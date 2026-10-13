-- Один раунд: старт, главный цикл, конец.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local KillerDefs = require(ReplicatedStorage.Shared.KillerDefs)
local Server = script.Parent.Parent
local State = require(script.Parent.State)
local Actions = require(script.Parent.Actions)
local Lifecycle = require(script.Parent.Lifecycle)
local Scoring = require(script.Parent.Scoring)
local Characters = require(script.Parent.Characters)
local MapBuilder = require(Server.Map.MapBuilder)
local Powers = require(Server.Powers)
local Systems = Server.Systems
local Health = require(Systems.Health)
local Carry = require(Systems.Carry)
local Combat = require(Systems.Combat)
local Generators = require(Systems.Generators)
local Exits = require(Systems.Exits)
require(Systems.Obstacles)
require(Systems.Lockers)
local Totems = require(Systems.Totems)
local Items = require(Systems.Items)
local Crows = require(Systems.Crows)
local Chase = require(Systems.Chase)

local Match = {}

local PLAYER_ATTRS = {
	"Role",
	"KillerType",
	"Status",
	"Health",
	"HookCount",
	"HookProgress",
	"BleedOut",
	"Wiggle",
	"ActionName",
	"ActionProgress",
	"Stunned",
	"Blinded",
	"Carrying",
	"Running",
	"Crouching",
	"Hidden",
	"Trapped",
	"Chase",
	"Item",
	"ItemCharges",
	"ItemMax",
	"ItemActive",
	"PowerCount",
	"PowerCharge",
	"PowerState",
	"Cloaked",
	"TerrorRadius",
}

local function newData(player: Player, role: string, killerType: string?)
	local def = killerType and KillerDefs.get(killerType)
	return {
		Player = player,
		Role = role,
		KillerType = killerType,
		Scale = def and def.Scale or 1,
		Health = 2,
		Status = "Playing",
		HookCount = 0,
		HookTimer = 0,
		BleedOut = 0,
		Wiggle = 0,
		HealProgress = 0,
		Sprinting = false,
		Crouching = false,
		BoostUntil = 0,
		StunnedUntil = 0,
		BlindUntil = 0,
		AttackReadyAt = 0,
		LungeUntil = 0,
		Lunging = false,
		SlowUntil = 0,
		VaultUntil = 0,
		NextCheckRoll = 0,
		Score = {},
	}
end

function Match.isActive(): boolean
	return State.Active
end

function Match.Start(playerList: { Player }, killerPlayer: Player?, killerType: string)
	table.clear(State.Participants)
	State.Killer = nil
	State.GensDone = 0
	State.GatesPowered = false
	State.EndgameDeadline = nil
	State.StartTime = State.now()
	State.SoloTest = killerPlayer == nil
	State.HexRuin = false
	Generators.reset()
	State.Map = MapBuilder.BuildMap()

	for _, player in playerList do
		local isKiller = player == killerPlayer
		local data = newData(player, isKiller and "Killer" or "Survivor", isKiller and killerType or nil)
		State.Participants[player] = data
		if isKiller then
			State.Killer = data
		end
	end

	State.InitialSurvivors = #State.survivors()
	local def = KillerDefs.get(killerType)
	State.setGame("GensLeft", Config.GeneratorsRequired)
	State.setGame("EndGame", false)
	State.setGame("EndGameTimer", Config.EndGameCollapseTime)
	State.setGame("KillerName", State.Killer and State.Killer.Player.DisplayName or "—")
	State.setGame("KillerType", State.Killer and def.Id or nil)

	-- Появление персонажей
	local map = State.Map
	local sIndex = 0
	for player, data in State.Participants do
		player:SetAttribute("Role", data.Role)
		player:SetAttribute("KillerType", data.KillerType)
		player:SetAttribute("Status", data.Status)
		player:SetAttribute("Health", data.Health)
		local cf
		if data.Role == "Killer" then
			cf = CFrame.lookAt(map.KillerSpawn, map.SurvivorSpawn * Vector3.new(1, 0, 1) + Vector3.new(0, map.KillerSpawn.Y, 0))
		else
			sIndex += 1
			local angle = sIndex * math.pi / 2
			local pos = map.SurvivorSpawn + Vector3.new(math.cos(angle) * 4, 0, math.sin(angle) * 4)
			cf = CFrame.lookAt(pos, map.SurvivorSpawn)
		end
		local char = Characters.spawn(player, cf, data.Role, data.KillerType)
		if not char then
			data.Status = "Left"
		end
	end

	if State.Killer then
		Powers.call(State.Killer, "Setup")
	end
	Totems.setup()
	Crows.setup()
	State.Active = true
	State.setGame("Phase", "InGame")

	for player, data in State.Participants do
		State.effect(player, "Intro", {
			Role = data.Role,
			KillerName = def.Name,
		})
		if data.Role == "Killer" then
			State.notify(player, "Ты — " .. def.Name .. ". " .. def.PowerHint, State.RED)
		else
			State.notify(player, "Ты — ВЫЖИВШИЙ. Почини генераторы и сбеги!", State.GREEN)
		end
	end
