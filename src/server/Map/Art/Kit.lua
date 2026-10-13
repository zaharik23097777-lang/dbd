-- Набор инструментов для моделирования из деталей (Part).
-- Все художественные модули (MapProps, Structures, Nature, KillerGear, Items, Lobby) строят модели через Kit,
-- чтобы стиль, флаги производительности и запасные варианты (CSG) были одинаковыми.
local Kit = {}

local rad = math.rad
local Mat = Enum.Material
Kit.Mat = Mat

------------------------------------------------------------------------
-- Палитра (мрачная, приглушённая, как в DBD)
------------------------------------------------------------------------

Kit.Palette = {
	Rust = Color3.fromRGB(112, 62, 38),
	DarkRust = Color3.fromRGB(70, 40, 28),
	Steel = Color3.fromRGB(120, 122, 125),
	DarkSteel = Color3.fromRGB(58, 60, 64),
	Iron = Color3.fromRGB(42, 42, 45),
	Paint = Color3.fromRGB(74, 86, 70), -- облезлая армейская краска
	Wood = Color3.fromRGB(110, 82, 55),
	OldWood = Color3.fromRGB(92, 78, 64),
	DarkWood = Color3.fromRGB(62, 46, 34),
	Plank = Color3.fromRGB(128, 100, 70),
	Bone = Color3.fromRGB(222, 212, 186),
	OldBone = Color3.fromRGB(190, 176, 146),
	Blood = Color3.fromRGB(92, 8, 8),
	DryBlood = Color3.fromRGB(60, 10, 8),
	Concrete = Color3.fromRGB(104, 102, 98),
	DarkConcrete = Color3.fromRGB(70, 69, 66),
	Brick = Color3.fromRGB(116, 62, 48),
	Plaster = Color3.fromRGB(150, 140, 120),
	Roof = Color3.fromRGB(60, 50, 46),
	Leaf = Color3.fromRGB(34, 50, 32),
	Pine = Color3.fromRGB(28, 44, 32),
	Grass = Color3.fromRGB(56, 70, 40),
	Hay = Color3.fromRGB(186, 158, 92),
	Fabric = Color3.fromRGB(90, 78, 60),
	Leather = Color3.fromRGB(70, 48, 34),
	Rubber = Color3.fromRGB(28, 28, 30),
	Warning = Color3.fromRGB(210, 170, 40),
	Wax = Color3.fromRGB(232, 222, 190),
	Flame = Color3.fromRGB(255, 170, 70),
	Neon = Color3.fromRGB(255, 220, 140),
	Black = Color3.fromRGB(18, 18, 20),
}

------------------------------------------------------------------------
-- Случайность и цвет
------------------------------------------------------------------------

-- Небольшое случайное отклонение яркости/оттенка, чтобы одинаковые детали не выглядели клонами
function Kit.jitter(color: Color3, amount: number?, rng: Random?): Color3
	local a = amount or 0.06
	local r = rng and rng:NextNumber(-a, a) or 0
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, math.clamp(s + r * 0.5, 0, 1), math.clamp(v + r, 0, 1))
end

function Kit.dark(color: Color3, k: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), k)
end

function Kit.A(x: number?, y: number?, z: number?): CFrame
	return CFrame.Angles(rad(x or 0), rad(y or 0), rad(z or 0))
end

------------------------------------------------------------------------
-- Детали
------------------------------------------------------------------------

export type Props = { [string]: any }

-- Базовое создание детали. Флаг Decor = мелочь без столкновений/лучей/тени.
function Kit.part(parent: Instance?, props: Props, className: string?): BasePart
	local p = Instance.new(className or "Part") :: BasePart
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Mat.SmoothPlastic
	local decor = props.Decor
	for k, v in props do
		if k ~= "Decor" and k ~= "Parent" then
			(p :: any)[k] = v
		end
	end
	if decor then
		Kit.decor(p)
	end
	if parent then
		p.Parent = parent
	end
	return p
end

function Kit.decor(p: BasePart)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
end

local function merge(base: Props, extra: Props?): Props
	if extra then
		for k, v in extra do
			base[k] = v
		end
	end
	return base
end

function Kit.box(parent: Instance?, cf: CFrame, size: Vector3, color: Color3, material: Enum.Material?, extra: Props?): BasePart
	return Kit.part(parent, merge({ CFrame = cf, Size = size, Color = color, Material = material or Mat.SmoothPlastic }, extra))
