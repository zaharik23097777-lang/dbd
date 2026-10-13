-- ВРЕМЕННЫЙ модуль: старые простые декорации (стены, деревья, камни, свалка...).
-- Используется Structures/Nature/Lobby, пока они не переписаны качественно; затем удаляется.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Props = {}

local SMOKE_TEX = "rbxasset://textures/particles/smoke_main.dds"
local SPARK_TEX = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE_TEX = "rbxasset://textures/particles/fire_main.dds"
Props.SmokeTexture = SMOKE_TEX
Props.SparkTexture = SPARK_TEX

local rad = math.rad

local function A(x, y, z)
	return CFrame.Angles(rad(x or 0), rad(y or 0), rad(z or 0))
end
Props.A = A

-- Создаёт деталь. Мелкий декор (Decor = true) не сталкивается и не мешает лучам.
function Props.part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	local decor = props.Decor
	for k, v in props do
		if k ~= "Decor" then
			(p :: any)[k] = v
		end
	end
	if decor then
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
	end
	p.Parent = parent
	return p
end
local P = Props.part

local function model(name: string, parent: Instance?): Model
	local m = Instance.new("Model")
	m.Name = name
	if parent then
		m.Parent = parent
	end
	return m
end
Props.model = model

local COLORS = {
	Concrete = Color3.fromRGB(92, 88, 84),
	Wood = Color3.fromRGB(105, 78, 52),
	DarkWood = Color3.fromRGB(70, 52, 38),
	Rust = Color3.fromRGB(110, 60, 35),
	Metal = Color3.fromRGB(90, 92, 95),
	Bone = Color3.fromRGB(225, 215, 190),
	Black = Color3.fromRGB(20, 20, 22),
}
Props.Colors = COLORS

local WALL_STYLES = {
	Wood = { COLORS.Wood, Enum.Material.WoodPlanks },
	Brick = { Color3.fromRGB(110, 60, 50), Enum.Material.Brick },
	Concrete = { COLORS.Concrete, Enum.Material.Concrete },
}

function Props.wall(parent: Instance, cf: CFrame, size: Vector3, style: string?): Part
	local st = WALL_STYLES[style or "Concrete"] or WALL_STYLES.Concrete
	return P(parent, {
		Name = "Wall",
		Size = size,
		CFrame = cf,
		Color = st[1],
		Material = st[2],
	})
end

-- Стена вдоль локальной оси X с проёмами.
-- openings = { {Center = x, Width = w, Sill = высота подоконника или 0 для двери, Top = верх проёма} }
-- Возвращает подоконники (их можно перепрыгивать).
function Props.wallWithOpenings(
	parent: Instance,
	cf: CFrame,
	length: number,
	height: number,
	thick: number,
	openings,
	style: string?,
	windowParent: Instance?
)
	table.sort(openings, function(a, b)
		return a.Center < b.Center
	end)
	local sills = {}
	local x = -length / 2
	local function segment(x0, x1, y0, y1)
		if x1 - x0 > 0.05 and y1 - y0 > 0.05 then
			Props.wall(parent, cf * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, 0), Vector3.new(x1 - x0, y1 - y0, thick), style)
		end
	end
	for _, o in openings do
		local x0, x1 = o.Center - o.Width / 2, o.Center + o.Width / 2
		segment(x, x0, 0, height)
		segment(x0, x1, o.Top, height)
		if o.Sill > 0 then
			local sill = P(windowParent or parent, {
				Name = "Window",
				Size = Vector3.new(o.Width, o.Sill, thick),
				CFrame = cf * CFrame.new(o.Center, o.Sill / 2, 0),
				Color = COLORS.DarkWood,
				Material = Enum.Material.Wood,
			})
			sill:SetAttribute("Kind", "Window")
			table.insert(sills, sill)
		end
		x = x1
	end
	segment(x, length / 2, 0, height)
	return sills
end

------------------------------------------------------------------------
-- Декор
------------------------------------------------------------------------

