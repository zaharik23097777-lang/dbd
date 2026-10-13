-- Детализированные объекты карты. Всё строится из обычных деталей (Part),
-- поэтому не нужны модели из Toolbox.
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
-- Генератор
------------------------------------------------------------------------

function Props.generator(parent: Instance, cf: CFrame, index: number): Model
	local m = model("Generator" .. index)
	P(m, {
		Name = "Base",
		Size = Vector3.new(4.6, 0.5, 3.4),
		CFrame = cf * CFrame.new(0, 0.25, 0),
		Color = COLORS.Rust,
		Material = Enum.Material.CorrodedMetal,
	})
	local body = P(m, {
		Name = "Body",
		Size = Vector3.new(4, 3, 3),
		CFrame = cf * CFrame.new(0, 2, 0),
		Color = Color3.fromRGB(78, 84, 74),
		Material = Enum.Material.DiamondPlate,
	})
	P(m, {
		Name = "Engine",
		Size = Vector3.new(2.6, 1.3, 2.2),
		CFrame = cf * CFrame.new(-0.5, 4.15, 0),
		Color = Color3.fromRGB(45, 45, 45),
		Material = Enum.Material.Metal,
	})
	for i = 1, 2 do
		P(m, {
			Name = "Piston" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.3, 0.55, 0.55),
			CFrame = cf * CFrame.new(-1.1 + (i - 1) * 1.1, 5.2, 0) * A(0, 0, 90),
			Color = Color3.fromRGB(150, 150, 150),
			Material = Enum.Material.Metal,
			Decor = true,
		})
	end
	P(m, {
		Name = "Exhaust",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.2, 0.35, 0.35),
		CFrame = cf * CFrame.new(1.4, 4.4, 1) * A(0, 0, 90),
		Color = COLORS.Black,
		Material = Enum.Material.Metal,
		Decor = true,
	})
	-- Кабели к земле
	for i = 1, 3 do
		P(m, {
			Name = "Cable",
			Size = Vector3.new(0.15, 0.15, 3),
			CFrame = cf * CFrame.new(-1.5 + i * 0.6, 0.6, -2.7) * A(-12, (i - 2) * 15, 0),
			Color = COLORS.Black,
			Material = Enum.Material.Rubber,
			Decor = true,
		})
	end
	-- Лампочки прогресса (4 штуки)
	P(m, {
		Name = "LightBar",
		Size = Vector3.new(2.4, 0.25, 0.4),
		CFrame = cf * CFrame.new(0, 3.65, -1.55),
		Color = COLORS.Black,
		Material = Enum.Material.Metal,
		Decor = true,
	})
	for i = 1, 4 do
		P(m, {
			Name = "Light" .. i,
			Size = Vector3.new(0.35, 0.35, 0.2),
			CFrame = cf * CFrame.new(-0.9 + (i - 1) * 0.6, 3.65, -1.8),
			Color = Color3.fromRGB(45, 40, 30),
			Material = Enum.Material.Glass,
			Decor = true,
		})
	end
	-- Большая лампа, загорается после ремонта
	local bulb = P(m, {
		Name = "Bulb",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.1, 1.1, 1.1),
		CFrame = cf * CFrame.new(1.2, 5.3, -0.6),
		Color = Color3.fromRGB(60, 60, 50),
		Material = Enum.Material.Glass,
		Decor = true,
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 230, 150)
	light.Range = 28
	light.Brightness = 3
	light.Shadows = true
	light.Enabled = false
	light.Parent = bulb

	-- Искры и дым при провале проверки навыка
	local fx = Instance.new("Attachment")
	fx.Name = "FX"
	fx.Position = Vector3.new(0, 1.8, 0)
	fx.Parent = body
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Texture = SPARK_TEX
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 190, 80))
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.3, 0)
	sparks.Speed = NumberRange.new(10, 18)
	sparks.SpreadAngle = Vector2.new(70, 70)
	sparks.Lifetime = NumberRange.new(0.3, 0.7)
	sparks.Acceleration = Vector3.new(0, -40, 0)
	sparks.Enabled = false
	sparks.Parent = fx
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Smoke"
	smoke.Texture = SMOKE_TEX
	smoke.Color = ColorSequence.new(Color3.fromRGB(40, 40, 40))
	smoke.Size = NumberSequence.new(1.5, 5)
	smoke.Transparency = NumberSequence.new(0.3, 1)
	smoke.Speed = NumberRange.new(3, 6)
	smoke.Lifetime = NumberRange.new(1.5, 2.5)
	smoke.Enabled = false
	smoke.Parent = fx

	m.PrimaryPart = body
	m:SetAttribute("Kind", "Generator")
	m:SetAttribute("Progress", 0)
	m:SetAttribute("Done", false)
	m:SetAttribute("Regressing", false)
	m.Parent = parent
	return m
