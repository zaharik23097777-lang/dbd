-- Траппер: медвежьи капканы.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KillerDefs = require(ReplicatedStorage.Shared.KillerDefs)
local Server = script.Parent.Parent
local State = require(Server.Core.State)
local Actions = require(Server.Core.Actions)
local Lifecycle = require(Server.Core.Lifecycle)
local Scoring = require(Server.Core.Scoring)
local Props = require(Server.Map.Props)
local Health = require(Server.Systems.Health)

local DEF = KillerDefs.Trapper
local Trapper = {}

local rng = Random.new()

local function setCount(kdata)
	kdata.Player:SetAttribute("PowerCount", kdata.Power.InHand)
end

local function isTrap(target: Instance): boolean
	return target:GetAttribute("Kind") == "Trap"
end

local function trapPosition(trap: Model): Vector3
	return (trap:GetAttribute("Origin") :: CFrame).Position
end

function Trapper.Setup(kdata)
	kdata.Power = { InHand = DEF.TrapsInHand }
	setCount(kdata)
	local map = State.Map
	if not map then
		return
	end
	local spots = table.clone(map.TrapSpots)
	for i = #spots, 2, -1 do
		local j = rng:NextInteger(1, i)
		spots[i], spots[j] = spots[j], spots[i]
	end
	for i = 1, math.min(DEF.TrapsOnMap, #spots) do
		local trap = Props.trap(map.Traps, spots[i] * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
		trap:SetAttribute("Owner", kdata.Player.UserId)
	end
end

-- Отпустить выжившего из капкана
local function release(sdata)
	local trap = sdata.Trapped
	if not trap then
		return
	end
	sdata.Trapped = nil
	sdata.Player:SetAttribute("Trapped", nil)
	if trap.Parent then
		trap:SetAttribute("Caught", 0)
	end
	local root = State.getRoot(sdata.Player)
	if root then
		root.Anchored = false
	end
end

local function catch(sdata, trap: Model)
	Actions.cancel(sdata)
	trap:SetAttribute("Armed", false)
	trap:SetAttribute("Caught", sdata.Player.UserId)
	Props.setTrapArmed(trap, false)
	sdata.Trapped = trap
	sdata.TrapAttempts = 0
	sdata.Player:SetAttribute("Trapped", true)
	local root = State.getRoot(sdata.Player)
	local pos = trapPosition(trap)
	if root then
		root.Anchored = true
		root.CFrame = CFrame.new(pos.X, root.Position.Y, pos.Z) * root.CFrame.Rotation
	end
	State.sfx("TrapSnap", pos)
	Health.damage(sdata, "Trap")
	State.sfx("Scream", pos)
	State.noise(pos)
	local k = State.Killer
	if k then
		State.notify(k.Player, sdata.Player.DisplayName .. " попал в капкан!", State.RED)
		Scoring.add(k.Player, "Deviousness", 500, "Пойман в капкан")
	end
end

function Trapper.Press(kdata)
	if kdata.Power.InHand > 0 and not kdata.Action then
		Actions.start(kdata, "SetTrap", kdata.Player)
	elseif kdata.Power.InHand <= 0 then
		State.notify(kdata.Player, "Нет капканов в руках — подбери капкан на карте (E)", State.WHITE)
	end
end

function Trapper.Release(kdata)
	if kdata.Action and kdata.Action.Kind == "SetTrap" then
		Actions.cancel(kdata)
	end
end

function Trapper.Update(kdata, _dt)
	local map = State.Map
	if not map then
		return
	end
	for _, trap in map.Traps:GetChildren() do
		if not trap:GetAttribute("Armed") then
			continue
		end
		local pos = trapPosition(trap :: Model)
		for _, sdata in State.survivors() do
			if sdata.Status ~= "Playing" or sdata.Hidden or sdata.Trapped or State.now() < sdata.VaultUntil then
				continue
			end
			local root = State.getRoot(sdata.Player)
			if root and State.flatDist(root.Position, pos) < 1.4 and root.Position.Y - pos.Y < 4.5 then
				catch(sdata, trap :: Model)
				break
			end
		end
	end
	setCount(kdata)
end

------------------------------------------------------------------------
-- Действия
------------------------------------------------------------------------

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.RespectCanCollide = true

Actions.register("SetTrap", {
	Validate = function(data, _target)
		return data.KillerType == "Trapper" and data.Power ~= nil and data.Power.InHand > 0
	end,
	Complete = function(data, _target)
		local root = State.getRoot(data.Player)
		if not root or not State.Map then
			return
		end
		local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		local origin = root.Position + look.Unit * 2.5
		local exclude = { State.Map.Traps, State.Map.Effects }
		for p in State.Participants do
			if p.Character then
				table.insert(exclude, p.Character)
			end
		end
		groundParams.FilterDescendantsInstances = exclude
		local hit = workspace:Raycast(origin, Vector3.new(0, -12, 0), groundParams)
		local ground = hit and hit.Position or Vector3.new(origin.X, 0, origin.Z)
		local trap = Props.trap(State.Map.Traps, CFrame.lookAt(ground, ground + look))
		trap:SetAttribute("Owner", data.Player.UserId)
		data.Power.InHand -= 1
		setCount(data)
		State.sfx("Clank", ground)
	end,
})

Actions.register("PickupTrap", {
	Validate = function(data, target)
		return data.KillerType == "Trapper"
			and isTrap(target)
			and target:GetAttribute("Caught") == 0
			and data.Power.InHand < DEF.MaxTrapsInHand
	end,
	Complete = function(data, target)
		target:Destroy()
		data.Power.InHand += 1
		setCount(data)
		State.sfx("Rustle", State.getRoot(data.Player))
	end,
})

Actions.register("ResetTrap", {
	Validate = function(data, target)
		return data.KillerType == "Trapper" and isTrap(target) and not target:GetAttribute("Armed") and target:GetAttribute("Caught") == 0
	end,
	Complete = function(_data, target)
		target:SetAttribute("Armed", true)
		Props.setTrapArmed(target :: Model, true)
		State.sfx("Clank", trapPosition(target :: Model))
	end,
})

Actions.register("DisarmTrap", {
	Validate = function(_data, target)
		return isTrap(target) and target:GetAttribute("Armed") == true
	end,
	Complete = function(data, target)
		target:SetAttribute("Armed", false)
		Props.setTrapArmed(target :: Model, false)
		State.sfx("TrapSnap", trapPosition(target :: Model))
		Scoring.add(data.Player, "Boldness", 300, "Капкан обезврежен")
	end,
})

Actions.register("EscapeTrap", {
	AllowTrapped = true,
	Validate = function(data, target)
		return data.Trapped ~= nil and data.Trapped == target
	end,
	Complete = function(data, _target)
		data.TrapAttempts = (data.TrapAttempts or 0) + 1
		local chance = DEF.TrapEscapeChance + data.TrapAttempts * 0.05
		if rng:NextNumber() < chance then
			release(data)
			State.notify(data.Player, "Ты вырвался из капкана!", State.GREEN)
			Scoring.add(data.Player, "Survival", 500, "Вырвался из капкана")
		else
			local root = State.getRoot(data.Player)
			if root then
				State.sfx("Pain", root)
			end
		end
	end,
})

Actions.register("FreeTrap", {
	Validate = function(data, target)
		if not isTrap(target) then
			return false
		end
		local caught = target:GetAttribute("Caught") :: number
		return caught ~= 0 and caught ~= data.Player.UserId
	end,
	Complete = function(data, target)
		for _, sdata in State.Participants do
			if sdata.Trapped == target then
				release(sdata)
				State.notify(sdata.Player, data.Player.DisplayName .. " освободил тебя из капкана", State.GREEN)
				Scoring.add(data.Player, "Altruism", 1000, "Освобождение из капкана")
			end
		end
	end,
})

Lifecycle.addDetach(function(data)
	if data.Trapped then
		release(data)
	end
end)

return Trapper
