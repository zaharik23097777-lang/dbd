-- Сундуки и предметы: аптечка, ящик с инструментами, фонарик.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ItemDefs = require(ReplicatedStorage.Shared.ItemDefs)
local Util = require(ReplicatedStorage.Shared.Util)
local Core = script.Parent.Parent.Core
local State = require(Core.State)
local Actions = require(Core.Actions)
local Lifecycle = require(Core.Lifecycle)
local Scoring = require(Core.Scoring)
local PropFX = require(script.Parent.Parent.Map.PropFX)
local ItemArt = require(script.Parent.Parent.Map.Art.Items)
local Combat = require(script.Parent.Combat)
local Generators = require(script.Parent.Generators)

local Items = {}

local rng = Random.new()

local function rollItem(): string
	local total = 0
	for _, w in Config.ChestItemWeights do
		total += w
	end
	local r = rng:NextNumber(0, total)
	for name, w in Config.ChestItemWeights do
		r -= w
		if r <= 0 then
			return name
		end
	end
	return "Medkit"
end

local function removeModel(data)
	if data.ItemModel then
		data.ItemModel:Destroy()
		data.ItemModel = nil
	end
end

-- Предмет в руке (виден всем); модель — в Art/Items
local function buildModel(data, item: string)
	removeModel(data)
	local char = data.Player.Character
	local arm = char and char:FindFirstChild("Right Arm") :: BasePart?
	if not arm then
		return
	end
	local m = ItemArt.held(item, arm)
	m.Parent = char
	data.ItemModel = m
end

function Items.give(data, item: string)
	data.Item = item
	data.ItemCharges = ItemDefs[item].Charges
	data.ItemActive = false
	data.Player:SetAttribute("Item", item)
	data.Player:SetAttribute("ItemCharges", data.ItemCharges)
	data.Player:SetAttribute("ItemMax", data.ItemCharges)
	data.Player:SetAttribute("ItemActive", false)
	buildModel(data, item)
end

function Items.remove(data)
	if data.Item then
		State.notify(data.Player, ItemDefs[data.Item].Name .. " закончился", State.WHITE)
	end
	data.Item = nil
	data.ItemCharges = 0
	data.ItemActive = false
	data.Player:SetAttribute("Item", nil)
	data.Player:SetAttribute("ItemCharges", nil)
	data.Player:SetAttribute("ItemActive", nil)
	removeModel(data)
end
Generators.onItemEmpty = Items.remove

local function setFlashlight(data, on: boolean)
	data.ItemActive = on
	data.Player:SetAttribute("ItemActive", on)
	local beam = data.ItemModel and data.ItemModel:FindFirstChild("Beam", true) :: SpotLight?
	if beam then
		beam.Enabled = on
	end
	if data.ItemModel then
		State.sfx("Click", data.ItemModel)
	end
end

Actions.register("OpenChest", {
	Validate = function(_data, target)
		return target:GetAttribute("Kind") == "Chest" and not target:GetAttribute("Opened")
	end,
	Begin = function(_data, target)
		State.sfx("Chest", (target :: Model).PrimaryPart)
	end,
	Complete = function(data, target)
		if target:GetAttribute("Opened") then
			return
		end
		target:SetAttribute("Opened", true)
		PropFX.chestOpen(target :: Model)
		local item = rollItem()
		Items.give(data, item)
		State.notify(data.Player, "Ты нашёл: " .. ItemDefs[item].Name .. ". " .. ItemDefs[item].Hint, State.YELLOW)
		Scoring.add(data.Player, "Objectives", 250, "Сундук открыт")
	end,
})