end

------------------------------------------------------------------------
-- Крюк
------------------------------------------------------------------------

function Props.hook(parent: Instance, cf: CFrame, index: number): Model
	local m = model("Hook" .. index)
	local red = Color3.fromRGB(95, 25, 20)
	P(m, {
		Name = "Base",
		Size = Vector3.new(2.6, 0.8, 2.6),
		CFrame = cf * CFrame.new(0, 0.4, 0) * A(0, 20, 0),
		Color = Color3.fromRGB(70, 65, 60),
		Material = Enum.Material.Slate,
	})
	local pole = P(m, {
		Name = "Pole",
		Size = Vector3.new(0.9, 12, 0.9),
		CFrame = cf * CFrame.new(0, 6, 0),
		Color = red,
		Material = Enum.Material.CorrodedMetal,
	})
	P(m, {
		Name = "Arm",
		Size = Vector3.new(0.7, 0.7, 4.4),
		CFrame = cf * CFrame.new(0, 11.4, -2),
		Color = red,
		Material = Enum.Material.CorrodedMetal,
	})
	P(m, {
		Name = "Brace",
		Size = Vector3.new(0.4, 0.4, 3),
		CFrame = cf * CFrame.new(0, 10.3, -1) * A(-45, 0, 0),
		Color = red,
		Material = Enum.Material.CorrodedMetal,
		Decor = true,
	})
	-- Цепь из звеньев
	for i = 1, 4 do
		P(m, {
			Name = "Link",
			Size = Vector3.new(0.12, 0.45, 0.25),
			CFrame = cf * CFrame.new(0, 11 - i * 0.4, -3.9) * A(0, i % 2 == 0 and 90 or 0, 0),
			Color = Color3.fromRGB(80, 80, 80),
			Material = Enum.Material.Metal,
			Decor = true,
		})
	end
	-- Сам крюк (изогнутый из трёх частей)
	local steel = Color3.fromRGB(160, 155, 150)
	P(m, {
		Name = "HookShaft",
		Size = Vector3.new(0.25, 1.4, 0.25),
		CFrame = cf * CFrame.new(0, 8.8, -3.9),
		Color = steel,
		Material = Enum.Material.Metal,
		Decor = true,
	})
	P(m, {
		Name = "HookCurve",
		Size = Vector3.new(0.25, 0.25, 0.9),
		CFrame = cf * CFrame.new(0, 8.1, -3.55),
		Color = steel,
		Material = Enum.Material.Metal,
		Decor = true,
	})
	P(m, {
		Name = "HookTip",
		Size = Vector3.new(0.22, 0.8, 0.22),
		CFrame = cf * CFrame.new(0, 8.45, -3.15) * A(-15, 0, 0),
		Color = steel,
		Material = Enum.Material.Metal,
		Decor = true,
	})
	-- Пятно крови под крюком
	P(m, {
		Name = "Blood",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.05, 2.6, 2.6),
		CFrame = cf * CFrame.new(0, 0.03, -3.9) * A(0, 0, 90),
		Color = Color3.fromRGB(70, 5, 5),
		Material = Enum.Material.SmoothPlastic,
		Decor = true,
	})
	-- Точка, где висит выживший (HumanoidRootPart), смотрит от столба
	P(m, {
		Name = "HangPoint",
		Size = Vector3.new(1, 1, 1),
		CFrame = cf * CFrame.new(0.25, 7, -4.3),
		Transparency = 1,
		Decor = true,
	})
	m.PrimaryPart = pole
	m:SetAttribute("Kind", "Hook")
	m:SetAttribute("Occupant", 0)
	m.Parent = parent
	return m