function Props.tree(parent: Instance, cf: CFrame, rng: Random)
	local h = rng:NextNumber(16, 26)
	P(parent, {
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(h, 1.8, 1.8),
		CFrame = cf * CFrame.new(0, h / 2, 0) * A(0, 0, 90),
		Color = Color3.fromRGB(55, 42, 33),
		Material = Enum.Material.Wood,
	})
	for i = 1, 3 do
		local s = 10 - i * 2.2
		P(parent, {
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(s, s * 0.8, s),
			CFrame = cf * CFrame.new(rng:NextNumber(-0.6, 0.6), h - 3 + i * 2.4, rng:NextNumber(-0.6, 0.6)),
			Color = Color3.fromRGB(28, 45 + i * 3, 30),
			Material = Enum.Material.LeafyGrass,
			Decor = true,
		})
	end
end

function Props.deadTree(parent: Instance, cf: CFrame, rng: Random)
	local h = rng:NextNumber(14, 22)
	local trunkColor = Color3.fromRGB(45, 38, 34)
	P(parent, {
		Name = "DeadTrunk",
		Size = Vector3.new(1.4, h, 1.4),
		CFrame = cf * CFrame.new(0, h / 2, 0) * A(rng:NextNumber(-4, 4), rng:NextNumber(0, 90), 0),
		Color = trunkColor,
		Material = Enum.Material.Wood,
	})
	for _ = 1, rng:NextInteger(3, 5) do
		local y = rng:NextNumber(h * 0.45, h * 0.9)
		local len = rng:NextNumber(3, 6)
		local yaw = rng:NextNumber(0, 360)
		P(parent, {
			Name = "Branch",
			Size = Vector3.new(0.4, 0.4, len),
			CFrame = cf * CFrame.new(0, y, 0) * A(0, yaw, 0) * A(rng:NextNumber(20, 50), 0, 0) * CFrame.new(0, 0, -len / 2),
			Color = trunkColor,
			Material = Enum.Material.Wood,
			Decor = true,
		})
	end
end

function Props.rock(parent: Instance, cf: CFrame, rng: Random)
	for _ = 1, rng:NextInteger(1, 3) do
		local s = Vector3.new(rng:NextNumber(4, 9), rng:NextNumber(4, 8), rng:NextNumber(4, 9))
		P(parent, {
			Name = "Rock",
			Size = s,
			CFrame = cf
				* CFrame.new(rng:NextNumber(-3, 3), s.Y / 2 - 0.5, rng:NextNumber(-3, 3))
				* A(rng:NextNumber(-8, 8), rng:NextNumber(0, 180), rng:NextNumber(-8, 8)),
			Color = Color3.fromRGB(80, 80, 86),
			Material = Enum.Material.Slate,
		})
	end
end

function Props.junkPile(parent: Instance, cf: CFrame, rng: Random)
	local rust = Color3.fromRGB(100 + rng:NextInteger(-15, 15), 55, 35)
	local car = cf * A(0, rng:NextNumber(-25, 25), rng:NextNumber(-6, 6))
	P(parent, {
		Name = "CarBody",
		Size = Vector3.new(4.4, 1.8, 9),
		CFrame = car * CFrame.new(0, 1.6, 0),
		Color = rust,
		Material = Enum.Material.CorrodedMetal,
	})
	P(parent, {
		Name = "CarCabin",
		Size = Vector3.new(4, 1.6, 4),
		CFrame = car * CFrame.new(0, 3.3, 0.6),
		Color = rust:Lerp(Color3.new(0, 0, 0), 0.2),
		Material = Enum.Material.CorrodedMetal,
	})
	P(parent, {
		Name = "Windshield",
		Size = Vector3.new(3.6, 1.2, 0.1),
		CFrame = car * CFrame.new(0, 3.3, -1.45),
		Color = Color3.fromRGB(40, 50, 55),
		Material = Enum.Material.Glass,
		Transparency = 0.4,
		Decor = true,
	})
	for _, w in { { -2.2, -3 }, { 2.2, -3 }, { -2.2, 3 }, { 2.2, 3 } } do
		if rng:NextNumber() > 0.25 then
			P(parent, {
				Name = "Wheel",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.6, 1.8, 1.8),
				CFrame = car * CFrame.new(w[1], 0.9, w[2]),
				Color = COLORS.Black,
				Material = Enum.Material.Rubber,
				Decor = true,
			})
		end
	end
	-- Стопка шин
	local tires = cf * CFrame.new(rng:NextNumber(-7, -5), 0, rng:NextNumber(-6, 6))
	for i = 1, rng:NextInteger(2, 4) do
		P(parent, {
			Name = "Tire",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.9, 2.6, 2.6),
			CFrame = tires * CFrame.new(rng:NextNumber(-0.2, 0.2), 0.45 + (i - 1) * 0.9, 0) * A(0, 0, 90),
			Color = COLORS.Black,
			Material = Enum.Material.Rubber,
		})
	end
	Props.barrel(parent, cf * CFrame.new(rng:NextNumber(5, 7), 0, rng:NextNumber(-5, 5)), rng)