Actions.register("SelfHeal", {
	SkillChecks = true,
	Validate = function(data, _target)
		return data.Item == "Medkit" and (data.ItemCharges or 0) > 0 and data.Health == 1
	end,
	Tick = function(data, _target, dt)
		data.HealProgress += dt / Config.MedkitHealTime
		data.ItemCharges -= dt
		data.Player:SetAttribute("ItemCharges", math.max(data.ItemCharges, 0))
		if data.HealProgress >= 1 then
			data.HealProgress = 0
			data.Health = 2
			Actions.cancel(data)
			State.notify(data.Player, "Ты вылечился аптечкой", State.GREEN)
			Scoring.add(data.Player, "Survival", 500, "Самолечение")
		end
		if data.ItemCharges <= 0 then
			Actions.cancel(data)
			Items.remove(data)
		end
	end,
	Progress = function(data, _target)
		return data.HealProgress
	end,
	OnSkillCheck = function(data, _target, result)
		if result == "great" then
			data.HealProgress = math.min(data.HealProgress + Config.SkillCheckGreatBonus, 0.999)
		elseif result == "fail" then
			data.HealProgress = math.max(data.HealProgress - Config.SkillCheckFailPenalty, 0)
			local root = State.getRoot(data.Player)
			if root then
				State.noise(root.Position)
				State.sfx("Pain", root)
			end
		end
	end,
})

Remotes.UseItem.OnServerEvent:Connect(function(player, isDown, aim)
	local data = State.get(player)
	if not State.Active or not data or data.Role ~= "Survivor" or not data.Item then
		return
	end
	if typeof(aim) == "Vector3" and aim.Magnitude > 0.5 and aim.Magnitude < 1.5 then
		data.ItemAim = aim.Unit
	end
	if data.Item == "Medkit" then
		if isDown == true then
			Actions.start(data, "SelfHeal", player)
		elseif data.Action and data.Action.Kind == "SelfHeal" then
			Actions.cancel(data)
		end
	elseif data.Item == "Flashlight" then
		local on = isDown == true and data.Status == "Playing" and data.Health > 0 and not data.Hidden
		if on ~= data.ItemActive then
			setFlashlight(data, on)
		end
	end
end)

-- Фонарик: светим в лицо маньяку
function Items.update(dt: number)
	local k = State.Killer
	local khead = k and k.Player.Character and k.Player.Character:FindFirstChild("Head") :: BasePart?
	local kroot = k and State.getRoot(k.Player)
	for _, data in State.Participants do
		if data.Item ~= "Flashlight" or not data.ItemActive then
			continue
		end
		if data.Status ~= "Playing" or data.Health <= 0 or data.Hidden or data.Action then
			setFlashlight(data, false)
			continue
		end
		data.ItemCharges -= dt
		data.Player:SetAttribute("ItemCharges", math.max(data.ItemCharges, 0))
		if data.ItemCharges <= 0 then
			Items.remove(data)
			continue
		end
		local shead = data.Player.Character and data.Player.Character:FindFirstChild("Head") :: BasePart?
		local hit = false
		if khead and kroot and shead and k.Status == "Playing" then
			local toKiller = khead.Position - shead.Position
			local dist = toKiller.Magnitude
			local aim = data.ItemAim or shead.CFrame.LookVector
			if dist <= Config.FlashlightRange and dist > 0.1 then
				local angle = math.deg(math.acos(math.clamp(aim:Dot(toKiller.Unit), -1, 1)))
				local facing = kroot.CFrame.LookVector:Dot(-toKiller.Unit)
				if angle <= Config.FlashlightAngle and facing > 0.4 and Combat.lineOfSight(shead.Position, khead.Position) then
					hit = true
				end
			end
		end
		if hit then
			data.BlindAccum = (data.BlindAccum or 0) + dt
			if data.BlindAccum >= Config.FlashlightBlindTime then
				data.BlindAccum = 0
				if Combat.blind(Config.BlindDuration) then
					Scoring.add(data.Player, "Boldness", 1250, "Ослепление")
				end
			end
		else
			data.BlindAccum = math.max((data.BlindAccum or 0) - dt * 0.5, 0)
		end
	end
end

Lifecycle.addDetach(function(data)
	if data.ItemActive then
		setFlashlight(data, false)
	end
end)

function Items.cleanup(data)
	removeModel(data)
end

return Items