end

-- Клин: наклонная грань смотрит вперёд (-Z) и вверх, высокая сторона сзади (+Z)
function Kit.wedge(parent: Instance?, cf: CFrame, size: Vector3, color: Color3, material: Enum.Material?, extra: Props?): BasePart
	return Kit.part(
		parent,
		merge({ CFrame = cf, Size = size, Color = color, Material = material or Mat.SmoothPlastic }, extra),
		"WedgePart"
	)
end

-- Цилиндр вдоль локальной оси X: length — длина, diameter — диаметр
function Kit.cyl(parent: Instance?, cf: CFrame, length: number, diameter: number, color: Color3, material: Enum.Material?, extra: Props?): BasePart
	return Kit.part(
		parent,
		merge({
			Shape = Enum.PartType.Cylinder,
			CFrame = cf,
			Size = Vector3.new(length, diameter, diameter),
			Color = color,
			Material = material or Mat.SmoothPlastic,
		}, extra)
	)
end

-- Вертикальный цилиндр (ось Y) с центром в cf
function Kit.vcyl(parent: Instance?, cf: CFrame, height: number, diameter: number, color: Color3, material: Enum.Material?, extra: Props?): BasePart
	return Kit.cyl(parent, cf * CFrame.Angles(0, 0, rad(90)), height, diameter, color, material, extra)
end

function Kit.ball(parent: Instance?, cf: CFrame, diameter: number, color: Color3, material: Enum.Material?, extra: Props?): BasePart
	return Kit.part(
		parent,
		merge({
			Shape = Enum.PartType.Ball,
			CFrame = cf,
			Size = Vector3.new(diameter, diameter, diameter),
			Color = color,
			Material = material or Mat.SmoothPlastic,
		}, extra)
	)
end

-- Брусок/палка между двумя точками (квадратное сечение thickness x depth)
function Kit.bar(parent: Instance?, a: Vector3, b: Vector3, thickness: number, color: Color3, material: Enum.Material?, extra: Props?, depth: number?): BasePart?
	local d = b - a
	local len = d.Magnitude
	if len < 1e-3 then
		return nil
	end
	local cf = CFrame.lookAt((a + b) / 2, b)
	return Kit.box(parent, cf, Vector3.new(thickness, depth or thickness, len), color, material, extra)
end

-- Цилиндр между двумя точками
function Kit.rod(parent: Instance?, a: Vector3, b: Vector3, diameter: number, color: Color3, material: Enum.Material?, extra: Props?): BasePart?
	local d = b - a
	local len = d.Magnitude
	if len < 1e-3 then
		return nil
	end
	local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, rad(90), 0)
	return Kit.cyl(parent, cf, len, diameter, color, material, extra)
end

-- Коробка со скошенными верхними рёбрами (выглядит менее «пластмассово»). 6 деталей.
function Kit.bevelBox(parent: Instance?, cf: CFrame, size: Vector3, bevel: number, color: Color3, material: Enum.Material?, extra: Props?)
	local b = math.min(bevel, size.X / 3, size.Z / 3, size.Y / 2)
	local parts = {}
	table.insert(parts, Kit.box(parent, cf * CFrame.new(0, -b / 2, 0), Vector3.new(size.X, size.Y - b, size.Z), color, material, extra))
	table.insert(parts, Kit.box(parent, cf * CFrame.new(0, size.Y / 2 - b / 2, 0), Vector3.new(size.X - 2 * b, b, size.Z - 2 * b), color, material, extra))
	local hx, hz, y = size.X / 2, size.Z / 2, size.Y / 2 - b / 2
	-- Клинья вдоль четырёх верхних рёбер
	table.insert(parts, Kit.wedge(parent, cf * CFrame.new(0, y, -hz + b / 2) * CFrame.Angles(0, 0, 0), Vector3.new(size.X - 2 * b, b, b), color, material, extra))
	table.insert(parts, Kit.wedge(parent, cf * CFrame.new(0, y, hz - b / 2) * CFrame.Angles(0, math.pi, 0), Vector3.new(size.X - 2 * b, b, b), color, material, extra))
	table.insert(parts, Kit.wedge(parent, cf * CFrame.new(-hx + b / 2, y, 0) * CFrame.Angles(0, rad(-90), 0), Vector3.new(size.Z - 2 * b, b, b), color, material, extra))
	table.insert(parts, Kit.wedge(parent, cf * CFrame.new(hx - b / 2, y, 0) * CFrame.Angles(0, rad(90), 0), Vector3.new(size.Z - 2 * b, b, b), color, material, extra))
	return parts
