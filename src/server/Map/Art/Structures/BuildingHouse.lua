-- Дом из двух комнат: оштукатуренные стены с обвалившейся штукатуркой (видна кладка), каменный цоколь
-- и угловые камни, окна для прыжка с рамами, осколками и ставнями, дверные коробки, двускатная крыша
-- из рядов кровли, свесы с водостоком, фронтоны из досок, печная труба, крыльцо с навесом на столбах,
-- обстановка (стол, опрокинутый стул, кровать, полка). Сталкиваются корпус стен (как раньше),
-- ряды кровли и фронтоны (выше 10: камера не залетает внутрь сверху).
local Kit = require(script.Parent.Parent.Kit)
local Common = require(script.Parent.Common)
local W = require(script.Parent.BuildingWalls)

local P = Kit.Palette
local Mat = Kit.Mat
local A = Kit.A
local V = Vector3.new
local C = CFrame.new
local DECOR = W.DECOR
local SOLID = W.SOLID

local H = 10
local PITCH = 28
local SLOPE = math.tan(math.rad(PITCH))
local RISE = 9.5 * SLOPE -- конёк над верхом стен
local OUTSIDE = { -1, 1, -1, 1 }

local function walls(cf: CFrame): ({ W.Wall }, W.Wall)
	return {
		W.wall(cf * C(0, 0, -9), 21, H, 1, { { Center = -5, Width = 5.8, Sill = 0, Top = 7.5 }, { Center = 5, Width = 4, Sill = 3, Top = 7 } }),
		W.wall(cf * C(0, 0, 9), 21, H, 1, { { Center = -5, Width = 4, Sill = 3, Top = 7 }, { Center = 5, Width = 4.5, Sill = 0, Top = 7.5 } }),
		W.wall(cf * C(-10, 0, 0) * A(0, 90, 0), 17, H, 1, { { Center = 2, Width = 4, Sill = 3, Top = 7 } }),
		W.wall(cf * C(10, 0, 0) * A(0, 90, 0), 17, H, 1),
	}, W.wall(cf * A(0, 90, 0), 17, H, 0.8, { { Center = 3, Width = 4.5, Sill = 0, Top = 7.5 } })
end

-- Удлинить крайние куски полосы (чтобы цоколь и карниз заходили за угол)
local function extend(r: W.Rect, length: number, e: number): (number, number)
	local a = r[1] <= -length / 2 + 1e-3 and r[1] - e or r[1]
	local b = r[2] >= length / 2 - 1e-3 and r[2] + e or r[2]
	return a, b
end

type Look = { Plaster: Color3, Stone: Color3, Trim: Color3, Brick: Color3, Roof: Color3, Gable: Color3 }

