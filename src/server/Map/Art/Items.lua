-- Предметы выживших в руке: аптечка, ящик с инструментами, фонарик.
-- ItemArt.held(item, arm) возвращает Model, приваренную к руке (Massless, без столкновений).
-- У фонарика внутри должен быть SpotLight с именем "Beam" (светит вдоль руки, Enabled = false).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Kit = require(script.Parent.Kit)

local ItemArt = {}

local function finish(m: Model, arm: BasePart)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.Massless = true
			Kit.decor(d)
			Util.weld(arm, d)
		end
	end
end

-- Кисть руки R6 — низ детали "Right Arm"; локальная -Y руки = направление, куда указывает рука
function ItemArt.held(item: string, arm: BasePart): Model
	local m = Kit.model("HeldItem")
	local hand = arm.CFrame * CFrame.new(0, -arm.Size.Y / 2, 0)
	if item == "Flashlight" then
		local body = Kit.cyl(m, hand * CFrame.new(0, -0.3, -0.25) * CFrame.Angles(0, 0, math.rad(90)), 1.3, 0.4, Color3.fromRGB(230, 220, 120), Enum.Material.SmoothPlastic)
		m.PrimaryPart = body
		local beam = Kit.spotLight(body, Color3.fromRGB(255, 250, 220), Config.FlashlightRange + 4, Config.FlashlightAngle * 2.5, 6, Enum.NormalId.Left, true)
		beam.Name = "Beam"
		beam.Enabled = false
	elseif item == "Medkit" then
		m.PrimaryPart = Kit.box(m, hand * CFrame.new(0, -0.2, -0.3), Vector3.new(1, 0.7, 0.4), Color3.fromRGB(200, 40, 40), Enum.Material.SmoothPlastic)
	else
		m.PrimaryPart = Kit.box(m, hand * CFrame.new(0, -0.25, -0.2), Vector3.new(1.2, 0.6, 0.5), Color3.fromRGB(60, 110, 200), Enum.Material.SmoothPlastic)
	end
	finish(m, arm)
	return m
end

return ItemArt