end

-- Дуга из цилиндров в плоскости XY локальной системы cf (угол 0 = +X, против часовой к +Y)
function Kit.arc(parent: Instance?, cf: CFrame, radius: number, a0: number, a1: number, segments: number, thickness: number, color: Color3, material: Enum.Material?, extra: Props?)
	local parts = {}
	local prev
	for i = 0, segments do
		local a = rad(a0 + (a1 - a0) * i / segments)
		local p = cf:PointToWorldSpace(Vector3.new(math.cos(a) * radius, math.sin(a) * radius, 0))
		if prev then
			local seg = Kit.rod(parent, prev, p, thickness, color, material, extra)
			if seg then
				table.insert(parts, seg)
			end
		end
		prev = p
	end
	return parts
end

-- Кольцо (полная дуга)
function Kit.ring(parent: Instance?, cf: CFrame, radius: number, segments: number, thickness: number, color: Color3, material: Enum.Material?, extra: Props?)
	return Kit.arc(parent, cf, radius, 0, 360, segments, thickness, color, material, extra)
end

-- Провисающая кривая (верёвка/кабель/цепь) между a и b
function Kit.sag(a: Vector3, b: Vector3, sag: number, n: number): { Vector3 }
	local pts = {}
	for i = 0, n do
		local t = i / n
		local p = a:Lerp(b, t) - Vector3.new(0, sag * 4 * t * (1 - t), 0)
		table.insert(pts, p)
	end
	return pts
end

function Kit.cable(parent: Instance?, points: { Vector3 }, diameter: number, color: Color3, material: Enum.Material?, extra: Props?)
	local parts = {}
	for i = 1, #points - 1 do
		local seg = Kit.rod(parent, points[i], points[i + 1], diameter, color, material, extra)
		if seg then
			table.insert(parts, seg)
		end
	end
	return parts
end

-- Цепь из чередующихся звеньев вдоль кривой
function Kit.chain(parent: Instance?, points: { Vector3 }, link: number, color: Color3, extra: Props?)
	local parts = {}
	local total = 0
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local len = (b - a).Magnitude
		local count = math.max(1, math.floor(len / link))
		for j = 0, count - 1 do
			local p0 = a:Lerp(b, j / count)
			local p1 = a:Lerp(b, (j + 1) / count)
			total += 1
			local cf = CFrame.lookAt((p0 + p1) / 2, p1) * CFrame.Angles(0, 0, total % 2 == 0 and rad(90) or 0)
			table.insert(parts, Kit.box(parent, cf, Vector3.new(link * 0.45, link * 0.12, link * 1.05), color, Mat.Metal, merge({ Decor = true }, extra)))
		end
	end
	return parts
end

-- Ряд заклёпок от a до b
function Kit.rivets(parent: Instance?, a: Vector3, b: Vector3, count: number, diameter: number, color: Color3)
	local parts = {}
	for i = 0, count - 1 do
		local t = count == 1 and 0.5 or i / (count - 1)
		table.insert(parts, Kit.ball(parent, CFrame.new(a:Lerp(b, t)), diameter, color, Mat.Metal, { Decor = true }))
	end
	return parts
end