end

-- Лапы Сущности вокруг крюка (на 2-й стадии и при жертвоприношении)
function Props.entityLegs(hook: Model, count: number): Model
	local hp = hook:FindFirstChild("HangPoint") :: BasePart
	local m = model("EntityLegs", hook)
	for i = 1, count do
		local angle = (i / count) * math.pi * 2
		local base = hp.CFrame * CFrame.new(math.cos(angle) * 3.5, 5, math.sin(angle) * 3.5)
		local look = CFrame.lookAt(base.Position, hp.Position + Vector3.new(0, 1, 0))
		P(m, {
			Name = "Leg",
			Size = Vector3.new(0.35, 0.35, 7),
			CFrame = look * CFrame.new(0, 0, -3.5),
			Color = Color3.fromRGB(25, 10, 10),
			Material = Enum.Material.Slate,
			Decor = true,
		})
		P(m, {
			Name = "Tip",
			Size = Vector3.new(0.2, 0.2, 1.4),
			CFrame = look * CFrame.new(0, 0, -7.4),
			Color = Color3.fromRGB(200, 40, 20),
			Material = Enum.Material.Neon,
			Decor = true,
		})
	end
	return m
end

------------------------------------------------------------------------
-- Паллета (модель из досок + невидимый хитбокс)
------------------------------------------------------------------------

function Props.pallet(parent: Instance, upCF: CFrame, dropCF: CFrame): Model
	local m = model("Pallet")
	local hitbox = P(m, {
		Name = "Hitbox",
		Size = Vector3.new(5.6, 3, 1.2),
		CFrame = upCF,
		Transparency = 1,
		CanCollide = false,
	})
	local wood = Color3.fromRGB(150, 112, 66)
	-- Поперечные доски
	for i = 0, 3 do
		P(m, {
			Name = "Slat",
			Size = Vector3.new(5.6, 0.55, 0.2),
			CFrame = upCF * CFrame.new(0, -1.15 + i * 0.77, -0.45),
			Color = wood:Lerp(Color3.new(0, 0, 0), (i % 2) * 0.1),
			Material = Enum.Material.WoodPlanks,
			Decor = true,
		})
		P(m, {
			Name = "Slat",
			Size = Vector3.new(5.6, 0.55, 0.2),
			CFrame = upCF * CFrame.new(0, -1.15 + i * 0.77, 0.45),
			Color = wood:Lerp(Color3.new(0, 0, 0), 0.15),
			Material = Enum.Material.WoodPlanks,
			Decor = true,
		})
	end
	-- Продольные бруски
	for _, x in { -2.4, 0, 2.4 } do
		P(m, {
			Name = "Stringer",
			Size = Vector3.new(0.5, 3, 0.7),
			CFrame = upCF * CFrame.new(x, 0, 0),
			Color = wood:Lerp(Color3.new(0, 0, 0), 0.25),
			Material = Enum.Material.Wood,
			Decor = true,
		})
	end
	m.PrimaryPart = hitbox
	m:SetAttribute("Kind", "Pallet")
	m:SetAttribute("State", "Up")
	m:SetAttribute("DropCFrame", dropCF)
	m.Parent = parent
	return m
end

------------------------------------------------------------------------
-- Шкафчик
------------------------------------------------------------------------