-- Наружные стены и перегородка
local function buildShell(map, cf: CFrame, rng: Random, look: Look)
	local outer, inner = walls(cf)
	for i, w in outer do
		local out = OUTSIDE[i]
		local zo = out * w.Thick / 2
		local face = out < 0 and Enum.NormalId.Front or Enum.NormalId.Back
		for _, p in W.core(map, w, look.Plaster, Mat.Plaster) do
			if p.Size.Y >= H - 0.01 then
				Kit.grime(p, face, 0.55)
			end
		end
		local ext = i <= 2 and 0.12 or 1
		-- каменный цоколь и деревянный карниз снаружи
		for _, r in W.band(w, 0, 1.2) do
			local a, b = extend(r, w.Length, ext)
			Kit.box(map.Decor, w.CF * C((a + b) / 2, 0.6, zo + out * 0.06), V(b - a, 1.2, 0.12), look.Stone, Mat.Concrete, DECOR)
		end
		Kit.box(map.Decor, w.CF * C(0, H - 0.3, zo + out * 0.09), V(w.Length + ext * 2 + 0.12, 0.6, 0.18), look.Trim, Mat.Wood, DECOR)
		-- изнутри: панели из досок по низу стены
		for _, r in W.band(w, 0, 3.2) do
			Kit.box(map.Decor, w.CF * C((r[1] + r[2]) / 2, (r[3] + r[4]) / 2, -zo - out * 0.04), V(r[2] - r[1], r[4] - r[3], 0.08), Kit.dark(look.Trim, 0.1), Mat.WoodPlanks, DECOR)
		end
		-- обвалившаяся штукатурка: неровные пятна кладки
		for _ = 1, 2 do
			local x, y = W.spot(w, rng, 2.4, 8, 1.5)
			if x then
				W.patch(map.Decor, rng, w, out, x, y, Vector2.new(rng:NextNumber(1.2, 2.6), rng:NextNumber(0.8, 1.5)), look.Brick, Mat.Brick)
			end
		end
		for _, o in w.Openings do
			W.frame(map.Decor, w, o, look.Trim, Mat.Wood, 0.2)
			if o.Sill > 0 then
				W.shards(map.Decor, w, o, rng, 2)
				-- ставня сбоку от окна и трещина от угла рамы
				local s = rng:NextNumber() < 0.5 and -1 or 1
				local sx = o.Center + s * (o.Width / 2 + 1.35)
				Kit.box(map.Decor, w.CF * C(sx, 5, zo + out * 0.11) * A(0, 0, rng:NextNumber(-7, 7)), V(1.85, 3.7, 0.12), Kit.jitter(Color3.fromRGB(62, 74, 70), 0.06, rng), Mat.Wood, DECOR)
				local cx = o.Center - s * (o.Width / 2 + 0.3)
				local p0 = w.CF * C(cx, o.Top + 0.3, zo + out * 0.01)
				local p1 = w.CF * C(cx - s * 0.5, o.Top + 1.1, zo + out * 0.01)
				local p2 = w.CF * C(cx - s * 0.7, H - 0.6, zo + out * 0.01)
				Kit.bar(map.Decor, p0.Position, p1.Position, 0.02, P.Black, Mat.SmoothPlastic, DECOR, 0.07)
				Kit.bar(map.Decor, p1.Position, p2.Position, 0.02, P.Black, Mat.SmoothPlastic, DECOR, 0.05)
			end
		end
	end
	-- угловые камни (поочерёдно длинные и короткие вдоль каждой грани)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			for k = 0, 5 do
				local lx, lz = k % 2 == 0 and 1.4 or 0.8, k % 2 == 0 and 0.8 or 1.4
				local pos = cf * C(sx * (10.6 - lx / 2), 1.85 + k * 1.37, sz * (9.6 - lz / 2))
				Kit.box(map.Decor, pos, V(lx, 1.25, lz), Kit.jitter(P.Concrete, 0.05, rng), Mat.Concrete, DECOR)
			end
		end
	end
	-- перегородка: доски, коробка двери, распахнутая дверь у стены
	local wood = Kit.jitter(P.OldWood, 0.04, rng)
	W.core(map, inner, wood, Mat.WoodPlanks)
	W.frame(map.Decor, inner, inner.Openings[1], look.Trim, Mat.Wood, 0.18)
	local door = cf * C(0.7, 3.65, 1.75)
	Kit.box(map.Decor, door, V(0.15, 7.1, 4.2), Kit.jitter(Color3.fromRGB(88, 70, 54), 0.05, rng), Mat.Wood, DECOR)
	for _, dy in { -1.7, 1.6 } do
		Kit.box(map.Decor, door * C(0.09, dy, 0), V(0.05, 2.4, 3.0), Kit.jitter(Color3.fromRGB(78, 62, 48), 0.05, rng), Mat.Wood, DECOR)
	end
	Kit.ball(map.Decor, door * C(0.14, -0.3, 1.7), 0.22, P.Steel, Mat.Metal, DECOR)
end