end

function Match.End(reason: string?)
	if not State.Active then
		return
	end
	State.Active = false

	local rows = {}
	local escaped, dead = 0, 0
	for player, data in State.Participants do
		if data.Role == "Survivor" then
			if data.Status == "Escaped" then
				escaped += 1
			elseif data.Status == "Dead" or data.Status == "Left" then
				dead += 1
			end
		end
		local total = Scoring.total(data)
		table.insert(rows, {
			Name = player.DisplayName,
			Role = data.Role,
			KillerType = data.KillerType,
			Status = data.Status,
			Score = Scoring.summary(data),
			Total = total,
		})
		Scoring.commit(player, total)
	end
	table.sort(rows, function(a, b)
		if a.Role ~= b.Role then
			return a.Role == "Killer"
		end
		return a.Total > b.Total
	end)
	local title
	if State.SoloTest then
		title = escaped > 0 and "Тестовый раунд: ты сбежал!" or "Тестовый раунд окончен"
	elseif escaped > dead then
		title = "Победа выживших!"
	elseif dead > escaped then
		title = "Победа маньяка!"
	else
		title = "Ничья"
	end
	Remotes.Results:FireAllClients(title, reason or "", rows)

	if State.Killer then
		Powers.call(State.Killer, "Cleanup")
	end
	for player, data in State.Participants do
		Lifecycle.detach(data)
		Actions.cancel(data)
		Items.cleanup(data)
		local root = State.getRoot(player)
		if root then
			root.Anchored = false
		end
		for _, attr in PLAYER_ATTRS do
			player:SetAttribute(attr, nil)
		end
		if player.Parent then
			task.spawn(Characters.spawnLobby, player)
		end
	end
	table.clear(State.Participants)
	State.Killer = nil
	State.setGame("EndGame", false)
	State.setGame("HexRuin", false)
	if State.Map then
		State.Map.Model:Destroy()
		State.Map = nil
	end
end

function Match.OnPlayerRemoving(player: Player)
	local data = State.get(player)
	if not data then
		return
	end
	Lifecycle.detach(data)
	Actions.cancel(data)
	if data.Status ~= "Dead" and data.Status ~= "Escaped" then
		data.Status = "Left"
		State.notifyAll(player.DisplayName .. " покинул игру", State.YELLOW)
	end
end

-- Смерть персонажа (например, кнопка «Reset»)
Characters.OnDied = function(player: Player, char: Model): boolean
	local data = State.get(player)
	if not State.Active or not data or player.Character ~= char then
		return false
	end
	if data.Role == "Killer" then
		data.Status = "Dead"
		return false
	end
	if State.isInGame(data) then
		Lifecycle.remove(data, "Dead", player.DisplayName .. " погиб", State.RED)
		return true
	end
	return false
end