-- cf — точка на полу, -Z смотрит наружу (дверь спереди)
function Props.locker(parent: Instance, cf: CFrame): Model
	local m = model("Locker")
	local metal = Color3.fromRGB(70, 85, 80)
	local back = P(m, {
		Name = "Back",
		Size = Vector3.new(3, 7.2, 0.2),
		CFrame = cf * CFrame.new(0, 3.6, 1.2),
		Color = metal,
		Material = Enum.Material.CorrodedMetal,
	})
	for _, x in { -1.5, 1.5 } do
		P(m, {
			Name = "Side",
			Size = Vector3.new(0.2, 7.2, 2.6),
			CFrame = cf * CFrame.new(x, 3.6, 0),
			Color = metal,
			Material = Enum.Material.CorrodedMetal,
		})
	end
	P(m, {
		Name = "Top",
		Size = Vector3.new(3.2, 0.2, 2.6),
		CFrame = cf * CFrame.new(0, 7.3, 0),
		Color = metal,
		Material = Enum.Material.CorrodedMetal,
	})
	P(m, {
		Name = "Bottom",
		Size = Vector3.new(3, 0.2, 2.6),
		CFrame = cf * CFrame.new(0, 0.1, 0),
		Color = metal,
		Material = Enum.Material.CorrodedMetal,
	})
	-- Дверь крутится вокруг левого края (петли)
	local closed = cf * CFrame.new(0, 3.6, -1.3)
	P(m, {
		Name = "Door",
		Size = Vector3.new(2.8, 7, 0.15),
		CFrame = closed,
		Color = metal:Lerp(Color3.new(1, 1, 1), 0.08),
		Material = Enum.Material.CorrodedMetal,
	})
	for i = 1, 4 do
		local offset = CFrame.new(0, 2.6 - i * 0.3, -0.1)
		local slit = P(m, {
			Name = "Slit",
			Size = Vector3.new(1.6, 0.12, 0.05),
			CFrame = closed * offset,
			Color = COLORS.Black,
			Decor = true,
		})
		slit:SetAttribute("DoorOffset", offset)
	end
	m:SetAttribute("DoorClosed", closed)
	m:SetAttribute("Hinge", cf * CFrame.new(-1.4, 3.6, -1.3))
	P(m, {
		Name = "Inside",
		Size = Vector3.new(1, 1, 1),
		CFrame = cf * CFrame.new(0, 3, 0.2),
		Transparency = 1,
		Decor = true,
	})
	m.PrimaryPart = back
	m:SetAttribute("Kind", "Locker")
	m:SetAttribute("Occupant", 0)
	m.Parent = parent
	return m
end

-- Открывает/закрывает дверь шкафчика (angle = градусы)
function Props.setLockerDoor(locker: Model, angle: number)
	local hinge = locker:GetAttribute("Hinge") :: CFrame
	local closed = locker:GetAttribute("DoorClosed") :: CFrame
	if not hinge or not closed then
		return
	end
	local rot = hinge * A(0, -angle, 0) * hinge:Inverse()
	local doorCF = rot * closed
	local door = locker:FindFirstChild("Door") :: BasePart?
	if door then
		door.CFrame = doorCF
	end
	for _, d in locker:GetChildren() do
		local offset = d:GetAttribute("DoorOffset")
		if offset and d:IsA("BasePart") then
			d.CFrame = doorCF * (offset :: CFrame)
		end
	end
end

------------------------------------------------------------------------
-- Тотем
------------------------------------------------------------------------

