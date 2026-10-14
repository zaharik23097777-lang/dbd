-- Оформление ячеек предметами: свалка (остов машины или пачка смятых кузовов, шины, бочка, лом),
-- горящая бочка с сеном, тюки сена, надгробия, забор, фонарь.
-- Сталкиваются те же крупные формы, что и раньше (кузов и кабина, шины, бочки, тюки, камни, невидимая
-- стенка забора, столб фонаря); всё мелкое — декор.
local Kit = require(script.Parent.Parent.Kit)
local Nature = require(script.Parent.Parent.Nature)

local P = Kit.Palette
local Mat = Kit.Mat
local A = Kit.A
local V = Vector3.new
local C = CFrame.new
local DECOR = { Decor = true }

local Props = {}

------------------------------------------------------------------------
-- Бочки и сено (общие для свалки и костра)
------------------------------------------------------------------------

local BARREL_PAINT = { Color3.fromRGB(110, 46, 34), Color3.fromRGB(58, 72, 84), Color3.fromRGB(78, 86, 62), Color3.fromRGB(120, 96, 52) }

-- Бочка 200 л (корпус d 2, h 3 сталкивается): обручи, бортик, ржавый низ; горящая — закопчённая,
-- с прогоревшими дырами, углями и огнём
local function barrel(map, cf: CFrame, rng: Random, burning: boolean)
	local paint = Kit.jitter(BARREL_PAINT[rng:NextInteger(1, #BARREL_PAINT)], 0.05, rng)
	if burning then
		paint = Kit.dark(paint, 0.6)
	end
	local body = Kit.vcyl(map.Walls, cf * C(0, 1.5, 0), 3, 2, paint, Mat.CorrodedMetal)
	body.Name = "Barrel"
	for _, y in { 1.0, 2.0 } do
		Kit.vcyl(map.Decor, cf * C(0, y, 0), 0.14, 2.08, Kit.dark(paint, 0.2), Mat.CorrodedMetal, DECOR)
	end
	Kit.vcyl(map.Decor, cf * C(0, 2.94, 0), 0.16, 2.06, Kit.dark(paint, 0.3), Mat.Metal, DECOR)
	if burning then
		Kit.vcyl(map.Decor, cf * C(0, 3.03, 0), 0.06, 1.75, Color3.fromRGB(220, 90, 30), Mat.Neon, DECOR)
		for k = 1, 3 do
			Kit.box(map.Decor, cf * A(0, k * 120 + rng:NextNumber(-25, 25), 0) * C(0, rng:NextNumber(0.4, 0.75), -0.99), V(0.22, 0.2, 0.05), Color3.fromRGB(255, 120, 40), Mat.Neon, DECOR)
		end
		Nature.fire(map.Decor, cf * C(0, 3.2, 0), 1)
	else
		Kit.vcyl(map.Decor, cf * C(0, 0.3, 0), 0.6, 2.03, Kit.jitter(P.DarkRust, 0.05, rng), Mat.CorrodedMetal, DECOR)
		Kit.vcyl(map.Decor, cf * C(0.5, 3.04, 0.25), 0.08, 0.3, Kit.dark(paint, 0.4), Mat.Metal, DECOR)
	end
end

-- Тюк сена 3x2x4.5 (сталкивается) с двумя бечёвками вдоль
local function bale(map, cf: CFrame, rng: Random, color: Color3)
	local body = Kit.box(map.Walls, cf, V(3, 2, 4.5), color, Mat.Grass)
	body.Name = "Hay"
	for _, x in { -0.75, 0.75 } do
		Kit.box(map.Decor, cf * C(x, 0, 0), V(0.08, 2.04, 4.54), Kit.jitter(Color3.fromRGB(140, 112, 68), 0.05, rng), Mat.Fabric, DECOR)
	end
end

function Props.hay(map, cf: CFrame, rng: Random)
	local base = Kit.jitter(Kit.dark(P.Hay, 0.14), 0.04, rng)
	local old = Color3.fromRGB(118, 110, 88)
	for i = 1, rng:NextInteger(2, 4) do
		local color = Kit.jitter(base:Lerp(old, rng:NextNumber(0.1, 0.55)), 0.04, rng)
		bale(map, cf * C((i - 2) * 3.2, 1, rng:NextNumber(-0.5, 0.5)) * A(0, rng:NextNumber(-10, 10), 0), rng, color)
	end
	if rng:NextNumber() > 0.5 then
		bale(map, cf * C(-1.6, 3, 0) * A(0, 8, 0), rng, Kit.jitter(Kit.dark(base, 0.08), 0.04, rng))
	end
end

function Props.barrelFire(map, cf: CFrame, rng: Random)
	barrel(map, cf * C(-3, 0, 0), rng, true)
	barrel(map, cf * C(-0.6, 0, 1), rng, false)
	Props.hay(map, cf * C(4, 0, 0), rng)
	-- дрова у огня и колода с топором
	local log = Kit.jitter(Color3.fromRGB(78, 62, 48), 0.05, rng)
	local pile = cf * C(-3.6, 0, -1.9) * A(0, 8, 0)
	for k = 0, 2 do
		local y = k == 2 and 0.82 or 0.3
		local z = k == 2 and 0 or (k - 0.5) * 0.62
		Kit.cyl(map.Decor, pile * C(0, y, z), 2.2, 0.6, Kit.jitter(log, 0.06, rng), Mat.Wood, DECOR)
	end
	local stump = cf * C(-3.3, 0, 2.4)
	Kit.vcyl(map.Decor, stump * C(0, 0.6, 0), 1.2, 1.4, Kit.jitter(log, 0.05, rng), Mat.Wood, DECOR)
	-- топор: лезвие в колоде, топорище наискось вверх
	local axe = stump * C(0, 1.25, 0) * A(0, rng:NextNumber(0, 180), -25)
	Kit.box(map.Decor, axe, V(0.5, 0.35, 0.08), P.DarkSteel, Mat.Metal, DECOR)
	Kit.box(map.Decor, axe * C(0.2, 0.9, 0), V(0.12, 1.8, 0.12), Kit.jitter(P.Wood, 0.05, rng), Mat.Wood, DECOR)
end

------------------------------------------------------------------------
-- Свалка
------------------------------------------------------------------------

local CAR_PAINT = { Color3.fromRGB(96, 40, 34), Color3.fromRGB(52, 66, 78), Color3.fromRGB(150, 140, 112), Color3.fromRGB(64, 78, 58), Color3.fromRGB(88, 84, 80) }
local GLASS = Color3.fromRGB(34, 42, 46)

-- Колесо: шина и ржавый диск (ось — локальная X); без колеса машина стоит на шлакоблоке
local function wheel(map, cf: CFrame, rng: Random)
	if rng:NextNumber() < 0.75 then
		Kit.cyl(map.Decor, cf, 0.6, 1.8, P.Rubber, Mat.Rubber, DECOR)
		Kit.cyl(map.Decor, cf, 0.64, 1.0, Kit.jitter(P.DarkRust, 0.06, rng), Mat.Metal, DECOR)
	else
		Kit.box(map.Decor, cf * C(0, -0.5, 0), V(0.8, 0.8, 1.5), Kit.jitter(P.Concrete, 0.05, rng), Mat.Concrete, DECOR)
	end
end

-- Остов седана (кузов и кабина сталкиваются, как раньше): капот (иногда открыт), стойки, стёкла,
-- бамперы (один висит), фары, решётка, швы дверей, ржавчина, колёса
local function wreck(map, car: CFrame, rng: Random)
	local paint = Kit.jitter(CAR_PAINT[rng:NextInteger(1, #CAR_PAINT)], 0.05, rng)
	local dark = Kit.dark(paint, 0.25)
	local rust = Kit.jitter(P.DarkRust, 0.06, rng)
	local body = Kit.box(map.Walls, car * C(0, 1.6, 0), V(4.4, 1.8, 9), paint, Mat.CorrodedMetal)
	body.Name = "CarBody"
	local cabin = Kit.box(map.Walls, car * C(0, 3.3, 0.6), V(4, 1.6, 4), GLASS, Mat.Glass)
	cabin.Name = "CarCabin"
	Kit.box(map.Decor, car * C(0, 4.18, 0.6), V(4.1, 0.16, 4.1), Kit.dark(paint, 0.08), Mat.CorrodedMetal, DECOR)
	for _, z in { -1.35, 0.6, 2.55 } do
		for _, sx in { -1, 1 } do
			Kit.box(map.Decor, car * C(sx * 1.98, 3.3, z), V(0.16, 1.62, 0.28), dark, Mat.CorrodedMetal, DECOR)
		end
	end
	Kit.wedge(map.Decor, car * C(0, 3.25, -1.9), V(3.9, 1.5, 1.0), GLASS, Mat.Glass, DECOR)
	Kit.wedge(map.Decor, car * C(0, 3.25, 3.1) * A(0, 180, 0), V(3.9, 1.5, 1.0), GLASS, Mat.Glass, DECOR)
	if rng:NextNumber() < 0.35 then
		-- открытый капот, под ним двигатель
		Kit.box(map.Decor, car * C(0, 2.62, -1.85) * A(38, 0, 0) * C(0, 0, -1.3), V(4.2, 0.12, 2.6), paint, Mat.CorrodedMetal, DECOR)
		Kit.box(map.Decor, car * C(0, 2.75, -3.0), V(2.2, 0.5, 1.6), P.Iron, Mat.Metal, DECOR)
	else
		Kit.box(map.Decor, car * C(0, 2.56, -3.15), V(4.2, 0.12, 2.6), paint, Mat.CorrodedMetal, DECOR)
		Kit.box(map.Decor, car * C(rng:NextNumber(-1, 1), 2.63, -3.2), V(rng:NextNumber(1, 2), 0.02, rng:NextNumber(0.8, 1.6)), rust, Mat.CorrodedMetal, DECOR)
	end
	Kit.box(map.Decor, car * C(0, 2.56, 4.05), V(4.2, 0.12, 0.9), paint, Mat.CorrodedMetal, DECOR)
	-- бамперы: задний висит на одном креплении
	Kit.box(map.Decor, car * C(0, 1.05, -4.62), V(4.5, 0.4, 0.3), P.Steel, Mat.Metal, DECOR)
	Kit.box(map.Decor, car * C(-2.2, 1.05, 4.62) * A(0, 0, -14) * C(2.2, 0, 0), V(4.4, 0.4, 0.3), Kit.dark(P.Steel, 0.3), Mat.Metal, DECOR)
	-- фары (одна разбита), решётка, задние фонари
	for _, sx in { -1, 1 } do
		local lamp = sx < 0 and Color3.fromRGB(150, 146, 120) or P.Black
		Kit.cyl(map.Decor, car * C(sx * 1.5, 1.95, -4.52) * A(0, 90, 0), 0.08, 0.55, lamp, Mat.Glass, DECOR)
		Kit.box(map.Decor, car * C(sx * 1.6, 2.0, 4.52), V(0.6, 0.35, 0.06), Color3.fromRGB(80, 20, 18), Mat.Glass, DECOR)
	end
	Kit.box(map.Decor, car * C(0, 1.95, -4.52), V(2.0, 0.5, 0.06), P.Iron, Mat.DiamondPlate, DECOR)
	-- швы дверей и ржавчина на боках
	for _, sx in { -1, 1 } do
		for _, z in { -1.4, 0.6 } do
			Kit.box(map.Decor, car * C(sx * 2.21, 1.75, z), V(0.04, 1.3, 0.05), Kit.dark(paint, 0.5), Mat.SmoothPlastic, DECOR)
		end
		Kit.box(map.Decor, car * C(sx * 2.205, 1.2, rng:NextNumber(-3, 3)) * A(rng:NextNumber(-8, 8), 0, 0), V(0.02, 0.7, rng:NextNumber(1, 2.2)), rust, Mat.CorrodedMetal, DECOR)
	end
	for _, wpos in { { -2.2, -3 }, { 2.2, -3 }, { -2.2, 3 }, { 2.2, 3 } } do
		wheel(map, car * C(wpos[1], 0.9, wpos[2]), rng)
	end
end

-- Пачка смятых кузовов (все слои сталкиваются): полоса окон, ржавчина, торчащий диск
local function crushed(map, cf: CFrame, rng: Random)
	local y = 0
	for i = 1, 3 do
		local h = rng:NextNumber(0.95, 1.25)
		local paint = Kit.jitter(CAR_PAINT[rng:NextInteger(1, #CAR_PAINT)], 0.06, rng)
		local layer = cf * C(rng:NextNumber(-0.3, 0.3), y + h / 2, rng:NextNumber(-0.4, 0.4)) * A(rng:NextNumber(-2, 2), rng:NextNumber(-8, 8), rng:NextNumber(-2, 2))
		local slab = Kit.box(map.Walls, layer, V(4.3, h, 8.4), paint, Mat.CorrodedMetal)
		slab.Name = "CrushedCar"
		Kit.box(map.Decor, layer * C(0, h * 0.22, 0.4), V(4.36, h * 0.28, 5), GLASS, Mat.Glass, DECOR)
		Kit.box(map.Decor, layer * C(0, h / 2 + 0.01, rng:NextNumber(-2.5, 2.5)), V(rng:NextNumber(1.5, 3), 0.02, rng:NextNumber(1.5, 3)), Kit.jitter(P.DarkRust, 0.06, rng), Mat.CorrodedMetal, DECOR)
		local sx = rng:NextNumber() < 0.5 and -1 or 1
		Kit.cyl(map.Decor, layer * C(sx * 2.1, -h * 0.1, rng:NextNumber(-3, 3)) * A(0, 0, sx * 12), 0.4, 1.1, Kit.jitter(P.DarkRust, 0.05, rng), Mat.Metal, DECOR)
		y += h - 0.04
	end
end

function Props.junk(map, cf: CFrame, rng: Random)
	if rng:NextNumber() < 0.65 then
		wreck(map, cf * A(0, rng:NextNumber(-25, 25), rng:NextNumber(-6, 6)), rng)
	else
		crushed(map, cf * A(0, rng:NextNumber(-25, 25), 0), rng)
	end
	-- стопка шин (сталкиваются) и одна прислонённая
	local tires = cf * C(rng:NextNumber(-7, -5), 0, rng:NextNumber(-6, 6))
	for i = 1, rng:NextInteger(2, 4) do
		local t = tires * C(rng:NextNumber(-0.2, 0.2), 0.45 + (i - 1) * 0.9, 0) * A(0, 0, 90)
		local tire = Kit.cyl(map.Walls, t, 0.9, 2.6, P.Rubber, Mat.Rubber)
		tire.Name = "Tire"
		Kit.cyl(map.Decor, t, 0.94, 1.3, P.Black, Mat.SmoothPlastic, DECOR)
	end
	local lean = tires * C(1.85, 1.25, 0.3) * A(0, 0, 14)
	Kit.cyl(map.Decor, lean, 0.9, 2.6, Kit.jitter(P.Rubber, 0.04, rng), Mat.Rubber, DECOR)
	Kit.cyl(map.Decor, lean, 0.94, 1.3, P.Black, Mat.SmoothPlastic, DECOR)
	barrel(map, cf * C(rng:NextNumber(5, 7), 0, rng:NextNumber(-5, 5)), rng, false)
	-- лом: согнутый лист профнастила, блок двигателя, колпак
	local sheet = cf * C(rng:NextNumber(-3, 3), 0, rng:NextNumber() < 0.5 and -7.6 or 7.6) * A(0, rng:NextNumber(0, 180), 0)
	local tone = Kit.jitter(P.Rust, 0.06, rng)
	Kit.box(map.Decor, sheet * C(0, 0.05, 0), V(2.6, 0.06, 1.8), tone, Mat.CorrodedMetal, DECOR)
	Kit.box(map.Decor, sheet * C(0, 0.05, 0.9) * A(-35, 0, 0) * C(0, 0, 0.7), V(2.6, 0.06, 1.4), Kit.dark(tone, 0.1), Mat.CorrodedMetal, DECOR)
	local engine = cf * C(rng:NextNumber(-2, 2), 0, rng:NextNumber() < 0.5 and -8.4 or 8.4) * A(0, rng:NextNumber(0, 180), 0)
	Kit.box(map.Decor, engine * C(0, 0.45, 0), V(1.6, 0.9, 1.1), P.Iron, Mat.Metal, DECOR)
	Kit.box(map.Decor, engine * C(0, 1.0, 0), V(1.2, 0.2, 0.6), P.DarkRust, Mat.CorrodedMetal, DECOR)
	Kit.cyl(map.Decor, cf * C(rng:NextNumber(-4, 4), 0.03, rng:NextNumber(-8, 8)) * A(0, 0, 90), 0.06, 1.0, P.Steel, Mat.Metal, DECOR)
end

------------------------------------------------------------------------
-- Надгробия
------------------------------------------------------------------------

local STONE = { Color3.fromRGB(104, 104, 108), Color3.fromRGB(88, 90, 86), Color3.fromRGB(122, 118, 108), Color3.fromRGB(78, 82, 80) }

-- Одна могила: камень (сталкивается, как раньше) одного из видов и холмик земли перед ним
local function grave(map, g: CFrame, h: number, rng: Random)
	local stone = Kit.jitter(STONE[rng:NextInteger(1, #STONE)], 0.04, rng)
	local tilt = A(rng:NextNumber(-10, 10), 0, rng:NextNumber(-8, 8))
	local base = g * C(0, -0.3, 0) * tilt
	local kind = rng:NextInteger(1, 4)
	local main: BasePart
	if kind == 1 then
		-- закруглённая плита с надписью
		main = Kit.box(map.Walls, base * C(0, (h - 1) / 2, 0), V(2, h - 1, 0.6), stone, Mat.Slate)
		Kit.cyl(map.Decor, base * C(0, h - 1, 0) * A(0, 90, 0), 0.6, 2, stone, Mat.Slate, DECOR)
		Kit.label(main, Enum.NormalId.Front, "R.I.P.", Kit.dark(stone, 0.5), Enum.Font.Fantasy)
	elseif kind == 2 then
		-- крест на постаменте
		main = Kit.box(map.Walls, base * C(0, (h + 1) / 2, 0), V(0.45, h + 1, 0.45), stone, Mat.Slate)
		Kit.box(map.Decor, base * C(0, h * 0.72 + 0.3, 0), V(1.9, 0.42, 0.42), stone, Mat.Slate, DECOR)
		Kit.box(map.Decor, base * C(0, 0.45, 0), V(1.2, 0.5, 1.0), Kit.dark(stone, 0.12), Mat.Slate, DECOR)
	elseif kind == 3 then
		-- разбитая плита: обломок верха лежит у основания
		local stub = h * 0.5
		main = Kit.box(map.Walls, base * C(0, stub / 2, 0), V(2, stub, 0.6), stone, Mat.Slate)
		Kit.wedge(map.Decor, base * C(-0.5, stub + 0.2, 0) * A(0, 90, 0), V(0.6, 0.4, 1), stone, Mat.Slate, DECOR)
		Kit.box(map.Decor, g * C(rng:NextNumber(-0.5, 0.5), 0.3, -1.2) * A(80, rng:NextNumber(-30, 30), 0), V(2, h * 0.45, 0.6), Kit.dark(stone, 0.06), Mat.Slate, DECOR)
	else
		-- узкая плита с двускатным верхом
		main = Kit.box(map.Walls, base * C(0, h / 2, 0), V(1.6, h, 0.8), stone, Mat.Slate)
		for _, s in { -1, 1 } do
			Kit.wedge(map.Decor, base * C(s * 0.4, h + 0.25, 0) * A(0, -s * 90, 0), V(0.8, 0.5, 0.8), stone, Mat.Slate, DECOR)
		end
	end
	main.Name = "Tombstone"
	-- холмик: округлый — лежащий вдоль могилы цилиндр, утопленный в землю (иногда осевший),
	-- и пологий скат земли в ногах
	local mound = g * C(rng:NextNumber(-0.15, 0.15), 0, -2.0) * A(0, rng:NextNumber(-4, 4), 0)
	local earth = Kit.jitter(Color3.fromRGB(58, 46, 36), 0.06, rng)
	local mh = rng:NextNumber(0.22, 0.4)
	local d = 1.9
	Kit.cyl(map.Decor, mound * C(0, mh - d / 2, 0) * A(0, 90, 0), 3.0, d, earth, Mat.Ground, DECOR)
	local foot = 2 * math.sqrt(math.max((d / 2) ^ 2 - (d / 2 - mh) ^ 2, 0.01))
	Kit.wedge(map.Decor, mound * C(0, mh / 2 - 0.02, -1.5 - 0.35), V(foot * 0.9, mh, 0.7), Kit.dark(earth, 0.05), Mat.Ground, DECOR)
	if kind == 1 and rng:NextNumber() < 0.5 then
		-- погасшая лампадка у камня
		Kit.vcyl(map.Decor, g * C(rng:NextNumber(-0.6, 0.6), 0.25, -0.55), 0.5, 0.26, Kit.jitter(Color3.fromRGB(150, 54, 40), 0.08, rng), Mat.Glass, DECOR)
	end
end

function Props.tombstones(map, cf: CFrame, rng: Random)
	local n = rng:NextInteger(4, 7)
	for i = 1, n do
		local x = ((i - 1) % 4 - 1.5) * 4
		local z = math.floor((i - 1) / 4) * 5 - 2.5
		grave(map, cf * C(x, 0, z) * A(0, rng:NextNumber(-10, 10), 0), rng:NextNumber(2, 3.5), rng)
	end
	-- лопата, воткнутая у крайней могилы
	local spade = cf * C(((n - 1) % 4 - 1.5) * 4 + 1.4, 0, math.floor((n - 1) / 4) * 5 - 4.2) * A(rng:NextNumber(-15, 15), rng:NextNumber(0, 180), 12)
	Kit.box(map.Decor, spade * C(0, 1.6, 0), V(0.12, 3.2, 0.12), Kit.jitter(P.Wood, 0.05, rng), Mat.Wood, DECOR)
	Kit.box(map.Decor, spade * C(0, 0.1, 0), V(0.7, 0.9, 0.05), P.DarkSteel, Mat.Metal, DECOR)
end

------------------------------------------------------------------------
-- Забор: невидимая стенка (сталкивается, как раньше) и видимый забор поверх
------------------------------------------------------------------------

local function woodFence(parent: Instance, f: CFrame, rng: Random, length: number)
	local wood = Kit.jitter(Color3.fromRGB(96, 86, 72), 0.05, rng)
	local spans = 4
	local step = length / spans
	for i = 0, spans do
		local h = rng:NextNumber(4.4, 4.9)
		Kit.box(parent, f * C(-length / 2 + i * step, h / 2 - 0.2, 0) * A(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3)), V(0.5, h, 0.5), Kit.jitter(Kit.dark(wood, 0.2), 0.05, rng), Mat.Wood, DECOR)
	end
	for i = 0, spans - 1 do
		local x0 = -length / 2 + i * step
		for _, y in { 1.2, 3.5 } do
			if rng:NextNumber() < 0.15 then
				-- сорванная жердь висит одним концом
				Kit.box(parent, f * C(x0 + 0.25, y, -0.31) * A(0, 0, -rng:NextNumber(10, 22)) * C(step / 2 - 0.25, 0, 0), V(step - 0.5, 0.32, 0.12), Kit.jitter(wood, 0.06, rng), Mat.Wood, DECOR)
			else
				Kit.box(parent, f * C(x0 + step / 2, y + rng:NextNumber(-0.08, 0.08), -0.31), V(step, 0.32, 0.12), Kit.jitter(wood, 0.06, rng), Mat.Wood, DECOR)
			end
		end
		-- штакетник поверх жердей: часть выпала, часть покосилась
		for k = 0, 4 do
			if rng:NextNumber() > 0.12 then
				local ph = rng:NextNumber(3.7, 4.1)
				Kit.box(parent, f * C(x0 + 0.4 + k * (step - 0.8) / 4, ph / 2, -0.43) * A(0, 0, rng:NextNumber() < 0.12 and rng:NextNumber(-7, 7) or 0), V(0.42, ph, 0.08), Kit.jitter(wood, 0.08, rng), Mat.WoodPlanks, DECOR)
			end
		end
	end
end

local function wireFence(parent: Instance, f: CFrame, rng: Random, length: number)
	local spans = 4
	local step = length / spans
	local wire = Kit.jitter(P.DarkSteel, 0.05, rng)
	local tops = {}
	for i = 0, spans do
		local tilt = i == 2 and rng:NextNumber() < 0.5 and 14 or rng:NextNumber(-4, 4)
		local post = f * C(-length / 2 + i * step, 0, 0) * A(rng:NextNumber(-3, 3), 0, tilt)
		Kit.vcyl(parent, post * C(0, 2.2, 0), 4.6, 0.42, Kit.jitter(Color3.fromRGB(70, 60, 50), 0.06, rng), Mat.Wood, DECOR)
		table.insert(tops, post)
	end
	for i = 1, spans do
		for _, y in { 1.3, 2.5, 3.7 } do
			local a = (tops[i] * C(0, y, -0.22)).Position
			local b = (tops[i + 1] * C(0, y, -0.22)).Position
			Kit.cable(parent, Kit.sag(a, b, rng:NextNumber(0.12, 0.45), 2), 0.05, wire, Mat.Metal, DECOR)
		end
	end
	-- тряпка, зацепившаяся за проволоку
	local rag = tops[rng:NextInteger(1, spans)] * C(step * 0.4, 2.3, -0.24)
	Kit.box(parent, rag * A(0, 0, rng:NextNumber(-15, 15)), V(0.5, 0.7, 0.03), Color3.fromRGB(90, 70, 58), Mat.Fabric, DECOR)
end

function Props.fence(map, cf: CFrame, rng: Random)
	local f = cf * C(0, 0, -4)
	local length = 16
	local block = Kit.box(map.Walls, f * C(0, 2.25, 0), V(length, 4.5, 0.4), P.Black, Mat.SmoothPlastic, { Transparency = 1 })
	block.Name = "FenceBlock"
	if rng:NextNumber() < 0.5 then
		woodFence(map.Decor, f, rng, length)
	else
		wireFence(map.Decor, f, rng, length)
	end
	table.insert(map.CrowSpots, cf * CFrame.new(rng:NextNumber(-6, 6), 4.5, -4))
end

------------------------------------------------------------------------
-- Фонарь: деревянный столб (сталкивается), траверса, изогнутый кронштейн, абажур с решёткой,
-- тусклая лампа (PointLight без теней), провисший провод
------------------------------------------------------------------------

function Props.lamp(map, cf: CFrame, rng: Random)
	local base = cf * A(rng:NextNumber(-2, 2), rng:NextNumber(0, 360), rng:NextNumber(-2, 2))
	local pole = Kit.vcyl(map.Decor, base * C(0, 6.1, 0), 12.6, 0.62, Kit.jitter(Color3.fromRGB(62, 52, 44), 0.05, rng), Mat.Wood)
	pole.Name = "LampPost"
	local iron = Kit.jitter(P.Iron, 0.05, rng)
	Kit.box(map.Decor, base * C(0, 11.7, 0), V(2.6, 0.26, 0.3), Kit.jitter(P.DarkWood, 0.05, rng), Mat.Wood, DECOR)
	local root, elbow = base * C(0, 10.6, -0.3), base * C(0, 11.25, -1.6)
	local headCF = base * C(0, 11.0, -2.25)
	Kit.rod(map.Decor, root.Position, elbow.Position, 0.14, iron, Mat.Metal, DECOR)
	Kit.rod(map.Decor, elbow.Position, (headCF * C(0, 0.3, 0)).Position, 0.14, iron, Mat.Metal, DECOR)
	local shade = Kit.jitter(rng:NextNumber() < 0.5 and Color3.fromRGB(56, 70, 62) or Color3.fromRGB(70, 64, 56), 0.05, rng)
	Kit.vcyl(map.Decor, headCF * C(0, 0.12, 0), 0.32, 0.7, shade, Mat.Metal, DECOR)
	Kit.vcyl(map.Decor, headCF * C(0, -0.08, 0), 0.1, 1.5, shade, Mat.Metal, DECOR)
	local bulb = Kit.ball(map.Decor, headCF * C(0, -0.3, 0), 0.42, Color3.fromRGB(255, 196, 120), Mat.Neon, DECOR)
	bulb.Name = "LampHead"
	Kit.pointLight(bulb, Color3.fromRGB(255, 170, 90), 22, 0.85)
	-- решётка: три прута от края абажура к нижней точке
	for k = 0, 2 do
		Kit.rod(map.Decor, (headCF * A(0, k * 120, 0) * C(0.68, -0.1, 0)).Position, (headCF * C(0, -0.62, 0)).Position, 0.05, iron, Mat.Metal, DECOR)
	end
	Kit.cable(map.Decor, Kit.sag((base * C(0.9, 11.85, 0)).Position, (headCF * C(0, 0.3, 0)).Position, 0.35, 2), 0.05, P.Black, Mat.Rubber, DECOR)
end

return Props