-- Стена из досок. cf — центр стены, size — (ширина, высота, толщина); доски идут вдоль direction ("X" — горизонтально, "Y" — вертикально)
function Kit.planks(parent: Instance?, cf: CFrame, size: Vector3, options: Props?)
	local opts: Props = options or {}
	local rng: Random = opts.Rng or Random.new(1)
	local dir = opts.Direction or "X"
	local width = opts.PlankWidth or 0.9
	local gap = opts.Gap or 0.08
	local color = opts.Color or Kit.Palette.Plank
	local material = opts.Material or Mat.WoodPlanks
	local missing = opts.Missing or 0
	local tilt = opts.Tilt or 0
	local parts = {}
	local span = dir == "X" and size.Y or size.X
	local count = math.max(1, math.floor(span / (width + gap)))
	local step = span / count
	for i = 0, count - 1 do
		if rng:NextNumber() >= missing then
			local offset = -span / 2 + step * (i + 0.5)
			local plankSize, pos
			if dir == "X" then
				plankSize = Vector3.new(size.X * rng:NextNumber(0.97, 1), step - gap, size.Z)
				pos = CFrame.new(rng:NextNumber(-0.05, 0.05), offset, rng:NextNumber(-0.04, 0.04))
			else
				plankSize = Vector3.new(step - gap, size.Y * rng:NextNumber(0.94, 1), size.Z)
				pos = CFrame.new(offset, -size.Y * rng:NextNumber(0, 0.03), rng:NextNumber(-0.04, 0.04))
			end
			local rot = tilt > 0 and CFrame.Angles(0, 0, rad(rng:NextNumber(-tilt, tilt))) or CFrame.identity
			table.insert(parts, Kit.box(parent, cf * pos * rot, plankSize, Kit.jitter(color, 0.08, rng), material, opts.Extra))
		end
	end
	return parts
end

------------------------------------------------------------------------
-- Рисунки на поверхности (SurfaceGui), без загрузки текстур
------------------------------------------------------------------------

local function surface(part: BasePart, face: Enum.NormalId, ppu: number?): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = ppu or 40
	gui.LightInfluence = 1
	gui.Brightness = 1
	gui.MaxDistance = 120
	gui.Parent = part
	return gui
end

local function frame(parent: Instance, props: Props): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in props do
		(f :: any)[k] = v
	end
	f.Parent = parent
	return f
end

-- Диагональные полосы «опасность» (жёлто-чёрные)
function Kit.hazardStripes(part: BasePart, face: Enum.NormalId, color: Color3?, count: number?)
	local gui = surface(part, face, 30)
	local holder = frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color or Kit.Palette.Warning, ClipsDescendants = true })
	local n = count or 6
	for i = -n, n * 2 do
		frame(holder, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(i / n, 0.5),
			Size = UDim2.new(0.5 / n, 0, 3, 0),
			Rotation = 35,
			BackgroundColor3 = Kit.Palette.Black,
		})
	end
	return gui
end

-- Ржавые потёки сверху вниз
function Kit.rustStreaks(part: BasePart, face: Enum.NormalId, rng: Random, count: number?, color: Color3?)
	local gui = surface(part, face, 20)
	for _ = 1, count or 5 do
		local f = frame(gui, {
			Position = UDim2.fromScale(rng:NextNumber(0, 0.95), 0),
			Size = UDim2.fromScale(rng:NextNumber(0.02, 0.07), rng:NextNumber(0.3, 0.9)),
			BackgroundColor3 = color or Kit.Palette.DarkRust,
			BackgroundTransparency = rng:NextNumber(0.25, 0.5),
		})
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Transparency = NumberSequence.new(0, 1)
		g.Parent = f
	end
	return gui
end

-- Грязь/копоть: тёмный градиент снизу
function Kit.grime(part: BasePart, face: Enum.NormalId, strength: number?)
	local gui = surface(part, face, 10)
	local f = frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0 })
	local g = Instance.new("UIGradient")
	g.Rotation = -90
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1 - (strength or 0.6)),
		NumberSequenceKeypoint.new(0.6, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = f
	return gui
end

-- Круглая шкала со стрелкой
function Kit.gauge(part: BasePart, face: Enum.NormalId, value: number?)
	local gui = surface(part, face, 80)
	local dial = frame(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.86, 0.86),
		BackgroundColor3 = Color3.fromRGB(220, 214, 190),
	})
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = dial
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Kit.Palette.Iron
	stroke.Parent = dial
	frame(dial, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.05, 0.42),
		Rotation = -60 + 120 * (value or 0.3),
		BackgroundColor3 = Color3.fromRGB(170, 20, 20),
	})
	return gui
end

-- Надпись
function Kit.label(part: BasePart, face: Enum.NormalId, text: string, color: Color3?, font: Enum.Font?)
	local gui = surface(part, face, 40)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextScaled = true
	l.Font = font or Enum.Font.SpecialElite
	l.TextColor3 = color or Kit.Palette.Black
	l.Parent = gui
	return gui
end

