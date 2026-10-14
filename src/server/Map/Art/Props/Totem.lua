-- Тотемы (обычный и проклятый)
-- Модель строится в начале координат: земля y = 0, «перед» модели смотрит в -Z.
-- Требования — Art/Contract.lua; подвижные части — Kit.movable (см. Map/PropFX.lua).
local Kit = require(script.Parent.Parent.Kit)

local P = Kit.Palette
local Mat = Kit.Mat
local A = Kit.A
local V = Vector3.new
local C = CFrame.new

local M = {}
local T = {}
M.Templates = T

------------------------------------------------------------------------
-- Тотем: кривой кол в холмике земли, на нём череп; кости и рёбра примотаны верёвкой,
-- сзади рога или веер палок, вокруг оплывшие свечи. У проклятого свечи горят (HexFlame),
-- глазницы светятся (SkullEye). Череп (группа Skull) падает при очистке.
------------------------------------------------------------------------

local DECOR = { Decor = true }
local SHADOW = { CanCollide = false, CanQuery = false, CanTouch = false } -- крупные детали: без столкновений, но с тенью
local DIRT = Color3.fromRGB(62, 50, 40)
local STICK = Color3.fromRGB(70, 54, 40)
local ROPE = Color3.fromRGB(122, 104, 76)
local ANTLER = Color3.fromRGB(170, 154, 126)

-- Два бугра холмика: шары, утопленные в землю (центр, радиус). Над землёй (y = 0) торчит лишь
-- низкий купол, остальное скрыто ландшафтом карты (рендер превью рисует шары целиком).
local MOUND = {
	{ Pos = V(0, -1.15, 0), R = 1.5 },
	{ Pos = V(0.55, -0.9, 0.45), R = 1.15 },
}

-- Высота холмика в точке (x, z)
local function groundAt(x: number, z: number): number
	local h = 0
	for _, b in MOUND do
		local dx, dz = x - b.Pos.X, z - b.Pos.Z
		local r2 = b.R * b.R - dx * dx - dz * dz
		if r2 > 0 then
			h = math.max(h, b.Pos.Y + math.sqrt(r2))
		end
	end
	return h
end

type Style = {
	Lean: number, -- наклон кола (градусы вокруг Z)
	Crown: string, -- "Antlers" | "Fan" | "Broken"
	Crossbar: boolean,
	Ribs: number,
	Rags: number,
	Jaw: boolean, -- нижняя челюсть на месте (иначе валяется на земле)
	Chime: boolean, -- подвешенные на верёвках косточки
	Candles: number,
	Stones: number,
	RagColor: Color3,
}

local STYLES: { Style } = {
	{ Lean = 3, Crown = "Antlers", Crossbar = true, Ribs = 2, Rags = 2, Jaw = true, Chime = false, Candles = 3, Stones = 2, RagColor = Color3.fromRGB(96, 82, 62) },
	{ Lean = -4, Crown = "Fan", Crossbar = false, Ribs = 3, Rags = 1, Jaw = true, Chime = false, Candles = 3, Stones = 3, RagColor = Color3.fromRGB(84, 70, 60) },
	{ Lean = 11, Crown = "Broken", Crossbar = true, Ribs = 0, Rags = 3, Jaw = false, Chime = true, Candles = 2, Stones = 2, RagColor = Color3.fromRGB(74, 66, 58) },
}
local HEX_STYLE: Style = { Lean = 4, Crown = "Antlers", Crossbar = true, Ribs = 2, Rags = 2, Jaw = true, Chime = false, Candles = 5, Stones = 1, RagColor = Color3.fromRGB(78, 30, 26) }

