-- Деревья: ель (с уровнями детализации), сухое дерево, пень, упавшая ветка.
-- Всё строится от точки на земле cf (y = 0); сталкивается только нижняя часть ствола.
local Kit = require(script.Parent.Kit)

local Mat = Kit.Mat
local A = Kit.A
local V = Vector3.new
local C = CFrame.new

local Trees = {}

local DECOR = { Decor = true }

-- Хвоя: наружные ярусы, внутренние (тёмные) и макушка
local NEEDLES = {
	Color3.fromRGB(34, 52, 40),
	Color3.fromRGB(40, 56, 38),
	Color3.fromRGB(30, 48, 44),
}
local BARK = Color3.fromRGB(64, 50, 40)
local DEAD_BARK = Color3.fromRGB(84, 76, 68)

------------------------------------------------------------------------
-- Ель
------------------------------------------------------------------------

export type PineOpts = {
	Lod: string?, -- "full" (≤ 38 деталей), "mid" (≤ 21), "far" (≤ 10, силуэт)
	Scale: number?,
	Lowest: number?, -- высота нижнего яруса хвои
	-- Для силуэтов: направление к зрителю. Ярусы тогда из двух клиньев поперёк взгляда —
	-- к зрителю они стоят треугольником (7 деталей на дерево вместо 10).
	Facing: Vector3?,
}

type SkirtOpts = {
	Droop: number,
	Width: number,
	Missing: number,
	Roll: number, -- наклон «лапы» вокруг своей оси: видны две грани и рваный кончик
	Yaw: number?, -- направление первого клина (иначе случайное)
}

-- Ярус-«юбка» из клиньев вокруг ствола. center — основание яруса на оси ствола;
-- клин стоит высокой стороной у ствола, скат смотрит наружу и чуть вниз (ветви провисают).
local function skirt(parent: Instance, center: CFrame, radius: number, height: number, n: number, color: Color3, rng: Random, o: SkirtOpts)
	local yaw0 = if o.Yaw then o.Yaw + rng:NextNumber(-20, 20) else rng:NextNumber(0, 360)
	for k = 1, n do
		if k > 2 and rng:NextNumber() < o.Missing then
			continue
		end
		local r = radius * rng:NextNumber(0.85, 1.12)
		local h = height * rng:NextNumber(0.85, 1.1)
		local yaw = yaw0 + k * 360 / n + rng:NextNumber(-14, 14)
		local roll = A(0, 0, rng:NextNumber(-o.Roll, o.Roll))
		local cf = center * A(0, yaw, 0) * A(-o.Droop * rng:NextNumber(0.6, 1.4), 0, 0) * roll * C(0, h / 2, -r / 2)
		Kit.wedge(parent, cf, V(r * o.Width, h, r), Kit.jitter(color, 0.05, rng), Mat.LeafyGrass, DECOR)
	end
end

-- Корневые наплывы у основания ствола
local function roots(parent: Instance, base: CFrame, d: number, n: number, color: Color3, rng: Random)
	local yaw0 = rng:NextNumber(0, 360)
	for k = 1, n do
		local h = d * rng:NextNumber(0.9, 1.4)
		local depth = d * rng:NextNumber(0.9, 1.3)
		local cf = base * A(0, yaw0 + k * 360 / n + rng:NextNumber(-20, 20), 0) * C(0, h / 2 - 0.25, -(depth / 2 + d * 0.22))
		Kit.wedge(parent, cf, V(d * 0.55, h, depth), Kit.dark(color, 0.1), Mat.Wood, DECOR)
	end
end