Remotes.Sprint.OnServerEvent:Connect(function(player, value)
	local data = State.get(player)
	if data then
		data.Sprinting = value == true
	end
end)

Remotes.Crouch.OnServerEvent:Connect(function(player, value)
	local data = State.get(player)
	if data and data.Role == "Survivor" then
		data.Crouching = value == true
	end
end)

------------------------------------------------------------------------
-- Скорость и атрибуты
------------------------------------------------------------------------

local function survivorSpeed(data, t: number): number
	if data.Action or t < data.VaultUntil or data.Trapped or data.Hidden then
		return 0
	end
	if data.Health == 0 then
		return Config.SurvivorCrawlSpeed
	end
	if t < data.BoostUntil then
		return Config.SurvivorHitBoostSpeed
	end
	if data.Crouching then
		return Config.SurvivorCrouchSpeed
	end
	return data.Sprinting and Config.SurvivorSprintSpeed or Config.SurvivorWalkSpeed
end

local function killerSpeed(data, t: number): number
	if t < data.StunnedUntil or data.Action or t < data.VaultUntil then
		return 0
	end
	if data.Lunging then
		return Config.KillerLungeSpeed
	end
	if t < data.SlowUntil then
		return Config.AttackSlowSpeed
	end
	if t < data.BlindUntil then
		return 8
	end
	local override = Powers.call(data, "SpeedOverride", t)
	if override then
		return override
	end
	if data.Carrying then
		return Config.KillerCarrySpeed
	end
	return KillerDefs.get(data.KillerType).Speed
end

local function syncPlayer(player: Player, data, t: number)
	local hum = State.getHumanoid(player)
	local root = State.getRoot(player)
	if hum and State.isInGame(data) then
		hum.WalkSpeed = data.Role == "Killer" and killerSpeed(data, t) or survivorSpeed(data, t)
	end
	local running = false
	if data.Role == "Survivor" and data.Status == "Playing" and data.Health > 0 and data.Sprinting and not data.Crouching and root then
		running = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude > 11
	end
	player:SetAttribute("Status", data.Status)
	player:SetAttribute("Health", data.Health)
	player:SetAttribute("HookCount", data.HookCount)
	player:SetAttribute("HookProgress", data.Status == "Hooked" and data.HookTimer / Config.HookStageTime or nil)
	player:SetAttribute("BleedOut", (data.Status == "Playing" and data.Health == 0) and data.BleedOut / Config.BleedOutTime or nil)
	player:SetAttribute("Wiggle", data.Status == "Carried" and data.Wiggle or nil)
	player:SetAttribute("Stunned", t < data.StunnedUntil)
	player:SetAttribute("Blinded", t < data.BlindUntil)
	player:SetAttribute("Carrying", data.Carrying ~= nil)
	player:SetAttribute("Running", running)
	player:SetAttribute("Crouching", data.Crouching and data.Role == "Survivor" and data.Health > 0)
	if data.Role == "Killer" then
		local tr = Powers.call(data, "TerrorRadius")
		player:SetAttribute("TerrorRadius", tr or KillerDefs.get(data.KillerType).TerrorRadius)
	end
end

function Match.Update(dt: number)
	if not State.Active then
		return
	end
	local t = State.now()

	Actions.update(dt)
	Combat.update(dt)
	Carry.update(dt)
	Health.update(dt)
	Generators.update(dt)
	Exits.update(dt)
	Powers.update(dt)
	Items.update(dt)
	Crows.update(dt)
	Chase.update(dt)

	for player, data in State.Participants do
		syncPlayer(player, data, t)
	end

	-- Условия окончания раунда
	local k = State.Killer
	if State.remainingSurvivors() == 0 then
		Match.End()
	elseif not State.SoloTest and (not k or k.Status ~= "Playing" or not k.Player.Parent) then
		Match.End("Маньяк выбыл из игры")
	elseif t - State.StartTime > Config.MaxRoundTime then
		Match.End("Время вышло")
	end
end

return Match
