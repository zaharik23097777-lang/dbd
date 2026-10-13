-- Тотемы: очистка выжившими, проклятый тотем включает Проклятие «Руина».
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Core = script.Parent.Parent.Core
local State = require(Core.State)
local Actions = require(Core.Actions)
local Scoring = require(Core.Scoring)

local Totems = {}

local function cleanse(totem: Model, by: Player)
	totem:SetAttribute("Cleansed", true)
	totem:SetAttribute("Progress", 1)
	for _, d in totem:GetChildren() do
		if d.Name == "Flame" then
			d:Destroy()
		elseif d:GetAttribute("SkullPart") and d:IsA("BasePart") then
			d.Color = Color3.fromRGB(20, 20, 22)
			d.Material = Enum.Material.SmoothPlastic
		end
	end
	local skull = totem:FindFirstChild("Skull") :: BasePart?
	if skull then
		local fallen = skull.CFrame * CFrame.new(0.6, -2.6, 0) * CFrame.Angles(0, 0, math.rad(80))
		TweenService:Create(skull, TweenInfo.new(0.6, Enum.EasingStyle.Bounce), { CFrame = fallen }):Play()
	end
	State.sfx("Rustle", totem.PrimaryPart)
	if totem:GetAttribute("Hex") then
		State.HexRuin = false
		State.setGame("HexRuin", false)
		State.sfx("EntityDrone", totem.PrimaryPart)
		State.notifyAll("Проклятие «Руина» снято!", State.GREEN)
		Scoring.add(by, "Objectives", 1500, "Проклятый тотем очищен")
	else
		Scoring.add(by, "Objectives", 1000, "Тотем очищен")
	end
end

Actions.register("Cleanse", {
	Validate = function(_data, target)
		return target:GetAttribute("Kind") == "Totem" and not target:GetAttribute("Cleansed")
	end,
	Tick = function(data, target, dt)
		local p = (target:GetAttribute("Progress") :: number) + dt / Config.CleanseTime
		if p >= 1 then
			Actions.cancel(data)
			cleanse(target :: Model, data.Player)
		else
			target:SetAttribute("Progress", p)
		end
	end,
	Progress = function(_data, target)
		return target:GetAttribute("Progress") :: number
	end,
})

function Totems.setup()
	local hex = false
	if State.Map then
		for _, totem in State.Map.Totems:GetChildren() do
			if totem:GetAttribute("Hex") then
				hex = true
			end
		end
	end
	State.HexRuin = hex
	State.setGame("HexRuin", hex)
	if hex and State.Killer then
		State.notify(State.Killer.Player, "Проклятие «Руина» активно: генераторы сами откатываются", State.RED)
	end
end

return Totems