-- Красный крест (аптечка)
function Kit.cross(part: BasePart, face: Enum.NormalId)
	local gui = surface(part, face, 60)
	frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(230, 228, 220) })
	frame(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.6, 0.2), BackgroundColor3 = Color3.fromRGB(190, 20, 20) })
	frame(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.2, 0.6), BackgroundColor3 = Color3.fromRGB(190, 20, 20) })
	return gui
end

------------------------------------------------------------------------
-- Свет и частицы (только встроенные текстуры)
------------------------------------------------------------------------

Kit.Tex = {
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Sparkles = "rbxasset://textures/particles/sparkles_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
	FireSparks = "rbxasset://textures/particles/fire_sparks_main.dds",
}

function Kit.pointLight(parent: Instance, color: Color3, range: number, brightness: number, shadows: boolean?): PointLight
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = shadows == true
	l.Parent = parent
	return l
end

function Kit.spotLight(parent: Instance, color: Color3, range: number, angle: number, brightness: number, face: Enum.NormalId, shadows: boolean?): SpotLight
	local l = Instance.new("SpotLight")
	l.Color = color
	l.Range = range
	l.Angle = angle
	l.Brightness = brightness
	l.Face = face
	l.Shadows = shadows == true
	l.Parent = parent
	return l
end

-- Готовые наборы частиц: "Fire", "Embers", "Smoke", "Sparks", "Fog", "Fireflies", "Dust"
function Kit.emitter(parent: Instance, preset: string, scale: number?): ParticleEmitter
	local s = scale or 1
	local e = Instance.new("ParticleEmitter")
	e.Name = preset
	if preset == "Fire" then
		e.Texture = Kit.Tex.Fire
		e.Color = ColorSequence.new(Color3.fromRGB(255, 170, 60), Color3.fromRGB(255, 70, 20))
		e.LightEmission = 1
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9 * s), NumberSequenceKeypoint.new(1, 0) })
		e.Transparency = NumberSequence.new(0.1, 1)
		e.Lifetime = NumberRange.new(0.5, 1)
		e.Rate = 35
		e.Speed = NumberRange.new(2 * s, 4 * s)
		e.SpreadAngle = Vector2.new(12, 12)
		e.RotSpeed = NumberRange.new(-60, 60)
		e.Rotation = NumberRange.new(0, 360)
	elseif preset == "Embers" then
		e.Texture = Kit.Tex.FireSparks
		e.Color = ColorSequence.new(Color3.fromRGB(255, 160, 60))
		e.LightEmission = 1
		e.Size = NumberSequence.new(0.12 * s, 0)
		e.Lifetime = NumberRange.new(1.5, 3)
		e.Rate = 6
		e.Speed = NumberRange.new(2, 5)
		e.SpreadAngle = Vector2.new(25, 25)
		e.Acceleration = Vector3.new(0, 1.5, 0)
	elseif preset == "Smoke" then
		e.Texture = Kit.Tex.Smoke
		e.Color = ColorSequence.new(Color3.fromRGB(40, 40, 42))
		e.Size = NumberSequence.new(1.2 * s, 4 * s)
		e.Transparency = NumberSequence.new(0.35, 1)
		e.Lifetime = NumberRange.new(2, 4)
		e.Rate = 4
		e.Speed = NumberRange.new(1.5, 3)
		e.SpreadAngle = Vector2.new(15, 15)
		e.RotSpeed = NumberRange.new(-20, 20)
	elseif preset == "Sparks" then
		e.Texture = Kit.Tex.Sparkles
		e.Color = ColorSequence.new(Color3.fromRGB(255, 190, 80))
		e.LightEmission = 1
		e.Size = NumberSequence.new(0.3 * s, 0)
		e.Speed = NumberRange.new(10, 18)
		e.SpreadAngle = Vector2.new(70, 70)
		e.Lifetime = NumberRange.new(0.3, 0.7)
		e.Acceleration = Vector3.new(0, -40, 0)
		e.Rate = 0
	elseif preset == "Fog" then
		e.Texture = Kit.Tex.Smoke
		e.Color = ColorSequence.new(Color3.fromRGB(150, 155, 170))
		e.Size = NumberSequence.new(8 * s, 14 * s)
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
	elseif preset == "Fireflies" then
		e.Texture = Kit.Tex.Sparkles
		e.Color = ColorSequence.new(Color3.fromRGB(220, 255, 140))
		e.LightEmission = 1
		e.Size = NumberSequence.new(0.15 * s)
		e.Lifetime = NumberRange.new(4, 7)
		e.Rate = 1.5
		e.Speed = NumberRange.new(0.5, 1.2)
		e.SpreadAngle = Vector2.new(180, 180)
	else -- Dust
		e.Texture = Kit.Tex.Smoke
		e.Color = ColorSequence.new(Color3.fromRGB(120, 110, 95))
		e.Size = NumberSequence.new(0.6 * s, 1.6 * s)
		e.Transparency = NumberSequence.new(0.6, 1)
		e.Lifetime = NumberRange.new(1, 2)
		e.Rate = 0
		e.Speed = NumberRange.new(1, 3)
		e.SpreadAngle = Vector2.new(60, 60)
	end
	e.Parent = parent
	return e