-- Крыша: ряды кровли (каждый следующий ложится на предыдущий), конёк, ветровые доски, фронтоны, труба
local function buildRoof(map, cf: CFrame, rng: Random, look: Look)
	local cosP = math.cos(math.rad(PITCH))
	local u0, u1 = -0.9 / cosP, 9.5 / cosP
	local courses, cw = 7, 2
	for _, s in { -1, 1 } do
		local sf = cf * C(0, H, s * 9.5) * (s < 0 and A(-PITCH, 0, 0) or A(0, 180, 0) * A(-PITCH, 0, 0))
		local first, last = u0 + cw / 2, u1 - cw / 2 + 0.15
		local moss = rng:NextInteger(1, courses - 2)
		for k = 0, courses - 1 do
			local u = first + (last - first) * k / (courses - 1)
			local course = sf * C(0, 0.16, u) * A(2.5, 0, 0)
			local p = Kit.box(map.Walls, course, V(21, 0.22, cw), Kit.jitter(look.Roof, 0.05, rng), Mat.RoofShingles)
			p.Name = "Roof"
			if k == moss then
				-- мох на одном ряду
				Kit.box(map.Decor, course * C(rng:NextNumber(-7, 7), 0.125, rng:NextNumber(-0.2, 0.2)), V(rng:NextNumber(1.5, 3), 0.04, 1.2), Kit.jitter(Color3.fromRGB(66, 74, 54), 0.05, rng), Mat.Grass, DECOR)
			end
		end
		for _, x in { -10.62, 10.62 } do
			Kit.box(map.Decor, sf * C(x, 0.12, (u0 + u1) / 2 + 0.05), V(0.22, 0.6, u1 - u0 + 0.1), look.Trim, Mat.Wood, SOLID)
		end
		Kit.box(map.Decor, cf * C(0, H - 0.9 * SLOPE - 0.1, s * 10.33), V(21.4, 0.55, 0.14), Kit.dark(look.Trim, 0.1), Mat.Wood, DECOR)
		-- фронтоны (половинки треугольника, высокая сторона к коньку) с вентиляционной решёткой
		for _, sx in { -1, 1 } do
			Kit.wedge(map.Walls, cf * C(sx * 10, H + RISE / 2, s * 4.75) * A(0, s < 0 and 0 or 180, 0), V(1, RISE, 9.5), look.Gable, Mat.WoodPlanks)
		end
	end
	for _, sx in { -1, 1 } do
		Kit.box(map.Decor, cf * C(sx * 10.54, H + RISE * 0.42, 0), V(0.08, 1.4, 1.8), look.Trim, Mat.Wood, DECOR)
		Kit.box(map.Decor, cf * C(sx * 10.55, H + RISE * 0.42, 0), V(0.1, 1.0, 1.4), P.Black, Mat.SmoothPlastic, DECOR)
	end
	Kit.box(map.Decor, cf * C(0, H + RISE + 0.36, 0), V(21.3, 0.32, 1.2), Kit.dark(look.Roof, 0.2), Mat.Slate, SOLID)
	Kit.box(map.Decor, cf * C(0, H + RISE + 0.6, 0), V(21.3, 0.2, 0.6), Kit.dark(look.Roof, 0.25), Mat.Slate, SOLID)
	-- водосток сзади: часть оторвалась и висит, труба уходит к стене
	local gutter = Kit.jitter(P.DarkSteel, 0.05, rng)
	Kit.cyl(map.Decor, cf * C(-3.25, 9.25, 10.5), 14.5, 0.4, gutter, Mat.Metal, DECOR)
	Kit.cyl(map.Decor, cf * C(4, 9.25, 10.5) * A(0, 0, -18) * C(3.1, 0, 0), 6.2, 0.4, gutter, Mat.Metal, DECOR)
	Kit.rod(map.Decor, (cf * C(-10.1, 9.2, 10.5)).Position, (cf * C(-10.1, 8.3, 9.78)).Position, 0.3, gutter, Mat.Metal, DECOR)
	Kit.rod(map.Decor, (cf * C(-10.1, 8.45, 9.78)).Position, (cf * C(-10.1, 0.2, 9.78)).Position, 0.3, gutter, Mat.Metal, DECOR)
	-- печная труба над задним скатом
	local chimney = cf * C(7.2, 0, 4.2)
	Kit.box(map.Decor, chimney * C(0, 14.95, 0), V(1.8, 5.3, 1.8), Kit.jitter(look.Brick, 0.04, rng), Mat.Brick, SOLID)
	Kit.box(map.Decor, chimney * C(0, 17.15, 0), V(1.84, 0.9, 1.84), Kit.dark(look.Brick, 0.6), Mat.Brick, DECOR)
	Kit.box(map.Decor, chimney * C(0, 17.75, 0), V(2.2, 0.3, 2.2), P.DarkConcrete, Mat.Concrete, SOLID)
	Kit.vcyl(map.Decor, chimney * C(0.2, 18.35, -0.1), 0.9, 0.6, Kit.jitter(Color3.fromRGB(120, 72, 52), 0.05, rng), Mat.Slate, DECOR)
end