function Props.totem(parent: Instance, cf: CFrame, hex: boolean, rng: Random): Model
	local m = model("Totem")
	local base = P(m, {
		Name = "Base",
		Size = Vector3.new(2.4, 0.6, 2.4),
		CFrame = cf * CFrame.new(0, 0.3, 0) * A(0, 30, 0),
		Color = Color3.fromRGB(60, 50, 40),
		Material = Enum.Material.Ground,
	})
	-- Кучка костей
	for _ = 1, 9 do
		P(m, {
			Name = "Bone",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(rng:NextNumber(0.8, 1.6), 0.25, 0.25),
			CFrame = cf
				* CFrame.new(rng:NextNumber(-0.8, 0.8), rng:NextNumber(0.6, 1.8), rng:NextNumber(-0.8, 0.8))
				* A(rng:NextNumber(-60, 60), rng:NextNumber(0, 180), rng:NextNumber(-60, 60)),
			Color = COLORS.Bone,
			Material = Enum.Material.SmoothPlastic,
			Decor = true,
		})
	end
	P(m, {
		Name = "Stake",
		Size = Vector3.new(0.3, 3.2, 0.3),
		CFrame = cf * CFrame.new(0, 2, 0),
		Color = COLORS.DarkWood,
		Material = Enum.Material.Wood,
		Decor = true,
	})
	local skull = P(m, {
		Name = "Skull",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.1, 1.1, 1.1),
		CFrame = cf * CFrame.new(0, 3.5, 0),
		Color = COLORS.Bone,
		Material = Enum.Material.SmoothPlastic,
		Decor = true,
	})
	for _, x in { -0.22, 0.22 } do
		local eye = P(m, {
			Name = "Eye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.3, 0.3, 0.3),
			CFrame = skull.CFrame * CFrame.new(x, 0.08, -0.43),
			Color = hex and Color3.fromRGB(255, 60, 20) or COLORS.Black,
			Material = hex and Enum.Material.Neon or Enum.Material.SmoothPlastic,
			Decor = true,
		})
		eye:SetAttribute("SkullPart", true)
	end
	-- Свечи вокруг
	for i = 1, 5 do
		local angle = i / 5 * math.pi * 2
		local h = rng:NextNumber(0.4, 0.9)
		local candle = P(m, {
			Name = "Candle",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(h, 0.25, 0.25),
			CFrame = cf * CFrame.new(math.cos(angle) * 1.4, 0.6 + h / 2, math.sin(angle) * 1.4) * A(0, 0, 90),
			Color = Color3.fromRGB(230, 220, 180),
			Material = Enum.Material.SmoothPlastic,
			Decor = true,
		})
		if hex then
			local flame = P(m, {
				Name = "Flame",
				Size = Vector3.new(0.12, 0.25, 0.12),
				CFrame = candle.CFrame * A(0, 0, -90) * CFrame.new(0, h / 2 + 0.12, 0),
				Color = Color3.fromRGB(255, 170, 60),
				Material = Enum.Material.Neon,
				Decor = true,
			})
			if i == 1 then
				local light = Instance.new("PointLight")
				light.Color = Color3.fromRGB(255, 120, 50)
				light.Range = 10
				light.Brightness = 2
				light.Parent = flame
			end
		end
	end
	m.PrimaryPart = base
	m:SetAttribute("Kind", "Totem")
	m:SetAttribute("Hex", hex)
	m:SetAttribute("Progress", 0)
	m:SetAttribute("Cleansed", false)
	m.Parent = parent
	return m
end

------------------------------------------------------------------------
-- Сундук
------------------------------------------------------------------------

function Props.chest(parent: Instance, cf: CFrame): Model
	local m = model("Chest")
	local base = P(m, {
		Name = "Box",
		Size = Vector3.new(3, 1.6, 2),
		CFrame = cf * CFrame.new(0, 0.8, 0),
		Color = COLORS.Wood,
		Material = Enum.Material.WoodPlanks,
	})
	local lidClosed = cf * CFrame.new(0, 1.85, 0)
	P(m, {
		Name = "Lid",
		Size = Vector3.new(3.1, 0.5, 2.1),
		CFrame = lidClosed,
		Color = COLORS.DarkWood,
		Material = Enum.Material.WoodPlanks,
	})
	for _, x in { -1, 1 } do
		P(m, {
			Name = "Band",
			Size = Vector3.new(0.25, 2.2, 2.15),
			CFrame = cf * CFrame.new(x, 1.1, 0),
			Color = COLORS.Metal,
			Material = Enum.Material.Metal,
			Decor = true,
		})
	end
	P(m, {
		Name = "Lock",
		Size = Vector3.new(0.4, 0.5, 0.15),
		CFrame = cf * CFrame.new(0, 1.5, -1.08),
		Color = Color3.fromRGB(180, 150, 60),
		Material = Enum.Material.Metal,
		Decor = true,
	})
	m:SetAttribute("LidClosed", lidClosed)
	m:SetAttribute("LidHinge", cf * CFrame.new(0, 2.1, 1.05))
	m.PrimaryPart = base
	m:SetAttribute("Kind", "Chest")
	m:SetAttribute("Opened", false)
	m.Parent = parent
	return m
end

function Props.openChest(chest: Model)
	local hinge = chest:GetAttribute("LidHinge") :: CFrame
	local closed = chest:GetAttribute("LidClosed") :: CFrame
	local lid = chest:FindFirstChild("Lid") :: BasePart?
	if hinge and closed and lid then
		lid.CFrame = hinge * A(70, 0, 0) * hinge:Inverse() * closed
	end
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 220, 140)
	glow.Range = 6
	glow.Brightness = 1
	glow.Parent = chest.PrimaryPart
end

------------------------------------------------------------------------
-- Люк
------------------------------------------------------------------------

