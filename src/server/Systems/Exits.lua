-- Ворота, обрушение Сущности (эндгейм) и люк.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Core = script.Parent.Parent.Core
local State = require(Core.State)
local Actions = require(Core.Actions)
local Lifecycle = require(Core.Lifecycle)
local Scoring = require(Core.Scoring)
local Props = require(script.Parent.Parent.Map.Props)

local Exits = {}

function Exits.startEndgame(text: string?)
	if State.EndgameDeadline then
		return
	end
	State.EndgameDeadline = State.now() + Config.EndGameCollapseTime
	State.setGame("EndGame", true)
	State.sfx("EntityDrone", nil)
	if text then
		State.notifyAll(text, State.YELLOW)
	end
end

function Exits.powerGates()
	if State.GatesPowered or not State.Map then
		return
	end
	State.GatesPowered = true
	State.setGame("GensLeft", 0)
	for _, gate in State.Map.ExitGates:GetChildren() do
		gate:SetAttribute("Powered", true)
		local sw = gate:FindFirstChild("Switch") :: BasePart?
		if sw then
			sw.Color = Color3.fromRGB(150, 130, 40)
		end
	end
	State.sfx("GatePowered", nil)
	State.notifyAll("Все генераторы починены! Ворота запитаны — открывайте их!", State.YELLOW)
end

local function openGate(gate: Model, opener: Player?)
	gate:SetAttribute("Progress", 1)
	gate:SetAttribute("Open", true)
	Props.setGateLever(gate, 1)
	local door = gate:FindFirstChild("Door") :: BasePart?
	if door then
		door.CanCollide = false
		local info = TweenInfo.new(2.5, Enum.EasingStyle.Quad)
		TweenService:Create(door, info, { CFrame = door.CFrame + Vector3.new(0, 11.8, 0) }):Play()
		for _, rib in gate:GetChildren() do
			if rib.Name == "DoorRib" and rib:IsA("BasePart") then
				TweenService:Create(rib, info, { CFrame = rib.CFrame + Vector3.new(0, 11.8, 0) }):Play()
			end
		end
		State.sfx("GateOpen", door)
	end
	if opener then
		Scoring.add(opener, "Objectives", 1250, "Ворота открыты")
	end
	if State.EndgameDeadline then
		State.notifyAll("Вторые ворота открыты!", State.YELLOW)
	else
		Exits.startEndgame("Ворота открыты! Обрушение Сущности началось — бегите!")
	end
end

local function setSiren(gate: Model, on: boolean)
	local siren = gate:FindFirstChild("Siren")
	local light = siren and siren:FindFirstChild("SirenLight") :: SpotLight?
	if light then
		light.Enabled = on
	end
	if siren and siren:IsA("BasePart") then
		siren.Material = on and Enum.Material.Neon or Enum.Material.Glass
		siren.Color = on and Color3.fromRGB(255, 40, 30) or Color3.fromRGB(80, 10, 10)
	end
end

Actions.register("OpenGate", {
	Validate = function(_data, target)
		return target:GetAttribute("Kind") == "ExitGate" and target:GetAttribute("Powered") == true and not target:GetAttribute("Open")
	end,
	Begin = function(_data, target)
		setSiren(target :: Model, true)
	end,
	Tick = function(data, target, dt)
		local p = (target:GetAttribute("Progress") :: number) + dt / Config.OpenGateTime
		if p >= 1 then
			Actions.cancel(data)
			openGate(target :: Model, data.Player)
		else
			target:SetAttribute("Progress", p)
			Props.setGateLever(target :: Model, p)
		end
	end,
	Progress = function(_data, target)
		return target:GetAttribute("Progress") :: number
	end,
})

------------------------------------------------------------------------
-- Люк
------------------------------------------------------------------------

local function isHatch(target: Instance): boolean
	return target:GetAttribute("Kind") == "Hatch"
end

Actions.register("JumpHatch", {
	Validate = function(_data, target)
		return isHatch(target) and target:GetAttribute("Open") == true
	end,
	Begin = function(data, target)
		State.sfx("Vault", (target :: Model).PrimaryPart)
		Scoring.add(data.Player, "Survival", 7000, "Побег через люк")
		Lifecycle.remove(data, "Escaped", data.Player.DisplayName .. " сбежал через люк!", State.GREEN)
	end,
})

Actions.register("CloseHatch", {
	Validate = function(_data, target)
		return isHatch(target) and target:GetAttribute("Open") == true
	end,
	Complete = function(data, target)
		target:SetAttribute("Open", false)
		target:SetAttribute("Closed", true)
		Props.setHatchOpen(target :: Model, false)
		State.sfx("Clank", (target :: Model).PrimaryPart)
		Scoring.add(data.Player, "Hunter", 1000, "Люк закрыт")
		Exits.powerGates()
		Exits.startEndgame("Маньяк закрыл люк! Обрушение Сущности началось.")
	end,
})

------------------------------------------------------------------------
-- Цикл
------------------------------------------------------------------------

function Exits.update(_dt: number)
	local map = State.Map
	if not map then
		return
	end
	local t = State.now()

	-- Побег через открытые ворота
	for _, data in State.survivors() do
		if data.Status ~= "Playing" then
			continue
		end
		local root = State.getRoot(data.Player)
		if not root then
			continue
		end
		for _, gate in map.ExitGates:GetChildren() do
			local zone = gate:FindFirstChild("EscapeZone") :: BasePart?
			if gate:GetAttribute("Open") and zone then
				local rel = zone.CFrame:PointToObjectSpace(root.Position)
				local half = zone.Size / 2
				if math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y + 2 and math.abs(rel.Z) <= half.Z then
					Scoring.add(data.Player, "Survival", 5000, "Побег")
					Lifecycle.remove(data, "Escaped", data.Player.DisplayName .. " сбежал!", State.GREEN)
					break
				end
			end
		end
	end

	-- Люк открывается, когда остался один выживший
	local hatch = map.Hatch
	if hatch and not State.SoloTest and not hatch:GetAttribute("Open") and not hatch:GetAttribute("Closed") then
		local earned = State.InitialSurvivors >= 2 or State.GensDone >= 2
		if earned and State.remainingSurvivors() == 1 and not State.EndgameDeadline then
			hatch:SetAttribute("Open", true)
			Props.setHatchOpen(hatch, true)
			State.sfx("Clank", hatch.PrimaryPart)
			for _, data in State.survivors() do
				if State.isInGame(data) then
					State.notify(data.Player, "Ты остался один. Люк открылся — найди его по звуку ветра!", State.YELLOW)
				end
			end
		end
	end

	-- Обрушение
	if State.EndgameDeadline then
		local left = State.EndgameDeadline - t
		State.setGame("EndGameTimer", math.max(math.ceil(left), 0))
		if left <= 0 then
			for _, data in State.survivors() do
				if State.isInGame(data) then
					Lifecycle.remove(data, "Dead", data.Player.DisplayName .. " забран Сущностью", State.RED)
				end
			end
		end
	end
end

return Exits