end

------------------------------------------------------------------------
-- CSG (объединение/вычитание). Если движок не может (или мы в тестах) — остаются обычные детали.
------------------------------------------------------------------------

function Kit.union(parts: { BasePart }, name: string?): BasePart?
	if #parts < 2 then
		return parts[1]
	end
	local first = parts[1]
	local rest = table.move(parts, 2, #parts, 1, {})
	local ok, result = pcall(function()
		return (first :: any):UnionAsync(rest)
	end)
	if not ok or not result then
		return nil
	end
	local u = result :: BasePart
	u.Name = name or first.Name
	u.Anchored = true
	u.CanCollide = first.CanCollide
	u.CanQuery = first.CanQuery
	u.CanTouch = first.CanTouch
	u.CastShadow = first.CastShadow
	pcall(function()
		(u :: any).UsePartColor = true
	end)
	u.Color = first.Color
	u.Material = first.Material
	u.Parent = first.Parent
	for _, p in parts do
		p:Destroy()
	end
	return u
end

-- Вычесть cutters из base. При неудаче резаки просто удаляются, остаётся base.
function Kit.subtract(base: BasePart, cutters: { BasePart }): BasePart
	local ok, result = pcall(function()
		return (base :: any):SubtractAsync(cutters)
	end)
	for _, c in cutters do
		c:Destroy()
	end
	if not ok or not result then
		return base
	end
	local u = result :: BasePart
	u.Name = base.Name
	u.Anchored = true
	u.CanCollide = base.CanCollide
	u.CastShadow = base.CastShadow
	pcall(function()
		(u :: any).UsePartColor = true
	end)
	u.Color = base.Color
	u.Material = base.Material
	u.Parent = base.Parent
	base:Destroy()
	return u
end

------------------------------------------------------------------------
-- Модели
------------------------------------------------------------------------

function Kit.model(name: string, parent: Instance?): Model
	local m = Instance.new("Model")
	m.Name = name
	if parent then
		m.Parent = parent
	end
	return m
end

-- Назначить PrimaryPart и сделать опору модели равной origin (по умолчанию — начало координат).
-- Вызывать сразу после создания PrimaryPart и ДО Kit.movable.
function Kit.setOrigin(model: Model, primary: BasePart, origin: CFrame?)
	model.PrimaryPart = primary
	primary.PivotOffset = primary.CFrame:ToObjectSpace(origin or CFrame.identity)
end

function Kit.count(root: Instance): number
	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

-- Пометить подвижную деталь: группа FX и два состояния (мировые CFrame на момент постройки).
-- Хранятся относительно опоры модели (model:GetPivot()), поэтому PrimaryPart модели должен быть
-- уже назначен и сам НЕ должен быть подвижным. PropFX.setGroup(model, group, alpha) двигает детали
-- группы между CF0 (alpha = 0) и CF1 (alpha = 1).
function Kit.movable(model: Model, part: BasePart, group: string, cf0: CFrame, cf1: CFrame)
	local pivot = model:GetPivot()
	part:SetAttribute("FX", group)
	part:SetAttribute("CF0", pivot:ToObjectSpace(cf0))
	part:SetAttribute("CF1", pivot:ToObjectSpace(cf1))
	part.CFrame = cf0
end

-- Повернуть CFrame вокруг шарнира (для подготовки CF1 у дверей/крышек)
function Kit.aroundHinge(cf: CFrame, hinge: CFrame, rotation: CFrame): CFrame
	return hinge * rotation * hinge:Inverse() * cf
end

return Kit