-- Длинная кость: стержень и утолщения на концах (knobs = 1 или 2)
local function bone(m: Model, a: Vector3, b: Vector3, d: number, color: Color3, knobs: number)
	Kit.rod(m, a, b, d, color, Mat.SmoothPlastic, DECOR)
	Kit.ball(m, C(a), d * 1.9, Kit.dark(color, 0.04), Mat.SmoothPlastic, DECOR)
	if knobs > 1 then
		Kit.ball(m, C(b), d * 1.7, Kit.dark(color, 0.06), Mat.SmoothPlastic, DECOR)
	end
end

-- Изогнутая палка/ребро по трём точкам (2 детали)
local function curve(m: Model, a: Vector3, mid: Vector3, b: Vector3, d: number, color: Color3, material: Enum.Material)
	Kit.rod(m, a, mid, d, color, material, DECOR)
	Kit.rod(m, mid, b, d * 0.85, color, material, DECOR)
end

-- Обмотка верёвкой вокруг оси (axis — направление палки)
local function lashing(m: Model, at: Vector3, axis: Vector3, d: number, len: number)
	local cf = CFrame.lookAt(at, at + axis) * A(0, 90, 0)
	Kit.cyl(m, cf, len, d, ROPE, Mat.Fabric, DECOR)
end

-- Череп в локальной системе skull (начало — центр черепной коробки, лицо в -Z).
-- Возвращает детали группы Skull; глазницы помечены SkullEye.
local function skull(m: Model, cf: CFrame, hex: boolean, withJaw: boolean, rng: Random): { BasePart }
	local ivory = Kit.jitter(P.OldBone, 0.05, rng)
	local hollow = Color3.fromRGB(22, 16, 12)
	local parts = {}
	local function add(p: BasePart)
		table.insert(parts, p)
	end
	-- черепная коробка, надбровье, лицевая часть (скулы и верхняя челюсть)
	add(Kit.ball(m, C((cf * C(0, 0.1, 0.08)).Position), 0.8, ivory, Mat.SmoothPlastic, SHADOW))
	add(Kit.box(m, cf * C(0, 0.07, -0.29), V(0.64, 0.08, 0.12), Kit.dark(ivory, 0.06), Mat.SmoothPlastic, DECOR))
	add(Kit.box(m, cf * C(0, -0.16, -0.18), V(0.58, 0.4, 0.28), Kit.dark(ivory, 0.03), Mat.SmoothPlastic, DECOR))
	-- глазницы: тёмные диски чуть впереди лица (у проклятого светятся)
	for _, x in { -0.15, 0.15 } do
		local eye = Kit.cyl(m, cf * C(x, -0.07, -0.31) * A(0, 90, 0), 0.06, 0.24, hex and Color3.fromRGB(255, 72, 30) or hollow, hex and Mat.Neon or Mat.SmoothPlastic, DECOR)
		eye:SetAttribute("SkullEye", true)
		add(eye)
	end
	-- носовая впадина ромбом
	add(Kit.box(m, cf * C(0, -0.22, -0.33) * A(0, 0, 45), V(0.1, 0.1, 0.02), hollow, Mat.SmoothPlastic, DECOR))
	-- верхние зубы (чуть утоплены)
	add(Kit.box(m, cf * C(0, -0.4, -0.26), V(0.34, 0.08, 0.08), Color3.fromRGB(190, 172, 132), Mat.SmoothPlastic, DECOR))
	if withJaw then
		-- приоткрытая нижняя челюсть
		local jaw = Kit.aroundHinge(cf * C(0, -0.49, -0.15), cf * C(0, -0.42, 0.03), A(-12, 0, 0))
		add(Kit.box(m, jaw, V(0.44, 0.1, 0.34), Kit.dark(ivory, 0.08), Mat.SmoothPlastic, DECOR))
	end
	return parts
end

