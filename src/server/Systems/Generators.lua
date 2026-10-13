-- Генераторы: ремонт, проверки навыка, повреждение маньяком, Проклятие «Руина».
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Core = script.Parent.Parent.Core
local State = require(Core.State)
local Actions = require(Core.Actions)
local Scoring = require(Core.Scoring)
local Exits = require(script.Parent.Exits)

local Generators = {}

local lastRepair = {} :: { [Instance]: number }

-- Бонус ящика с инструментами (тратит заряд)
local function toolboxBonus(data, dt: number): number
	if data.Item == "Toolbox" and (data.ItemCharges or 0) > 0 then
		data.ItemCharges -= dt
		data.Player:SetAttribute("ItemCharges", math.max(data.ItemCharges, 0))
		if data.ItemCharges <= 0 then
			Generators.onItemEmpty(data)
		end
		return Config.ToolboxBonus
	end
	return 0
end
Generators.onItemEmpty = function(_data) end -- подменяется Items

local function setLights(gen: Model, progress: number)
	for i = 1, 4 do
		local light = gen:FindFirstChild("Light" .. i) :: BasePart?
		if light then
			local on = progress >= i / 4 - 0.001
			light.Color = on and Color3.fromRGB(255, 220, 120) or Color3.fromRGB(45, 40, 30)
			light.Material = on and Enum.Material.Neon or Enum.Material.Glass
		end
	end
end

function Generators.setProgress(gen: Model, p: number)
	gen:SetAttribute("Progress", p)
	setLights(gen, p)
end

local function completeGenerator(gen: Model)
	Generators.setProgress(gen, 1)
	gen:SetAttribute("Done", true)
	gen:SetAttribute("Regressing", false)
	local bulb = gen:FindFirstChild("Bulb") :: BasePart?
	if bulb then
		bulb.Color = Color3.fromRGB(255, 230, 140)
		bulb.Material = Enum.Material.Neon
		local light = bulb:FindFirstChildOfClass("PointLight")
		if light then
			light.Enabled = true
		end
	end
	State.GensDone += 1
	State.sfx("GenDone", nil)
	State.sfx("Clank", gen.PrimaryPart)
	for _, data in State.Participants do
		if data.Action and data.Action.Target == gen then
			Actions.cancel(data)
			Scoring.add(data.Player, "Objectives", 1250, "Генератор починен")
		end
	end
	local left = math.max(Config.GeneratorsRequired - State.GensDone, 0)
	State.setGame("GensLeft", left)
	if left > 0 then
		State.notifyAll("Генератор починен! Осталось: " .. left, State.YELLOW)
	else
		Exits.powerGates()
	end
end

local function explode(gen: Model)
	local body = gen.PrimaryPart
	if not body then
		return
	end
	local fx = body:FindFirstChild("FX")
	if fx then
		local sparks = fx:FindFirstChild("Sparks") :: ParticleEmitter?
		local smoke = fx:FindFirstChild("Smoke") :: ParticleEmitter?
		if sparks then
			sparks:Emit(45)
		end
		if smoke then
			smoke.Enabled = true
			task.delay(2.5, function()
				if smoke.Parent then
					smoke.Enabled = false
				end
			end)
		end
	end
	State.sfx("GenExplode", body)
	State.noise(body.Position)
end

local function isGen(target: Instance): boolean
	return target:GetAttribute("Kind") == "Generator"
end

Actions.register("Repair", {
	SkillChecks = true,
	Validate = function(_data, target)
		return isGen(target) and not target:GetAttribute("Done") and not State.GatesPowered
	end,
	Begin = function(_data, target)
		target:SetAttribute("Regressing", false)
	end,
	Tick = function(data, target, dt)
		local rate = (1 + toolboxBonus(data, dt)) / Config.GeneratorRepairTime
		local p = (target:GetAttribute("Progress") :: number) + dt * rate
		lastRepair[target] = State.now()
		Scoring.add(data.Player, "Objectives", dt * rate * 1250, nil)
		if p >= 1 then
			completeGenerator(target :: Model)
		else
			Generators.setProgress(target :: Model, p)
		end
	end,
	Progress = function(_data, target)
		return target:GetAttribute("Progress") :: number
	end,
	OnSkillCheck = function(data, target, result)
		local p = target:GetAttribute("Progress") :: number
		if result == "great" then
			Generators.setProgress(target :: Model, math.min(p + Config.SkillCheckGreatBonus, 0.999))
			Scoring.add(data.Player, "Objectives", 100, "Отличная проверка")
		elseif result == "good" then
			Scoring.add(data.Player, "Objectives", 50, nil)
		else
			Generators.setProgress(target :: Model, math.max(p - Config.SkillCheckFailPenalty, 0))
			explode(target :: Model)
			State.effect(data.Player, "Shake", 0.5)
			State.notify(data.Player, "Генератор взорвался! Маньяк услышал шум.", State.RED)
		end
	end,
})

Actions.register("Kick", {
	Validate = function(_data, target)
		return isGen(target)
			and not target:GetAttribute("Done")
			and not State.GatesPowered
			and (target:GetAttribute("Progress") :: number) > 0
			and not target:GetAttribute("Regressing")
	end,
	Complete = function(data, target)
		local p = math.max((target:GetAttribute("Progress") :: number) - Config.GeneratorKickRegression, 0)
		Generators.setProgress(target :: Model, p)
		target:SetAttribute("Regressing", p > 0)
		State.sfx("Clank", (target :: Model).PrimaryPart)
		explode(target :: Model)
		Scoring.add(data.Player, "Brutality", 100, "Повреждение генератора")
	end,
})

function Generators.update(dt: number)
	local map = State.Map
	if not map or State.GatesPowered then
		return
	end
	local t = State.now()
	for _, gen in map.Generators:GetChildren() do
		if gen:GetAttribute("Done") then
			continue
		end
		local p = gen:GetAttribute("Progress") :: number
		local beingRepaired = t - (lastRepair[gen] or 0) < 0.2
		if p > 0 and not beingRepaired then
			local rate = 0
			if gen:GetAttribute("Regressing") then
				rate += Config.GeneratorRegressPerSecond
			end
			if State.HexRuin then
				rate += Config.RuinRegressPerSecond
			end
			if rate > 0 then
				p = math.max(p - rate * dt, 0)
				Generators.setProgress(gen :: Model, p)
				if p <= 0 then
					gen:SetAttribute("Regressing", false)
				end
			end
		end
	end
end

function Generators.reset()
	table.clear(lastRepair)
end

return Generators
