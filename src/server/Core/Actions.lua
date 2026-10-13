-- Реестр действий (ремонт, лечение, крюк, шкафчики и т.д.).
-- Системы регистрируют действие: Validate, Begin, Tick, Complete, Progress, OnSkillCheck.
-- Здесь — общий цикл: проверка дистанции, длительность, проверки навыка, атрибуты для UI.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Util = require(ReplicatedStorage.Shared.Util)
local ActionInfo = require(ReplicatedStorage.Shared.ActionInfo)
local State = require(script.Parent.State)

local Actions = {}

export type ActionDef = {
	Validate: (data: any, target: Instance) -> boolean,
	Begin: ((data: any, target: Instance) -> ())?,
	Tick: ((data: any, target: Instance, dt: number) -> ())?,
	Complete: ((data: any, target: Instance) -> ())?,
	Progress: ((data: any, target: Instance) -> number?)?,
	OnSkillCheck: ((data: any, target: Instance, result: string) -> ())?,
	OnCancel: ((data: any, target: Instance) -> ())?,
	SkillChecks: boolean?,
	AllowHidden: boolean?,
	AllowTrapped: boolean?,
	AllowCarrying: boolean?,
	AllowDowned: boolean?,
}

Actions.Defs = {} :: { [string]: ActionDef }

function Actions.register(kind: string, def: ActionDef)
	assert(ActionInfo[kind], "нет ActionInfo для " .. kind)
	Actions.Defs[kind] = def
end

function Actions.cancel(data)
	local a = data.Action
	data.Action = nil
	data.PendingCheck = nil
	data.Player:SetAttribute("ActionName", nil)
	data.Player:SetAttribute("ActionProgress", nil)
	if a then
		local def = Actions.Defs[a.Kind]
		if def and def.OnCancel then
			def.OnCancel(data, a.Target)
		end
	end
end

-- Общие условия: может ли игрок вообще что-то делать
function Actions.canAct(data, def: ActionDef?): boolean
	if data.Status ~= "Playing" then
		return false
	end
	local t = State.now()
	if t < data.VaultUntil then
		return false
	end
	if data.Hidden and not (def and def.AllowHidden) then
		return false
	end
	if data.Role == "Survivor" then
		if data.Trapped and not (def and def.AllowTrapped) then
			return false
		end
		return data.Health > 0 or (def ~= nil and def.AllowDowned == true)
	end
	if data.Carrying and not (def and def.AllowCarrying) then
		return false
	end
	return t >= data.StunnedUntil and t >= data.BlindUntil and not data.Lunging and not data.PowerBusy
end

local function inRange(data, kind: string, target: Instance, extra: number): boolean
	local info = ActionInfo[kind]
	if info.Range >= 1000 then
		return true
	end
	local root = Util.getRoot(data.Player)
	local pos = Util.objectPosition(target)
	return root ~= nil and pos ~= nil and Util.flatDist(root.Position, pos) <= info.Range + extra
end

local function roleAllowed(data, kind: string): boolean
	local info = ActionInfo[kind]
	return info.Role == "Any" or info.Role == data.Role
end

-- Начать действие (с клиента или из другой системы)
function Actions.start(data, kind: string, target: Instance): boolean
	local def = Actions.Defs[kind]
	local info = ActionInfo[kind]
	if not def or not info or not State.Active then
		return false
	end
	if data.Action or not roleAllowed(data, kind) or not Actions.canAct(data, def) then
		return false
	end
	if not inRange(data, kind, target, 1) or not def.Validate(data, target) then
		return false
	end
	if info.Instant then
		if def.Begin then
			def.Begin(data, target)
		end
		return true
	end
	data.Action = { Kind = kind, Target = target, Time = 0 }
	data.NextCheckRoll = State.now() + 1
	if def.Begin then
		def.Begin(data, target)
	end
	return true
end

------------------------------------------------------------------------
-- Проверки навыка
------------------------------------------------------------------------

local skillCheckCounter = 0
local rng = Random.new()

local function applySkillCheck(data, result: string)
	data.PendingCheck = nil
	local a = data.Action
	if not a then
		return
	end
	local def = Actions.Defs[a.Kind]
	if def and def.OnSkillCheck then
		def.OnSkillCheck(data, a.Target, result)
	end
end

local function tickSkillChecks(data, t: number)
	if data.PendingCheck then
		if t > data.PendingCheck.Deadline then
			applySkillCheck(data, "fail")
		end
		return
	end
	if t < data.NextCheckRoll then
		return
	end
	data.NextCheckRoll = t + 1
	local chance = Config.SkillCheckChancePerSecond
	if State.HexRuin then
		chance *= 1.3
	end
	if rng:NextNumber() < chance then
		skillCheckCounter += 1
		local zone = rng:NextNumber(0.45, 0.8)
		data.PendingCheck = { Id = skillCheckCounter, Deadline = t + Config.SkillCheckDuration + 2 }
		Remotes.SkillCheck:FireClient(data.Player, skillCheckCounter, zone)
	end
end

------------------------------------------------------------------------
-- Цикл
------------------------------------------------------------------------

function Actions.update(dt: number)
	local t = State.now()
	for _, data in State.Participants do
		local a = data.Action
		if not a then
			if data.PendingCheck then
				data.PendingCheck = nil
			end
			continue
		end
		local def = Actions.Defs[a.Kind]
		local info = ActionInfo[a.Kind]
		if not (Actions.canAct(data, def) and inRange(data, a.Kind, a.Target, 2) and def.Validate(data, a.Target)) then
			Actions.cancel(data)
			continue
		end
		a.Time += dt
		if def.Tick then
			def.Tick(data, a.Target, dt)
		end
		if data.Action ~= a then
			continue
		end
		local progress
		if info.Duration then
			progress = a.Time / info.Duration
			if progress >= 1 then
				Actions.cancel(data)
				if def.Complete then
					def.Complete(data, a.Target)
				end
				continue
			end
		elseif def.Progress then
			progress = def.Progress(data, a.Target)
		end
		data.Player:SetAttribute("ActionName", a.Kind)
		data.Player:SetAttribute("ActionProgress", progress)
		if def.SkillChecks then
			tickSkillChecks(data, t)
		end
	end
end

Remotes.BeginAction.OnServerEvent:Connect(function(player, kind, target)
	local data = State.get(player)
	if data and typeof(kind) == "string" and typeof(target) == "Instance" then
		Actions.start(data, kind, target)
	end
end)

Remotes.EndAction.OnServerEvent:Connect(function(player)
	local data = State.get(player)
	if data and data.Action then
		local info = ActionInfo[data.Action.Kind]
		-- Предмет и способность отпускаются своими кнопками
		if info and info.Key ~= "Item" and info.Key ~= "Power" then
			Actions.cancel(data)
		end
	end
end)

Remotes.SkillCheck.OnServerEvent:Connect(function(player, id, result)
	local data = State.get(player)
	if not data or not data.PendingCheck or data.PendingCheck.Id ~= id then
		return
	end
	if result ~= "great" and result ~= "good" then
		result = "fail"
	end
	applySkillCheck(data, result)
end)

return Actions