function Props.hatch(parent: Instance, cf: CFrame): Model
	local m = model("Hatch")
	local frame = P(m, {
		Name = "Frame",
		Size = Vector3.new(4.4, 0.3, 4.4),
		CFrame = cf * CFrame.new(0, 0.15, 0),
		Color = COLORS.Rust,
		Material = Enum.Material.CorrodedMetal,
		CanCollide = false,
	})
	P(m, {
		Name = "Pit",
		Size = Vector3.new(3.6, 0.1, 3.6),
		CFrame = cf * CFrame.new(0, 0.32, 0),
		Color = COLORS.Black,
		Material = Enum.Material.SmoothPlastic,
		Decor = true,
	})
	for i, x in { -0.9, 0.9 } do
		local door = P(m, {
			Name = "Door" .. i,
			Size = Vector3.new(1.8, 0.15, 3.6),
			CFrame = cf * CFrame.new(x, 0.42, 0),
			Color = COLORS.Metal,
			Material = Enum.Material.DiamondPlate,
			Decor = true,
		})
		door:SetAttribute("Closed", door.CFrame)
		door:SetAttribute("Hinge", cf * CFrame.new(x * 2, 0.42, 0))
		door:SetAttribute("Sign", x > 0 and 1 or -1)
	end
	local glow = Instance.new("PointLight")
	glow.Name = "Glow"
	glow.Color = Color3.fromRGB(180, 200, 255)
	glow.Range = 14
	glow.Brightness = 2
	glow.Enabled = false
	glow.Parent = frame
	m.PrimaryPart = frame
	m:SetAttribute("Kind", "Hatch")
	m:SetAttribute("Open", false)
	m:SetAttribute("Closed", false)
	m.Parent = parent
	return m
end

function Props.setHatchOpen(hatch: Model, open: boolean)
	for _, d in hatch:GetChildren() do
		if d:IsA("BasePart") and d.Name:match("^Door") then
			local closed = d:GetAttribute("Closed") :: CFrame
			local hinge = d:GetAttribute("Hinge") :: CFrame
			local sign = d:GetAttribute("Sign") :: number
			if open then
				d.CFrame = hinge * A(0, 0, -100 * sign) * hinge:Inverse() * closed
			else
				d.CFrame = closed
			end
		end
	end
	local frame = hatch.PrimaryPart
	local glow = frame and frame:FindFirstChild("Glow") :: PointLight?
	if glow then
		glow.Enabled = open
	end
end

------------------------------------------------------------------------
-- Медвежий капкан
------------------------------------------------------------------------

function Props.trap(parent: Instance, cf: CFrame): Model
	local m = model("BearTrap")
	local base = P(m, {
		Name = "Plate",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.15, 1.2, 1.2),
		CFrame = cf * CFrame.new(0, 0.08, 0) * A(0, 0, 90),
		Color = Color3.fromRGB(70, 65, 60),
		Material = Enum.Material.CorrodedMetal,
		CanCollide = false,
	})
	for i = 1, 2 do
		P(m, {
			Name = "Jaw" .. i,
			Size = Vector3.new(2.2, 0.12, 0.7),
			CFrame = cf,
			Color = Color3.fromRGB(110, 105, 100),
			Material = Enum.Material.Metal,
			Decor = true,
		})
		for t = -2, 2 do
			local tooth = P(m, {
				Name = "Tooth" .. i,
				Size = Vector3.new(0.14, 0.4, 0.14),
				CFrame = cf,
				Color = Color3.fromRGB(150, 145, 140),
				Material = Enum.Material.Metal,
				Decor = true,
			})
			tooth:SetAttribute("Offset", t * 0.45)
		end
	end
	P(m, {
		Name = "Chain",
		Size = Vector3.new(0.12, 0.12, 2),
		CFrame = cf * CFrame.new(0, 0.06, 1.4),
		Color = COLORS.Black,
		Material = Enum.Material.Metal,
		Decor = true,
	})
	m.PrimaryPart = base
	m:SetAttribute("Kind", "Trap")
	m:SetAttribute("Armed", true)
	m:SetAttribute("Caught", 0)
	m:SetAttribute("Origin", cf)
	m.Parent = parent
	Props.setTrapArmed(m, true)
	return m
