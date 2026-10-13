-- Внешний вид маньяков: снаряжение из деталей, приваренное к телу R6.
-- KillerGear.dress(char, def) вызывается до масштабирования (char:ScaleTo), детали — Massless,
-- без столкновений. Части рук/оружия с именами из CameraController.VIEWMODEL видны от первого лица.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Util = require(ReplicatedStorage.Shared.Util)

local KillerGear = {}

------------------------------------------------------------------------
-- Снаряжение маньяков (из деталей, приваривается к телу)
------------------------------------------------------------------------

local function gear(char: Model, attachTo: string, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part?
	local base = char:FindFirstChild(attachTo) :: BasePart?
	if not base then
		return nil
	end
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CFrame = base.CFrame * offset
	Util.weld(base, p)
	p.Parent = char
	return p
end

local A = function(x, y, z)
	return CFrame.Angles(math.rad(x or 0), math.rad(y or 0), math.rad(z or 0))
end

local GEAR = {}

function GEAR.Trapper(char: Model)
	local bone = Color3.fromRGB(225, 215, 195)
	gear(char, "Head", "Mask", Vector3.new(1.25, 1.25, 0.3), CFrame.new(0, 0, -0.6), bone)
	gear(char, "Head", "MaskMouth", Vector3.new(0.9, 0.3, 0.1), CFrame.new(0, -0.3, -0.78), Color3.fromRGB(40, 10, 10))
	for i = -3, 3 do
		gear(char, "Head", "Tooth", Vector3.new(0.1, 0.18, 0.08), CFrame.new(i * 0.12, -0.25, -0.83), bone)
	end
	for _, x in { -0.25, 0.25 } do
		gear(char, "Head", "Eye", Vector3.new(0.22, 0.12, 0.08), CFrame.new(x, 0.15, -0.78), Color3.fromRGB(10, 10, 10))
	end
	gear(char, "Torso", "Apron", Vector3.new(1.9, 2.4, 0.2), CFrame.new(0, -0.4, -0.55), Color3.fromRGB(80, 60, 45), Enum.Material.Fabric)
	gear(char, "Torso", "Belt", Vector3.new(2.1, 0.3, 1.1), CFrame.new(0, -0.9, 0), Color3.fromRGB(40, 30, 25), Enum.Material.Fabric)
	gear(char, "Torso", "BackTrap", Vector3.new(0.2, 1.4, 1.4), CFrame.new(0, 0.2, 0.62) * A(0, 90, 0), Color3.fromRGB(110, 105, 100), Enum.Material.Metal, Enum.PartType.Cylinder)
	-- Тесак
	gear(char, "Right Arm", "Handle", Vector3.new(0.25, 1.2, 0.25), CFrame.new(0, -1.2, -0.4) * A(90, 0, 0), Color3.fromRGB(60, 40, 25), Enum.Material.Wood)
	gear(char, "Right Arm", "Blade", Vector3.new(0.12, 1, 2.2), CFrame.new(0, -1.5, -1.9), Color3.fromRGB(160, 150, 145), Enum.Material.Metal)
	gear(char, "Right Arm", "BladeBlood", Vector3.new(0.13, 0.5, 1.2), CFrame.new(0, -1.75, -2.2), Color3.fromRGB(90, 10, 10), Enum.Material.SmoothPlastic)
end

function GEAR.Huntress(char: Model)
	local white = Color3.fromRGB(235, 230, 220)
	gear(char, "Head", "Mask", Vector3.new(1.3, 1.3, 0.4), CFrame.new(0, 0, -0.55), white)
	for _, x in { -0.3, 0.3 } do
		gear(char, "Head", "Ear", Vector3.new(0.3, 1.6, 0.15), CFrame.new(x, 1.25, -0.2) * A(-10, 0, x * 25), white)
		gear(char, "Head", "Eye", Vector3.new(0.18, 0.18, 0.08), CFrame.new(x * 0.8, 0.12, -0.78), Color3.fromRGB(10, 10, 10))
	end
	gear(char, "Head", "Hood", Vector3.new(1.5, 1.4, 1.2), CFrame.new(0, 0.1, 0.25), Color3.fromRGB(90, 60, 40), Enum.Material.Fabric)
	gear(char, "Torso", "Fur", Vector3.new(2.6, 0.7, 1.4), CFrame.new(0, 0.85, 0), Color3.fromRGB(110, 85, 60), Enum.Material.Fabric)
	gear(char, "Torso", "Cloak", Vector3.new(2.2, 2.6, 0.2), CFrame.new(0, -0.3, 0.6), Color3.fromRGB(80, 55, 35), Enum.Material.Fabric)
	-- Топор
	gear(char, "Right Arm", "Handle", Vector3.new(0.22, 0.22, 2.6), CFrame.new(0, -1.15, -1.1), Color3.fromRGB(70, 50, 30), Enum.Material.Wood)
	gear(char, "Right Arm", "AxeHead", Vector3.new(0.12, 1.1, 0.8), CFrame.new(0, -0.75, -2.2), Color3.fromRGB(150, 145, 140), Enum.Material.Metal)
end

function GEAR.Wraith(char: Model)
	local wrap = Color3.fromRGB(150, 140, 120)
	for _, partName in { "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" } do
		local part = char:FindFirstChild(partName) :: BasePart?
		if part then
			local w = part.Size.X + 0.06
			for i = -2, 2 do
				gear(char, partName, "Bandage", Vector3.new(w, 0.18, part.Size.Z + 0.06), CFrame.new(0, i * 0.4, 0) * A(0, 0, (i % 2) * 8 - 4), wrap, Enum.Material.Fabric)
			end
		end
	end
	gear(char, "Head", "Wraps", Vector3.new(1.3, 1.25, 1.1), CFrame.new(0, 0, 0), wrap, Enum.Material.Fabric)
	for _, x in { -0.25, 0.25 } do
		gear(char, "Head", "Eye", Vector3.new(0.2, 0.1, 0.06), CFrame.new(x, 0.12, -0.56), Color3.fromRGB(255, 240, 200), Enum.Material.Neon)
	end
	gear(char, "Torso", "Rags", Vector3.new(2.1, 1.6, 1.1), CFrame.new(0, -1.3, 0), Color3.fromRGB(60, 55, 50), Enum.Material.Fabric)
	-- Дубина с черепом
	gear(char, "Right Arm", "Club", Vector3.new(0.25, 0.25, 2.4), CFrame.new(0, -1.15, -1.1), Color3.fromRGB(80, 70, 60), Enum.Material.Wood)
	gear(char, "Right Arm", "Skull", Vector3.new(0.75, 0.75, 0.75), CFrame.new(0, -1.15, -2.4), Color3.fromRGB(220, 210, 190), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	-- Колокол
	gear(char, "Left Arm", "Bell", Vector3.new(0.8, 0.9, 0.9), CFrame.new(0, -1.5, -0.2) * A(0, 0, 90), Color3.fromRGB(150, 120, 60), Enum.Material.Metal, Enum.PartType.Cylinder)
end

function KillerGear.dress(char: Model, def)
	for _, d in char:GetDescendants() do
		if d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") or d:IsA("Accessory") then
			d:Destroy()
		end
	end
	local head = char:FindFirstChild("Head")
	if head then
		for _, d in head:GetChildren() do
			if d:IsA("Decal") then
				d:Destroy()
			end
		end
	end
	for _, partName in { "Torso", "Left Leg", "Right Leg" } do
		local p = char:FindFirstChild(partName) :: BasePart?
		if p then
			p.Color = def.ClothColor
		end
	end
	for _, partName in { "Head", "Left Arm", "Right Arm" } do
		local p = char:FindFirstChild(partName) :: BasePart?
		if p then
			p.Color = def.BodyColor
		end
	end
	local builder = GEAR[def.Id]
	if builder then
		builder(char)
	end
	-- Красное пятно перед маньяком (видят выжившие)
	if head then
		local stain = Instance.new("SpotLight")
		stain.Name = "RedStain"
		stain.Color = Color3.fromRGB(255, 20, 20)
		stain.Range = 24
		stain.Angle = 35
		stain.Brightness = 4
		stain.Face = Enum.NormalId.Front
		stain.Parent = head
	end
end


return KillerGear