end

function Props.barrel(parent: Instance, cf: CFrame, rng: Random)
	P(parent, {
		Name = "Barrel",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3, 2, 2),
		CFrame = cf * CFrame.new(0, 1.5, 0) * A(0, 0, 90),
		Color = Color3.fromRGB(80 + rng:NextInteger(0, 40), 40, 30),
		Material = Enum.Material.CorrodedMetal,
	})
end

function Props.hay(parent: Instance, cf: CFrame, rng: Random)
	for i = 1, rng:NextInteger(2, 4) do
		P(parent, {
			Name = "Hay",
			Size = Vector3.new(3, 2, 4.5),
			CFrame = cf * CFrame.new((i - 2) * 3.2, 1, rng:NextNumber(-0.5, 0.5)) * A(0, rng:NextNumber(-10, 10), 0),
			Color = Color3.fromRGB(190, 160, 85),
			Material = Enum.Material.Grass,
		})
	end
	if rng:NextNumber() > 0.5 then
		P(parent, {
			Name = "Hay",
			Size = Vector3.new(3, 2, 4.5),
			CFrame = cf * CFrame.new(-1.6, 3, 0) * A(0, 8, 0),
			Color = Color3.fromRGB(175, 150, 80),
			Material = Enum.Material.Grass,
		})
	end
end

function Props.tombstones(parent: Instance, cf: CFrame, rng: Random)
	for i = 1, rng:NextInteger(4, 7) do
		local x = ((i - 1) % 4 - 1.5) * 4
		local z = math.floor((i - 1) / 4) * 5 - 2.5
		local h = rng:NextNumber(2, 3.5)
		P(parent, {
			Name = "Tombstone",
			Size = Vector3.new(2, h, 0.6),
			CFrame = cf * CFrame.new(x, h / 2 - 0.3, z) * A(rng:NextNumber(-10, 10), rng:NextNumber(-10, 10), rng:NextNumber(-8, 8)),
			Color = Color3.fromRGB(110, 110, 115),
			Material = Enum.Material.Slate,
		})
	end
end

function Props.fence(parent: Instance, cf: CFrame, length: number)
	local posts = math.floor(length / 4)
	for i = 0, posts do
		P(parent, {
			Name = "FencePost",
			Size = Vector3.new(0.5, 4.5, 0.5),
			CFrame = cf * CFrame.new(-length / 2 + i * (length / posts), 2.25, 0),
			Color = COLORS.DarkWood,
			Material = Enum.Material.Wood,
		})
	end
	for _, y in { 1.5, 3.4 } do
		P(parent, {
			Name = "FenceRail",
			Size = Vector3.new(length, 0.4, 0.2),
			CFrame = cf * CFrame.new(0, y, 0),
			Color = COLORS.Wood,
			Material = Enum.Material.WoodPlanks,
		})
	end
	-- Сплошная невидимая стенка, чтобы через забор нельзя было пролезть
	P(parent, {
		Name = "FenceBlock",
		Size = Vector3.new(length, 4.5, 0.4),
		CFrame = cf * CFrame.new(0, 2.25, 0),
		Transparency = 1,
	})
end