-- Ель: конус из провисающих ярусов, между ними тёмные внутренние ярусы
function Trees.pine(parent: Instance, cf: CFrame, rng: Random, opts: PineOpts?): BasePart
	local o: PineOpts = opts or {}
	local lod = o.Lod or "full"
	local s = (o.Scale or 1) * rng:NextNumber(0.85, 1.18)
	local height = rng:NextNumber(25, 33) * s
	local lowest = o.Lowest or rng:NextNumber(6.5, 8.5)
	local yawB = rng:NextNumber(0, 360)
	local base = cf * A(0, yawB, 0) * A(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3)) * C(0, -0.3, 0)
	local d = rng:NextNumber(1.4, 1.8) * math.sqrt(s)
	local bark = Kit.jitter(BARK, 0.06, rng)
	local needles = NEEDLES[rng:NextInteger(1, #NEEDLES)]

	local crown = height - lowest
	local rMax = (crown * 0.22 + 1) * rng:NextNumber(0.9, 1.1)

	-- Ствол: нижняя часть твёрдая (за ней можно спрятаться), выше — тёмная сердцевина кроны
	local trunkH = lowest + 2
	local trunk = Kit.vcyl(parent, base * C(0, trunkH / 2, 0), trunkH, d, bark, Mat.Wood)
	trunk.Name = "Trunk"
	if lod ~= "far" then
		roots(parent, base, d, lod == "full" and 3 or 2, bark, rng)
	end

	-- Ярусы: широкие внизу, узкие и крутые наверху; верхние светлее (ловят лунный свет).
	-- Между ними — тёмные внутренние ярусы поменьше: глубина кроны вместо просвета насквозь.
	local tiers = lod == "far" and 3 or 4
	local per = lod == "far" and 3 or (lod == "mid" and 4 or 6)
	local gap = crown / (tiers + 0.3)
	-- Ширина «лапы» относительно длины: у подробной ели лапы уже, их больше, и они сильнее повёрнуты
	local width = lod == "full" and 0.7 or (lod == "mid" and 0.95 or 1.05)
	local skirtOpts: SkirtOpts = { Droop = rng:NextNumber(8, 16), Width = width, Missing = lod == "full" and 0.1 or 0, Roll = lod == "full" and 18 or 10 }
	if o.Facing and lod == "far" then
		-- Клин смотрит наружу вдоль -Z после поворота на yaw: ставим клинья поперёк взгляда
		local f = cf:VectorToObjectSpace(o.Facing)
		skirtOpts.Yaw = math.deg(math.atan2(-f.X, -f.Z)) + 90 - yawB
		per = 2
	end
	local innerOpts: SkirtOpts = { Droop = 6, Width = 1.1, Missing = 0, Roll = 10 }
	local inner = Kit.dark(needles, 0.5)
	for i = 0, tiers - 1 do
		local t = i / tiers
		local y = lowest + gap * i + rng:NextNumber(-0.25, 0.25)
		local r = rMax * (1 - t) ^ 0.9 + 0.9
		local tone = Kit.dark(needles, 0.2 * (1 - t)):Lerp(Color3.fromRGB(64, 76, 52), t * 0.3)
		local center = base * C(rng:NextNumber(-0.2, 0.2), y, rng:NextNumber(-0.2, 0.2))
		-- Чем выше ярус, тем уже «лапы»: верхушка остаётся острой, без плоских граней
		skirtOpts.Width = width - t * (lod == "full" and 0.3 or 0.45)
		skirt(parent, center, r, gap * (lod == "far" and 1.2 + t * 0.4 or 1.25 - t * 0.2), per, tone, rng, skirtOpts)
		if lod == "full" and i < tiers - 1 then
			skirt(parent, base * C(0, y + gap * 0.7, 0), r * 0.78, gap * 0.95, 3, inner, rng, innerOpts)
		elseif lod == "mid" and i == 0 then
			-- Тёмная масса под кроной (одна деталь вместо внутренних ярусов)
			Kit.vcyl(parent, base * C(0, y + gap, 0), gap * 2, r * 0.9, inner, Mat.LeafyGrass, DECOR)
		end
	end
	-- Верхушка: тонкий побег над последним ярусом (у силуэта её роль играет верхний ярус)
	if lod ~= "far" then
		local topY = lowest + gap * (tiers - 0.2)
		Kit.vcyl(parent, base * C(0, (topY + height) / 2, 0), height - topY, 0.35, needles, Mat.LeafyGrass, DECOR)
	end
	return trunk
end

------------------------------------------------------------------------
-- Сухое дерево
------------------------------------------------------------------------

-- Повернуть направление на случайный угол (градусы) вокруг случайной перпендикулярной оси
local function bend(dir: Vector3, maxDeg: number, rng: Random): Vector3
	local side = dir:Cross(Vector3.yAxis)
	if side.Magnitude < 1e-3 then
		side = Vector3.xAxis
	end
	local axis = (CFrame.fromAxisAngle(dir, rng:NextNumber(0, math.pi * 2)) * side.Unit).Unit
	return (CFrame.fromAxisAngle(axis, math.rad(rng:NextNumber(-maxDeg, maxDeg))) * dir).Unit
end

-- Сухое дерево: изогнутый ствол, рекурсивные ветви, корни, обломанная верхушка (≤ 40 деталей)
function Trees.dead(parent: Instance, cf: CFrame, rng: Random): BasePart
	local LIMIT = 40
	local count = 0
	local s = rng:NextNumber(0.85, 1.15)
	local height = rng:NextNumber(18, 24) * s
	local bark = Kit.jitter(DEAD_BARK, 0.05, rng)
	local base = cf * A(0, rng:NextNumber(0, 360), 0)

	-- Деталь-брусок с перекрытием на стыках (чтобы не было щелей на изгибах)
	local function limb(a: Vector3, b: Vector3, t: number, solid: boolean?): BasePart?
		count += 1
		local dir = (b - a).Unit
		local color = Kit.jitter(rng:NextNumber() < 0.3 and Kit.dark(bark, 0.25) or bark, 0.06, rng)
		local p = Kit.bar(parent, a - dir * t * 0.35, b + dir * t * 0.25, t, color, Mat.Wood, not solid and DECOR or nil, t * rng:NextNumber(0.85, 1))
		if p then
			p.CFrame *= A(0, 0, rng:NextNumber(0, 90))
		end
		return p
	end

	-- Ствол из трёх изогнутых отрезков
	local points = { base.Position + Vector3.new(0, -0.4, 0) }
	local thick = { 1.65 * s, 1.3 * s, 0.95 * s }
	local dir = bend(Vector3.yAxis, 10, rng)
	for i, frac in { 0.42, 0.33, 0.25 } do
		dir = bend((dir + Vector3.yAxis * 0.6).Unit, 9, rng)
		table.insert(points, points[i] + dir * height * frac)
	end
	local trunk = limb(points[1], points[2], thick[1], true) :: BasePart
	trunk.Name = "DeadTrunk"
	limb(points[2], points[3], thick[2])
	limb(points[3], points[4], thick[3])
	-- Обломанная верхушка: острый скол
	local top = points[4]
	Kit.wedge(parent, CFrame.lookAt(top, top + dir) * A(-90, 0, 0) * C(0, 0.6 * s, 0) * A(0, rng:NextNumber(0, 360), 0), V(thick[3] * 0.8, 1.4 * s, thick[3] * 0.8), Kit.dark(bark, 0.1), Mat.Wood, DECOR)
	count += 1

	-- Корни уходят в землю
	local yaw0 = rng:NextNumber(0, math.pi * 2)
	for k = 1, 4 do
		local a = yaw0 + k * math.pi / 2 + rng:NextNumber(-0.4, 0.4)
		local r = rng:NextNumber(2.1, 2.9) * s
		local from = base.Position + Vector3.new(math.cos(a) * 0.3, rng:NextNumber(1.4, 2), math.sin(a) * 0.3)
		limb(from, base.Position + Vector3.new(math.cos(a) * r, -0.5, math.sin(a) * r), rng:NextNumber(0.7, 0.9) * s)
	end
	-- Дупло
	local hollowY = height * rng:NextNumber(0.18, 0.3)
	local hollowPos = points[1]:Lerp(points[2], hollowY / (height * 0.42))
	local hollowCF = CFrame.lookAt(hollowPos, hollowPos + Vector3.new(math.cos(yaw0), 0, math.sin(yaw0))) * C(0, 0, -thick[1] * 0.42)
	Kit.box(parent, hollowCF, V(thick[1] * 0.4, thick[1] * 0.7, 0.2), Color3.fromRGB(16, 13, 12), Mat.SmoothPlastic, DECOR)
	count += 1

	-- Ветви (рекурсивно, пока хватает бюджета)
	local function grow(from: Vector3, d: Vector3, len: number, t: number, depth: number)
		if count >= LIMIT then
			return
		end
		local to = from + d * len
		limb(from, to, t)
		if depth >= 3 or rng:NextNumber() < 0.12 * depth then
			return -- обломанная ветка
		end
		for _ = 1, 2 do
			local nd = bend((d + Vector3.yAxis * 0.25).Unit, rng:NextNumber(22, 42), rng)
			grow(to, nd, len * rng:NextNumber(0.55, 0.7), t * 0.62, depth + 1)
		end
	end
	-- Иногда ствол раздваивается: второй лидер уходит в сторону от середины ствола
	if rng:NextNumber() < 0.35 then
		local side = bend((dir + Vector3.new(math.cos(yaw0 + 2), 0, math.sin(yaw0 + 2)) * 0.8).Unit, 8, rng)
		grow(points[3], side, height * rng:NextNumber(0.25, 0.32), thick[3] * 0.9, 1)
	end
	local branches = rng:NextInteger(4, 5)
	for k = 1, branches do
		local h = rng:NextNumber(0.4, 0.9)
		local seg = h < 0.42 and 1 or (h < 0.75 and 2 or 3)
		local p = points[seg]:Lerp(points[seg + 1], rng:NextNumber(0.3, 0.9))
		local a = yaw0 + k * math.pi * 2 / branches + rng:NextNumber(-0.5, 0.5)
		local out = Vector3.new(math.cos(a), math.tan(math.rad(rng:NextNumber(15, 50))), math.sin(a)).Unit
		grow(p, out, rng:NextNumber(4.5, 7) * s * (1.2 - h * 0.45), thick[seg] * 0.45, 1)
	end
	return trunk
end

------------------------------------------------------------------------
-- Мелочи: пень и упавшая ветка
------------------------------------------------------------------------

-- Пень со спилом и корнями (4 детали). extra — свойства ствола (по умолчанию декор).
-- Возвращает высоту спила над cf.
function Trees.stump(parent: Instance, cf: CFrame, rng: Random, extra: Kit.Props?): number
	local d = rng:NextNumber(1.3, 2)
	local h = rng:NextNumber(0.7, 1.3)
	local bark = Kit.jitter(BARK, 0.08, rng)
	local base = cf * A(rng:NextNumber(-4, 4), rng:NextNumber(0, 360), rng:NextNumber(-4, 4))
	Kit.vcyl(parent, base * C(0, h / 2 - 0.1, 0), h, d, bark, Mat.Wood, extra or DECOR)
	-- Спил: светлая древесина, чуть наклонён
	Kit.vcyl(parent, base * C(0, h - 0.07, 0) * A(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6)), 0.12, d * 0.86, Kit.jitter(Color3.fromRGB(120, 98, 72), 0.06, rng), Mat.Wood, DECOR)
	roots(parent, base, d * 0.8, 2, bark, rng)
	return h - 0.05
end

-- Упавшая ветка с отростками (2-3 детали)
function Trees.fallenBranch(parent: Instance, cf: CFrame, rng: Random)
	local len = rng:NextNumber(3, 6)
	local t = rng:NextNumber(0.25, 0.45)
	local color = Kit.jitter(DEAD_BARK, 0.08, rng)
	local a = (cf * C(-len / 2, t * 0.35, 0)).Position
	local b = (cf * C(len / 2, t * 0.35, rng:NextNumber(-0.6, 0.6))).Position
	Kit.bar(parent, a, b, t, color, Mat.Wood, DECOR)
	for _ = 1, rng:NextInteger(1, 2) do
		local p = a:Lerp(b, rng:NextNumber(0.3, 0.8))
		local side = (cf * A(0, rng:NextNumber(-60, 60) + (rng:NextNumber() < 0.5 and 0 or 180), 0)).LookVector
		Kit.bar(parent, p, p + side * rng:NextNumber(1, 2) + Vector3.new(0, 0.1, 0), t * 0.5, color, Mat.Wood, DECOR)
	end
end

return Trees