end

function Props.setTrapArmed(trap: Model, armed: boolean)
	local cf = trap:GetAttribute("Origin") :: CFrame
	for i = 1, 2 do
		local side = i == 1 and -1 or 1
		local jawCF
		if armed then
			jawCF = cf * CFrame.new(0, 0.12, side * 0.85)
		else
			jawCF = cf * CFrame.new(0, 0.55, side * 0.18) * A(side * 75, 0, 0)
		end
		local jaw = trap:FindFirstChild("Jaw" .. i) :: BasePart?
		if jaw then
			jaw.CFrame = jawCF
		end
		for _, d in trap:GetChildren() do
			if d.Name == "Tooth" .. i and d:IsA("BasePart") then
				local off = d:GetAttribute("Offset") :: number
				d.CFrame = jawCF * CFrame.new(off, 0.2, -side * 0.3)
			end
		end
	end
end

------------------------------------------------------------------------
-- Ворона
------------------------------------------------------------------------

function Props.crow(parent: Instance, cf: CFrame): Model
	local m = model("Crow")
	local black = Color3.fromRGB(15, 15, 18)
	local body = P(m, {
		Name = "Body",
		Size = Vector3.new(0.45, 0.45, 0.9),
		CFrame = cf * CFrame.new(0, 0.35, 0),
		Color = black,
		Decor = true,
	})
	P(m, {
		Name = "Head",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.38, 0.38, 0.38),
		CFrame = cf * CFrame.new(0, 0.65, -0.45),
		Color = black,
		Decor = true,
	})
	P(m, {
		Name = "Beak",
		Size = Vector3.new(0.1, 0.1, 0.3),
		CFrame = cf * CFrame.new(0, 0.62, -0.72),
		Color = Color3.fromRGB(60, 55, 40),
		Decor = true,
	})
	for _, x in { -0.3, 0.3 } do
		P(m, {
			Name = "Wing",
			Size = Vector3.new(0.12, 0.35, 0.75),
			CFrame = cf * CFrame.new(x, 0.38, 0.05),
			Color = black,
			Decor = true,
		})
	end
	P(m, {
		Name = "Tail",
		Size = Vector3.new(0.3, 0.08, 0.45),
		CFrame = cf * CFrame.new(0, 0.4, 0.6) * A(15, 0, 0),
		Color = black,
		Decor = true,
	})
	m.PrimaryPart = body
	m:SetAttribute("Kind", "Crow")
	m.Parent = parent
	return m
end

------------------------------------------------------------------------
-- Ворота выхода
------------------------------------------------------------------------