-- Крыльцо перед входом с паллетой: настил, ступень, столбы, балка, навес
local function buildPorch(map, cf: CFrame, rng: Random, look: Look)
	local deck = Kit.jitter(P.OldWood, 0.05, rng)
	for k, z in { -9.72, -10.17 } do
		Kit.box(map.Decor, cf * C(-5, 0.125, z), V(9.2, 0.25, 0.42), Kit.jitter(deck, 0.06, rng), Mat.WoodPlanks, DECOR)
		if k == 1 then
			Kit.box(map.Decor, cf * C(-5, 0.06, -10.62), V(5, 0.12, 0.45), Kit.dark(deck, 0.15), Mat.WoodPlanks, DECOR)
		end
	end
	for _, x in { -9.55, -0.45 } do
		Kit.box(map.Decor, cf * C(x, 4.15, -10.15) * A(rng:NextNumber(-1.5, 1.5), 0, rng:NextNumber(-1.5, 1.5)), V(0.42, 8.3, 0.42), Kit.jitter(look.Trim, 0.05, rng), Mat.Wood, DECOR)
	end
	Kit.box(map.Decor, cf * C(-5, 8.5, -10.15), V(9.6, 0.4, 0.4), look.Trim, Mat.Wood, DECOR)
	Kit.bar(map.Decor, (cf * C(-5, 9.05, -9.45)).Position, (cf * C(-5, 8.55, -10.75)).Position, 10.2, Kit.jitter(look.Roof, 0.05, rng), Mat.RoofShingles, SOLID, 0.18)
	-- погасший фонарь у двери
	Kit.box(map.Decor, cf * C(-1.3, 6.4, -9.58), V(0.35, 0.5, 0.16), P.Iron, Mat.Metal, DECOR)
	Kit.ball(map.Decor, cf * C(-1.3, 6.1, -9.75), 0.35, Color3.fromRGB(90, 84, 70), Mat.Glass, DECOR)
end

-- Обстановка (декор у стен, проходы свободны)
local function buildInterior(map, cf: CFrame, rng: Random)
	-- пол из досок (часть выпала)
	local floor = Kit.jitter(Kit.dark(P.OldWood, 0.2), 0.04, rng)
	for i = 0, 18 do
		if rng:NextNumber() > 0.05 then
			Kit.box(map.Decor, cf * C(-9 + i, 0.1, 0), V(0.95, 0.2, 16.9), Kit.jitter(floor, 0.07, rng), Mat.WoodPlanks, DECOR)
		end
	end
	Kit.box(map.Decor, cf * C(-5.2, 0.215, 0.2) * A(0, rng:NextNumber(-6, 6), 0), V(4.2, 0.03, 3), Kit.jitter(Color3.fromRGB(92, 52, 44), 0.05, rng), Mat.Fabric, DECOR)
	-- левая комната: стол у перегородки и опрокинутый стул
	local wood = Kit.jitter(P.Wood, 0.05, rng)
	local tableCF = cf * C(-1.9, 0, 3.7)
	Kit.box(map.Decor, tableCF * C(0, 2.9, 0), V(2.4, 0.16, 3.2), wood, Mat.Wood, DECOR)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Kit.box(map.Decor, tableCF * C(sx * 1.0, 1.5, sz * 1.4), V(0.2, 2.8, 0.2), Kit.dark(wood, 0.15), Mat.Wood, DECOR)
		end
	end
	Kit.vcyl(map.Decor, tableCF * C(0.4, 3.23, -0.6), 0.5, 0.22, Color3.fromRGB(60, 86, 62), Mat.Glass, DECOR)
	Kit.vcyl(map.Decor, tableCF * C(-0.3, 3.0, 0.5), 0.04, 0.75, P.OldBone, Mat.SmoothPlastic, DECOR)
	local chair = cf * C(-4.1, 0.86, 2.4) * A(0, rng:NextNumber(20, 60), 0) * A(90, 0, 0)
	Kit.box(map.Decor, chair * C(0, 1.6, 0), V(1.3, 0.14, 1.3), wood, Mat.Wood, DECOR)
	Kit.box(map.Decor, chair * C(0, 2.45, 0.6), V(1.3, 1.6, 0.12), wood, Mat.Wood, DECOR)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Kit.box(map.Decor, chair * C(sx * 0.55, 0.8, sz * 0.55), V(0.14, 1.6, 0.14), Kit.dark(wood, 0.15), Mat.Wood, DECOR)
		end
	end
	-- правая комната: кровать у торцевой стены и полка у перегородки
	local bed = cf * C(7.85, 0, -0.2)
	local iron = Kit.jitter(P.DarkSteel, 0.05, rng)
	for _, sx in { -1, 1 } do
		Kit.box(map.Decor, bed * C(sx * 1.45, 1.0, 0), V(0.18, 0.45, 6.4), iron, Mat.Metal, DECOR)
	end
	Kit.box(map.Decor, bed * C(0, 1.6, 3.2), V(3.1, 3.2, 0.2), iron, Mat.Metal, DECOR)
	Kit.box(map.Decor, bed * C(0, 1.0, -3.3), V(3.1, 2.0, 0.2), iron, Mat.Metal, DECOR)
	Kit.box(map.Decor, bed * C(0, 1.4, 0) * A(0, 1.5, 0), V(2.8, 0.45, 6.1), Kit.jitter(Color3.fromRGB(128, 118, 96), 0.05, rng), Mat.Fabric, DECOR)
	Kit.box(map.Decor, bed * C(rng:NextNumber(-0.5, 0.5), 1.63, rng:NextNumber(-1.5, 1.5)), V(1.3, 0.02, 1.7), P.DryBlood, Mat.Fabric, DECOR)
	local shelf = cf * C(0.9, 0, 6.1)
	local board = Kit.jitter(P.Plank, 0.05, rng)
	for _, sz in { -1, 1 } do
		Kit.box(map.Decor, shelf * C(0, 2.75, sz * 1.44), V(0.9, 5.5, 0.12), Kit.dark(board, 0.1), Mat.Wood, DECOR)
	end
	for k = 0, 3 do
		Kit.box(map.Decor, shelf * C(0, 0.5 + k * 1.4, 0) * A(0, 0, k == 2 and 4 or 0), V(0.86, 0.1, 2.76), board, Mat.Wood, DECOR)
	end
	for k = 0, 2 do
		Kit.vcyl(map.Decor, shelf * C(rng:NextNumber(-0.15, 0.15), 2.18, -0.9 + k * 0.55), 0.5, 0.32, Kit.jitter(Color3.fromRGB(100, 110, 84), 0.1, rng), Mat.Glass, DECOR)
	end
	Kit.box(map.Decor, shelf * C(0, 3.75, 0.6) * A(12, 0, 0), V(0.6, 0.8, 0.22), Kit.jitter(Color3.fromRGB(80, 40, 34), 0.08, rng), Mat.Fabric, DECOR)
	Kit.box(map.Decor, shelf * C(0, 0.85, -0.4), V(0.7, 0.6, 1.0), Kit.jitter(P.Plank, 0.08, rng), Mat.Cardboard, DECOR)
	-- лампочки на шнурах под коньком
	for _, x in { -5, 5 } do
		Kit.rod(map.Decor, (cf * C(x, H + RISE - 0.1, 0)).Position, (cf * C(x, 8.9, 0)).Position, 0.06, P.Black, Mat.Rubber, DECOR)
		Kit.vcyl(map.Decor, cf * C(x, 8.82, 0), 0.25, 0.22, P.DarkSteel, Mat.Metal, DECOR)
		local bulb = Kit.ball(map.Decor, cf * C(x, 8.6, 0), 0.45, Color3.fromRGB(255, 206, 140), Mat.Neon, DECOR)
		bulb.Name = "Bulb"
		Kit.pointLight(bulb, Color3.fromRGB(255, 170, 100), 14, 0.9)
	end