-- Кукурузное поле: высокие стебли, сквозь которые можно пройти и спрятаться
function Props.corn(parent: Instance, cf: CFrame, rng: Random)
	for x = -8, 8, 1.6 do
		for z = -8, 8, 1.6 do
			local h = rng:NextNumber(6.5, 8.5)
			P(parent, {
				Name = "Corn",
				Size = Vector3.new(0.18, h, 0.18),
				CFrame = cf * CFrame.new(x + rng:NextNumber(-0.4, 0.4), h / 2, z + rng:NextNumber(-0.4, 0.4)) * A(
					rng:NextNumber(-6, 6),
					0,
					rng:NextNumber(-6, 6)
				),
				Color = Color3.fromRGB(150, 140, 70):Lerp(Color3.fromRGB(80, 100, 45), rng:NextNumber()),
				Material = Enum.Material.Grass,
				Decor = true,
			})
		end
	end
end

function Props.lamp(parent: Instance, cf: CFrame)
	P(parent, {
		Name = "LampPost",
		Size = Vector3.new(0.6, 12, 0.6),
		CFrame = cf * CFrame.new(0, 6, 0),
		Color = Color3.fromRGB(30, 30, 30),
		Material = Enum.Material.Metal,
	})
	P(parent, {
		Name = "LampArm",
		Size = Vector3.new(0.3, 0.3, 2),
		CFrame = cf * CFrame.new(0, 12, -0.8),
		Color = Color3.fromRGB(30, 30, 30),
		Material = Enum.Material.Metal,
		Decor = true,
	})
	local head = P(parent, {
		Name = "LampHead",
		Size = Vector3.new(1, 0.6, 1),
		CFrame = cf * CFrame.new(0, 11.7, -1.6),
		Color = Color3.fromRGB(255, 200, 120),
		Material = Enum.Material.Neon,
		Decor = true,
	})
	local light = Instance.new("SpotLight")
	light.Color = Color3.fromRGB(255, 170, 90)
	light.Range = 30
	light.Angle = 80
	light.Brightness = 2
	light.Shadows = true
	light.Face = Enum.NormalId.Bottom
	light.Parent = head
end

-- Низкий туман
function Props.fog(parent: Instance, pos: Vector3, rng: Random)
	local p = P(parent, {
		Name = "FogEmitter",
		Size = Vector3.new(20, 1, 20),
		CFrame = CFrame.new(pos),
		Transparency = 1,
		Decor = true,
	})
	local e = Instance.new("ParticleEmitter")
	e.Texture = SMOKE_TEX
	e.Color = ColorSequence.new(Color3.fromRGB(150, 155, 170))
	e.Size = NumberSequence.new(8, 14)
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.88),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(10, 16)
	e.Rate = 0.6
	e.Speed = NumberRange.new(0.3, 1)
	e.SpreadAngle = Vector2.new(180, 10)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-5, 5)
	e.LightInfluence = 1
	e.Parent = p
	if rng:NextNumber() < 0.4 then
		local flies = Instance.new("ParticleEmitter")
		flies.Name = "Fireflies"
		flies.Texture = SPARK_TEX
		flies.Color = ColorSequence.new(Color3.fromRGB(220, 255, 140))
		flies.LightEmission = 1
		flies.Size = NumberSequence.new(0.15)
		flies.Lifetime = NumberRange.new(4, 7)
		flies.Rate = 1.5
		flies.Speed = NumberRange.new(0.5, 1.2)
		flies.SpreadAngle = Vector2.new(180, 180)
		flies.Parent = p
	end
end

-- Огонь костра / бочки
function Props.fire(parent: Instance, cf: CFrame, size: number)
	local p = P(parent, {
		Name = "FireSource",
		Size = Vector3.new(size, 0.4, size),
		CFrame = cf,
		Transparency = 1,
		Decor = true,
	})
	local e = Instance.new("ParticleEmitter")
	e.Texture = FIRE_TEX
	e.Color = ColorSequence.new(Color3.fromRGB(255, 150, 50), Color3.fromRGB(255, 60, 20))
	e.LightEmission = 1
	e.Size = NumberSequence.new(size * 0.8, 0)
	e.Lifetime = NumberRange.new(0.6, 1.1)
	e.Rate = 30
	e.Speed = NumberRange.new(2, 4)
	e.SpreadAngle = Vector2.new(15, 15)
	e.Parent = p
	local light = Instance.new("PointLight")
	light.Name = "FireLight"
	light.Color = Color3.fromRGB(255, 140, 60)
	light.Range = 18 * size
	light.Brightness = 2
	light.Shadows = true
	light.Parent = p
	return p
end

return Props