function Props.exitGate(parent: Instance, side: number, index: number): Model
	local half = Config.MapSize / 2
	local cf = CFrame.new(0, 0, side * half) * A(0, side == 1 and 0 or 180, 0)
	-- В локальных координатах: -Z внутрь карты, +Z наружу.
	local m = model("ExitGate" .. index)
	local metal = Color3.fromRGB(60, 60, 65)

	P(m, {
		Name = "Door",
		Size = Vector3.new(12, 12, 1),
		CFrame = cf * CFrame.new(0, 6, 0),
		Color = metal,
		Material = Enum.Material.DiamondPlate,
	})
	for i = -2, 2 do
		P(m, {
			Name = "DoorRib",
			Size = Vector3.new(0.4, 12, 1.3),
			CFrame = cf * CFrame.new(i * 2.4, 6, 0),
			Color = metal:Lerp(Color3.new(0, 0, 0), 0.3),
			Material = Enum.Material.Metal,
			Decor = true,
		})
	end
	for _, x in { -7, 7 } do
		P(m, {
			Name = "Pillar",
			Size = Vector3.new(2, 16, 2.5),
			CFrame = cf * CFrame.new(x, 8, 0),
			Color = Color3.fromRGB(50, 48, 46),
			Material = Enum.Material.Concrete,
		})
	end
	P(m, {
		Name = "Frame",
		Size = Vector3.new(16, 2.5, 2.5),
		CFrame = cf * CFrame.new(0, 14.75, 0),
		Color = Color3.fromRGB(40, 40, 40),
		Material = Enum.Material.Metal,
	})
	-- Пульт с рычагом
	local switch = P(m, {
		Name = "Switch",
		Size = Vector3.new(2.2, 4, 1.4),
		CFrame = cf * CFrame.new(10, 2, -2.2),
		Color = Color3.fromRGB(50, 50, 50),
		Material = Enum.Material.Metal,
	})
	P(m, {
		Name = "LeverBase",
		Size = Vector3.new(0.5, 0.5, 0.5),
		CFrame = switch.CFrame * CFrame.new(0, 0.6, -0.8),
		Color = COLORS.Black,
		Material = Enum.Material.Metal,
		Decor = true,
	})
	P(m, {
		Name = "Lever",
		Size = Vector3.new(0.25, 1.6, 0.25),
		CFrame = switch.CFrame * CFrame.new(0, 1.3, -0.8) * A(-35, 0, 0),
		Color = Color3.fromRGB(150, 30, 30),
		Material = Enum.Material.Metal,
		Decor = true,
	})
	m:SetAttribute("LeverPivot", switch.CFrame * CFrame.new(0, 0.6, -0.8))
	for i = 1, 3 do
		P(m, {
			Name = "Lamp" .. i,
			Size = Vector3.new(0.5, 0.5, 0.3),
			CFrame = switch.CFrame * CFrame.new(-0.6 + (i - 1) * 0.6, 1.5, -0.75),
			Color = Color3.fromRGB(40, 0, 0),
			Material = Enum.Material.Neon,
			Decor = true,
		})
	end
	-- Сирена
	local siren = P(m, {
		Name = "Siren",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1, 1, 1),
		CFrame = cf * CFrame.new(-7, 16.5, -1),
		Color = Color3.fromRGB(80, 10, 10),
		Material = Enum.Material.Glass,
		Decor = true,
	})
	local sirenLight = Instance.new("SpotLight")
	sirenLight.Name = "SirenLight"
	sirenLight.Color = Color3.fromRGB(255, 30, 20)
	sirenLight.Range = 30
	sirenLight.Brightness = 4
	sirenLight.Angle = 60
	sirenLight.Face = Enum.NormalId.Front
	sirenLight.Enabled = false
	sirenLight.Parent = siren

	-- Коридор за воротами и зона побега
	P(m, {
		Name = "Corridor",
		Size = Vector3.new(12, 1, 30),
		CFrame = cf * CFrame.new(0, -0.5, 15.75),
		Color = Color3.fromRGB(50, 45, 40),
		Material = Enum.Material.Ground,
	})
	Props.wall(m, cf * CFrame.new(-6.75, 6, 15.75), Vector3.new(1.5, 12, 30))
	Props.wall(m, cf * CFrame.new(6.75, 6, 15.75), Vector3.new(1.5, 12, 30))
	local escape = P(m, {
		Name = "EscapeZone",
		Size = Vector3.new(12, 12, 10),
		CFrame = cf * CFrame.new(0, 6, 24),
		Transparency = 0.6,
		Color = Color3.fromRGB(255, 255, 255),
		Material = Enum.Material.ForceField,
		Decor = true,
	})
	local glow = Instance.new("PointLight")
	glow.Range = 40
	glow.Brightness = 2
	glow.Parent = escape

	m.PrimaryPart = switch
	m:SetAttribute("Kind", "ExitGate")
	m:SetAttribute("Powered", false)
	m:SetAttribute("Progress", 0)
	m:SetAttribute("Open", false)
	m.Parent = parent
	return m
end

function Props.setGateLever(gate: Model, progress: number)
	local pivot = gate:GetAttribute("LeverPivot") :: CFrame
	local lever = gate:FindFirstChild("Lever") :: BasePart?
	if pivot and lever then
		local angle = -35 + 70 * math.clamp(progress, 0, 1)
		lever.CFrame = pivot * A(angle, 0, 0) * CFrame.new(0, 0.7, 0)
	end
	for i = 1, 3 do
		local lamp = gate:FindFirstChild("Lamp" .. i) :: BasePart?
		if lamp then
			lamp.Color = progress >= i / 3 and Color3.fromRGB(255, 40, 40) or Color3.fromRGB(40, 0, 0)
		end
	end
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