end

local function house(map, cf: CFrame, rng: Random)
	local look: Look = {
		Plaster = Kit.jitter(Kit.dark(P.Plaster, 0.22), 0.03, rng),
		Stone = Kit.jitter(P.DarkConcrete, 0.04, rng),
		Trim = Kit.jitter(P.DarkWood, 0.05, rng),
		Brick = Kit.jitter(P.Brick, 0.04, rng),
		Roof = Kit.jitter(rng:NextNumber() < 0.5 and Color3.fromRGB(58, 52, 50) or Color3.fromRGB(78, 50, 42), 0.03, rng),
		Gable = Kit.jitter(Color3.fromRGB(74, 66, 58), 0.04, rng),
	}
	buildShell(map, cf, rng, look)
	buildRoof(map, cf, rng, look)
	buildPorch(map, cf, rng, look)
	buildInterior(map, cf, rng)
	Common.pallet(map, rng, cf * CFrame.new(-6.8, 3, -8) * A(0, 0, 78), cf * CFrame.new(-5, 1.5, -9))
	Common.locker(map, rng, cf * CFrame.new(-8, 0, 6.8))
	Common.locker(map, rng, cf * CFrame.new(7.6, 0, 6.8))
	table.insert(map.ChestSpots, cf * CFrame.new(-7.5, 0, -2) * A(0, 90, 0))
	table.insert(map.TotemSpots, cf * CFrame.new(7, 0, -6))
end

return house
