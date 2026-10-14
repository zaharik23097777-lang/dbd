-- Метательный топор Охотницы (строится на клиенте для полёта снаряда).
-- Hatchet.build() возвращает Model с PrimaryPart; опора модели — центр вращения в начале координат,
-- «вперёд» (-Z) — направление полёта, модель вращается вокруг своей оси X (кувырком, как настоящий
-- брошенный топор). Лезвие смотрит вперёд: воткнувшись (Effects ставит опору в 0.6 перед точкой
-- удара), топор уходит в стену острием, а рукоять остаётся снаружи. Все детали Anchored, без столкновений.
local Hatchet = {}

local A = function(x: number, y: number, z: number): CFrame
	return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
end

local function part(m: Model, class: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): BasePart
	local p = Instance.new(class) :: BasePart
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Parent = m
	return p
end

-- Цилиндр между точками a и b
local function rod(m: Model, a: Vector3, b: Vector3, diameter: number, color: Color3, material: Enum.Material): BasePart
	local p = part(m, "Part", Vector3.new((b - a).Magnitude, diameter, diameter), CFrame.lookAt((a + b) / 2, b) * A(0, 90, 0), color, material);
	(p :: Part).Shape = Enum.PartType.Cylinder
	return p
end

function Hatchet.build(): Model
	local m = Instance.new("Model")
	m.Name = "Hatchet"
	local iron = Color3.fromRGB(64, 62, 60)
	local steel = Color3.fromRGB(150, 148, 142)
	local wood = Color3.fromRGB(96, 70, 46)
	local leather = Color3.fromRGB(70, 48, 34)
	-- Рукоять чуть отклонена назад, низ обмотан кожей
	local top, bottom = Vector3.new(0, 0.34, -0.1), Vector3.new(0, -1.22, 0.1)
	local handle = rod(m, top, bottom, 0.15, wood, Enum.Material.Wood)
	handle.Name = "Handle"
	rod(m, top:Lerp(bottom, 0.66), top:Lerp(bottom, 0.98), 0.19, leather, Enum.Material.Leather)
	-- Обух с проушиной, щёки, бородка, светлая заточенная кромка
	local eye = part(m, "Part", Vector3.new(0.2, 0.3, 0.28), CFrame.new(0, 0.22, -0.12), iron, Enum.Material.CorrodedMetal)
	eye.Name = "Head"
	part(m, "Part", Vector3.new(0.17, 0.2, 0.12), CFrame.new(0, 0.22, 0.07), iron, Enum.Material.CorrodedMetal)
	part(m, "Part", Vector3.new(0.09, 0.28, 0.38), CFrame.new(0, 0.2, -0.45), iron, Enum.Material.CorrodedMetal)
	part(m, "WedgePart", Vector3.new(0.09, 0.14, 0.38), CFrame.new(0, 0.41, -0.45) * A(0, 180, 0), iron, Enum.Material.CorrodedMetal)
	part(m, "WedgePart", Vector3.new(0.09, 0.24, 0.38), CFrame.new(0, -0.06, -0.45) * A(180, 0, 0), iron, Enum.Material.CorrodedMetal)
	part(m, "Part", Vector3.new(0.095, 0.66, 0.08), CFrame.new(0, 0.16, -0.67), steel, Enum.Material.Metal)
	-- Сыромятная обвязка под обухом
	rod(m, Vector3.new(0, 0.07, -0.1), Vector3.new(0, -0.05, -0.09), 0.2, leather, Enum.Material.Leather)
	part(m, "Part", Vector3.new(0.22, 0.05, 0.36), CFrame.new(0, 0.2, -0.12) * A(35, 0, 0), leather, Enum.Material.Leather)
	-- Опора — центр вращения (начало координат), а не центр обуха
	m.PrimaryPart = eye
	eye.PivotOffset = eye.CFrame:Inverse()
	return m
end

return Hatchet
