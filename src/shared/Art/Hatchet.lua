-- Метательный топор Охотницы (строится на клиенте для полёта снаряда).
-- Hatchet.build() возвращает Model с PrimaryPart; «вперёд» (-Z) — направление полёта,
-- модель вращается вокруг своей оси X. Все детали Anchored, без столкновений.
local Hatchet = {}

local function part(m: Model, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Parent = m
	return p
end

function Hatchet.build(): Model
	local m = Instance.new("Model")
	m.Name = "Hatchet"
	local handle = part(m, Vector3.new(0.18, 0.18, 1.8), CFrame.identity, Color3.fromRGB(80, 55, 35), Enum.Material.Wood)
	handle.Name = "Handle"
	part(m, Vector3.new(0.1, 0.8, 0.6), CFrame.new(0, 0.3, -0.8), Color3.fromRGB(170, 165, 160), Enum.Material.Metal)
	m.PrimaryPart = handle
	return m
end

return Hatchet