local function buildTotem(rng: Random, hex: boolean, style: Style): Model
	local m = Kit.model(hex and "HexTotem" or "Totem")
	m:SetAttribute("Kind", "Totem")

	-- Холмик земли и камни
	local root = Kit.ball(m, C(MOUND[1].Pos), MOUND[1].R * 2, Kit.jitter(DIRT, 0.04, rng), Mat.Ground, DECOR)
	root.Name = "Base"
	Kit.setOrigin(m, root)
	Kit.ball(m, C(MOUND[2].Pos), MOUND[2].R * 2, Kit.jitter(Kit.dark(DIRT, 0.12), 0.04, rng), Mat.Mud, DECOR)
	for i = 1, style.Stones do
		local a = math.rad(-150 + i * 95 + rng:NextNumber(-20, 20))
		local r = rng:NextNumber(0.9, 1.15)
		local x, z = math.cos(a) * r, math.sin(a) * r
		local stone = Kit.jitter(Color3.fromRGB(86, 84, 80), 0.06, rng)
		local g = groundAt(x, z)
		if i == 2 then
			-- круглый валун, наполовину в земле
			Kit.ball(m, C(x, g - 0.08, z), rng:NextNumber(0.55, 0.7), stone, Mat.Rock, DECOR)
		else
			-- острый осколок камня (клин)
			local size = V(rng:NextNumber(0.45, 0.6), rng:NextNumber(0.4, 0.55), rng:NextNumber(0.6, 0.8))
			Kit.wedge(m, C(x, g + size.Y / 2 - 0.1, z) * A(rng:NextNumber(-8, 8), math.deg(-a) + 90 + rng:NextNumber(-30, 30), 0), size, stone, Mat.Slate, DECOR)
		end
	end

	-- Кривой кол (нижняя часть сталкивается, чтобы сквозь тотем не ходили)
	local lean = CFrame.Angles(0, 0, math.rad(style.Lean))
	local function up(v: Vector3): Vector3
		return lean:PointToWorldSpace(v)
	end
	local stakeTop = up(V(0, 2.35, 0.03))
	local stakeMid = up(V(0.07, 1.25, 0.06))
	Kit.rod(m, V(0, 0.05, 0.04), stakeMid, 0.24, Kit.jitter(STICK, 0.05, rng), Mat.Wood)
	Kit.rod(m, stakeMid, stakeTop, 0.2, Kit.jitter(STICK, 0.05, rng), Mat.Wood, SHADOW)

	-- Подпорки шалашом
	for i = 1, 3 do
		local a = math.rad(i * 120 + rng:NextNumber(-25, 25) + 30)
		local foot = V(math.cos(a) * 0.85, 0, math.sin(a) * 0.85)
		foot += V(0, groundAt(foot.X, foot.Z) - 0.05, 0)
		local cross = up(V(0, 1.45 + i * 0.12, 0.04))
		local tip = cross + (cross - foot).Unit * rng:NextNumber(0.35, 0.6)
		Kit.rod(m, foot, tip, rng:NextNumber(0.09, 0.12), Kit.jitter(STICK, 0.08, rng), Mat.Wood, DECOR)
	end
	lashing(m, up(V(0.04, 1.62, 0.05)), up(V(0, 1, 0)) - up(V(0, 0, 0)), 0.32, 0.3)

	-- Перекладина с тряпками и рёбрами
	local barL, barR = up(V(-0.85, 1.92, 0.12)), up(V(0.82, 1.84, 0.12))
	if style.Crossbar then
		Kit.rod(m, barL, barR, 0.12, Kit.jitter(STICK, 0.06, rng), Mat.Wood, DECOR)
		lashing(m, up(V(0, 1.88, 0.08)), V(1, 0, 0), 0.3, 0.22)
	end
	-- без перекладины тряпки повязаны на кол
	local hangs = style.Crossbar and { barL:Lerp(barR, 0.06), barR:Lerp(barL, 0.1), barL:Lerp(barR, 0.3) }
		or { up(V(0.1, 2.05, -0.1)), up(V(-0.12, 1.75, -0.1)), up(V(0, 1.5, -0.12)) }
	for i = 1, style.Rags do
		local top = hangs[i] + V(0, -0.04, -0.02)
		local len = rng:NextNumber(0.7, 1.1)
		local rag = C(top + V(0, -len / 2, -0.04)) * A(rng:NextNumber(-8, 8), rng:NextNumber(-35, 35), rng:NextNumber(-8, 8))
		Kit.box(m, rag, V(rng:NextNumber(0.16, 0.26), len, 0.03), Kit.jitter(style.RagColor, 0.06, rng), Mat.Fabric, DECOR)
	end

	-- Скрещённые кости перед колом
	local boneColor = Kit.jitter(P.OldBone, 0.05, rng)
	local c = up(V(0.02, 1.15, -0.2))
	bone(m, c + V(-0.36, -0.42, 0.02), c + V(0.34, 0.44, 0.02), 0.13, boneColor, 2)
	bone(m, c + V(0.36, -0.4, -0.04), c + V(-0.3, 0.38, -0.04), 0.11, Kit.dark(boneColor, 0.05), 1)
	lashing(m, c + V(0, 0.01, -0.02), V(0, 0, 1), 0.24, 0.22)

	-- Рёбра: изогнутые дуги, свисающие с перекладины (или примотанные к колу веером)
	for i = 1, style.Ribs do
		local side = i % 2 == 1 and -1 or 1
		local a = style.Crossbar and barL:Lerp(barR, 0.5 + side * (0.22 + i * 0.05)) or up(V(side * 0.1, 1.3 + i * 0.18, 0.08))
		local mid = a + V(side * 0.28, -0.32, -0.16)
		local b = mid + V(-side * 0.08, -0.36, -0.1)
		curve(m, a, mid, b, 0.07, Kit.jitter(P.Bone, 0.06, rng), Mat.SmoothPlastic)
	end

	-- Подвешенные на верёвках косточки
	if style.Chime then
		for i, t in { 0.72, 0.9 } do
			local top = barL:Lerp(barR, t)
			local low = top + V(0, -0.35 - i * 0.12, 0)
			Kit.rod(m, top, low, 0.03, ROPE, Mat.Fabric, DECOR)
			Kit.rod(m, low, low + V(0.05, -0.3, 0.02), 0.07, Kit.jitter(P.Bone, 0.06, rng), Mat.SmoothPlastic, DECOR)
		end
	end

	-- Корона за черепом: рога, веер палок или обломанный рог
	local crownBase = stakeTop + V(0, -0.1, 0.12)
	if style.Crown == "Antlers" or style.Crown == "Broken" then
		for _, side in { -1, 1 } do
			-- ствол рога уходит в сторону и вверх, отросток смотрит вперёд
			local col = Kit.jitter(ANTLER, 0.05, rng)
			local p0 = crownBase + V(side * 0.1, 0.05, 0.02)
			if style.Crown == "Broken" and side == 1 then
				Kit.rod(m, p0, p0 + V(side * 0.32, 0.2, 0.06), 0.13, col, Mat.SmoothPlastic, DECOR) -- обломанный пенёк
				continue
			end
			local p1 = p0 + V(side * 0.55, 0.32, 0.1)
			local p2 = p1 + V(side * 0.15, 0.62, -0.08)
			Kit.rod(m, p0, p1, 0.13, col, Mat.SmoothPlastic, DECOR)
			Kit.rod(m, p1, p2, 0.09, col, Mat.SmoothPlastic, DECOR)
			local fork = p1:Lerp(p2, 0.3)
			Kit.rod(m, fork, fork + V(-side * 0.12, 0.42, -0.24), 0.07, col, Mat.SmoothPlastic, DECOR)
		end
	else
		for i = 1, 5 do
			local a = math.rad(-60 + (i - 1) * 30 + rng:NextNumber(-6, 6))
			local dir = V(math.sin(a), math.cos(a), 0.12)
			Kit.rod(m, crownBase, crownBase + dir * rng:NextNumber(1.0, 1.35), rng:NextNumber(0.05, 0.08), Kit.jitter(STICK, 0.1, rng), Mat.Wood, DECOR)
		end
	end
	lashing(m, crownBase + V(0, -0.02, -0.02), up(V(0, 1, 0)) - up(V(0, 0, 0)), 0.28, 0.24)

	-- Череп (группа Skull): на колу; при очистке падает и откатывается вперёд
	local skullCF = C(stakeTop + V(0, 0.24, -0.02)) * lean * A(rng:NextNumber(-6, 4), rng:NextNumber(-12, 12), rng:NextNumber(-6, 6))
	local fallen = C(0.75, 0.43, -1.25) * A(-15, rng:NextNumber(20, 60), 78)
	for _, p in skull(m, skullCF, hex, style.Jaw, rng) do
		local rel = skullCF:ToObjectSpace(p.CFrame)
		local cf0, cf1 = skullCF * rel, fallen * rel
		if (p :: Part).Shape == Enum.PartType.Ball then
			-- шару поворот не нужен: храним только положение
			cf0, cf1 = C(cf0.Position), C(cf1.Position)
		end
		Kit.movable(m, p, "Skull", cf0, cf1)
	end
	if not style.Jaw then
		-- челюсть давно отвалилась и лежит на холмике
		local x, z = -0.55, -0.7
		Kit.box(m, C(x, groundAt(x, z) + 0.04, z) * A(-8, 35, 4), V(0.48, 0.12, 0.42), Kit.dark(boneColor, 0.1), Mat.SmoothPlastic, DECOR)
	end

	-- Оплывшие свечи (у проклятого горят)
	local flames = 0
	for i = 1, style.Candles do
		local a = math.rad(200 + (i - 0.5) * (150 / style.Candles) + rng:NextNumber(-8, 8))
		local r = rng:NextNumber(0.75, 1.15)
		local x, z = math.cos(a) * r, math.sin(a) * r
		local g = groundAt(x, z)
		local h = rng:NextNumber(0.3, hex and 0.8 or 0.6)
		local d = rng:NextNumber(0.2, 0.3)
		local wax = Kit.jitter(P.Wax, 0.05, rng)
		Kit.vcyl(m, C(x, g + h / 2 - 0.02, z) * A(rng:NextNumber(-5, 5), 0, rng:NextNumber(-5, 5)), h, d, wax, Mat.SmoothPlastic, DECOR)
		if i <= 2 then
			Kit.vcyl(m, C(x, g + 0.01, z), 0.05, d * 2.1, Kit.dark(wax, 0.06), Mat.SmoothPlastic, DECOR)
		end
		if hex then
			local flame = Kit.box(m, C(x, g + h + 0.1, z) * A(0, 45, 0), V(0.09, 0.2, 0.09), P.Flame, Mat.Neon, DECOR)
			flame:SetAttribute("HexFlame", true)
			flames += 1
			if flames == 2 then
				Kit.pointLight(flame, Color3.fromRGB(255, 130, 60), 10, 1.8)
				Kit.emitter(flame, "Fire", 0.12).Rate = 10
			end
		end
	end

	-- Мелкая косточка на холмике
	if not hex then
		local x, z = 0.4, -0.75
		local g = groundAt(x, z)
		Kit.rod(m, V(x - 0.2, g + 0.03, z), V(x + 0.2, g + 0.06, z - 0.1), 0.07, Kit.jitter(P.Bone, 0.06, rng), Mat.SmoothPlastic, DECOR)
	end

	m:SetAttribute("Hex", hex)
	m:SetAttribute("Progress", 0)
	m:SetAttribute("Cleansed", false)
	return m
end

T.Totem = {
	Variants = 3,
	Build = function(rng: Random, variant: number)
		return buildTotem(rng, false, STYLES[variant] or STYLES[1])
	end,
}
T.HexTotem = {
	Variants = 1,
	Build = function(rng: Random)
		return buildTotem(rng, true, HEX_STYLE)
	end,
}

return M
