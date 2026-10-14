-- Хижина маньяка (центр карты): брусчатый каркас, обшивка досками с щелями и сорванными досками,
-- односкатная крыша из ржавого профнастила на стропилах и обрешётке, две двери, два окна, паллета.
-- Сталкиваются: корпус стен (как раньше: 4 стены высотой 9 с проёмами) и листы крыши (камера не пролетает внутрь).
local Kit = require(script.Parent.Parent.Kit)
local Common = require(script.Parent.Common)
local W = require(script.Parent.BuildingWalls)

local P = Kit.Palette
local Mat = Kit.Mat
local A = Kit.A
local V = Vector3.new
local C = CFrame.new
local DECOR = W.DECOR

local H = 9 -- высота стен
local PLATE = H + 0.1 -- верх обвязки, на ней лежат стропила
local PITCH = 7 -- уклон крыши (градусы), высокая сторона — +X
local SLOPE = math.tan(math.rad(PITCH))

-- Стены и их наружные грани (±1 по локальной Z стены)
local function walls(cf: CFrame): { W.Wall }
	return {
		W.wall(cf * C(0, 0, -8), 17, H, 1, { { Center = 0, Width = 5.8, Sill = 0, Top = 7 } }),
		W.wall(cf * C(0, 0, 8), 17, H, 1, { { Center = 3, Width = 4, Sill = 3, Top = 7 } }),
		W.wall(cf * C(-8, 0, 0) * A(0, 90, 0), 15, H, 1, { { Center = 2, Width = 4, Sill = 3, Top = 7 } }),
		W.wall(cf * C(8, 0, 0) * A(0, 90, 0), 15, H, 1, { { Center = -2, Width = 5, Sill = 0, Top = 7 } }),
	}
end
local OUTSIDE = { -1, 1, -1, 1 }

-- Стены: корпус, наружная обшивка, внутренние стойки и ригель, нижняя и верхняя обвязка, рамы проёмов
local function buildWalls(map, cf: CFrame, rng: Random)
	local core = Kit.jitter(Color3.fromRGB(46, 36, 28), 0.03, rng)
	local board = Kit.jitter(P.OldWood, 0.04, rng)
	local timber = Kit.jitter(P.DarkWood, 0.05, rng)
	for i, w in walls(cf) do
		local out = OUTSIDE[i]
		W.core(map, w, core, Mat.WoodPlanks)
		W.boards(map.Decor, w, out, { Rng = rng, Color = board, Row = 0.95, Gap = 0.13, Missing = 0.05, Broken = 0.1, MaxLen = 7, Y0 = 0.4, Y1 = H - 0.5 })
		-- изнутри: стойки каркаса через ~2.4 и ригель на середине высоты (не у краёв проёмов)
		local zin = -out * (w.Thick / 2 + 0.15)
		local lim = w.Length / 2 - 1.2
		for _, r in W.solid(w, 0.4, H - 0.6) do
			local a, b = math.max(r[1] + 0.55, -lim), math.min(r[2] - 0.55, lim)
			if b > a then
				local n = math.max(1, math.floor((b - a) / 2.4 + 0.5))
				for k = 0, n do
					local x = a + (b - a) * k / n
					Kit.box(map.Decor, w.CF * C(x, (H - 0.2) / 2, zin), V(0.35, H - 1, 0.3), Kit.jitter(timber, 0.05, rng), Mat.Wood, DECOR)
				end
			end
		end
		for _, r in W.band(w, 4.4, 4.75) do
			local a, b = math.max(r[1], -lim - 0.6), math.min(r[2], lim + 0.6)
			if b - a > 0.8 then
				Kit.box(map.Decor, w.CF * C((a + b) / 2, 4.575, zin - out * 0.02), V(b - a, 0.35, 0.26), timber, Mat.Wood, DECOR)
			end
		end
		-- нижняя обвязка (поверх обшивки) и верхняя обвязка на всю толщину
		for _, r in W.band(w, 0, 0.4) do
			Kit.box(map.Decor, w.CF * C((r[1] + r[2]) / 2, 0.2, 0), V(r[2] - r[1], 0.4, w.Thick + 0.45), Kit.dark(timber, 0.1), Mat.Wood, DECOR)
		end
		local plateY = i <= 2 and PLATE - 0.3 or PLATE - 0.32
		Kit.box(map.Decor, w.CF * C(0, plateY, 0), V(w.Length, 0.6, w.Thick + 0.5), timber, Mat.Wood, DECOR)
		for _, o in w.Openings do
			W.frame(map.Decor, w, o, Kit.jitter(timber, 0.04, rng), Mat.Wood, 0.22)
			if o.Sill > 0 then
				W.shards(map.Decor, w, o, rng, 2)
			else
				-- порог
				Kit.box(map.Decor, w.CF * C(o.Center, 0.12, 0), V(o.Width, 0.24, w.Thick + 0.3), Kit.dark(timber, 0.2), Mat.Wood, DECOR)
			end
		end
	end
	-- угловые столбы
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Kit.box(map.Decor, cf * C(sx * 8, PLATE / 2, sz * 8) * A(0, rng:NextNumber(-2, 2), 0), V(1.3, PLATE, 1.3), Kit.jitter(timber, 0.05, rng), Mat.Wood, DECOR)
		end
	end
	-- фронтоны под скатом (спереди и сзади — треугольники, справа — полоса)
	local rise = 17 * SLOPE
	for _, sz in { -1, 1 } do
		Kit.wedge(map.Walls, cf * C(0, PLATE + rise / 2, sz * 8) * A(0, 90, 0), V(1, rise, 17), Kit.dark(board, 0.15), Mat.WoodPlanks)
	end
	local riseR = 16.5 * SLOPE
	Kit.box(map.Walls, cf * C(8, PLATE + riseR / 2, 0), V(1, riseR, 15), Kit.dark(board, 0.15), Mat.WoodPlanks)
end

-- Крыша: стропила вдоль ската, обрешётка поперёк, два ряда профлистов с волнами; один лист сорван,
-- один задран ветром. Возвращает функцию «точка на крыше» для ворона.
local function buildRoof(map, cf: CFrame, rng: Random): (number, number) -> Vector3
	local ro = cf * C(-8.5, PLATE, 0) * A(0, 0, PITCH)
	local cosP = math.cos(math.rad(PITCH))
	local s0, s1 = -1.4 / cosP, 18.4 / cosP -- свесы по 1.4 за стены
	local timber = Kit.jitter(P.DarkWood, 0.04, rng)
	for _, z in { -8, -4, 0, 4, 8 } do
		Kit.box(map.Decor, ro * C((s0 + s1) / 2, 0.25, z), V(s1 - s0, 0.5, 0.35), Kit.jitter(timber, 0.05, rng), Mat.Wood, DECOR)
	end
	for _, s in { 0.4, 6, 11.6, 17.2 } do
		Kit.box(map.Decor, ro * C(s, 0.65, 0), V(0.4, 0.3, 19.6), Kit.dark(timber, 0.08), Mat.Wood, DECOR)
	end
	local cols, sheetW = 6, 3.5
	local step = (19.4 - sheetW) / (cols - 1)
	local mid = (s0 + s1) / 2
	local missing = rng:NextInteger(1, cols - 2)
	local lifted = rng:NextNumber() < 0.5 and 0 or cols - 1
	local tones = { Kit.dark(P.Rust, 0.15), P.DarkRust, Kit.dark(P.Steel, 0.45), Color3.fromRGB(88, 66, 50) }
	for row = 0, 1 do
		local a, b = row == 0 and s0 or mid - 0.5, row == 0 and mid + 0.5 or s1
		local len = b - a
		for col = 0, cols - 1 do
			if not (row == 0 and col == missing) then
				local z = -9.7 + sheetW / 2 + step * col + rng:NextNumber(-0.08, 0.08)
				local n = 0.84 + (col % 2) * 0.07 + row * 0.15
				local color = Kit.jitter(tones[rng:NextInteger(1, #tones)], 0.05, rng)
				local base = ro * C((a + b) / 2, n, z)
				if row == 0 and col == lifted then
					base = ro * C(b, n, z) * A(0, 0, -6) * C(-len / 2, 0, 0)
				end
				local sheet = Kit.box(map.Walls, base, V(len, 0.08, sheetW), color, Mat.CorrodedMetal)
				sheet.Name = "Roof"
				if rng:NextNumber() < 0.35 then
					Kit.rustStreaks(sheet, Enum.NormalId.Top, rng, 4)
				end
				for k = 0, 3 do
					Kit.cyl(map.Decor, base * C(0, 0.04, -1.3 + k * 0.866), len, 0.14, Kit.jitter(color, 0.03, rng), Mat.CorrodedMetal, DECOR)
				end
			end
		end
	end
	-- старая покрышка и пара кирпичей прижимают листы
	local top = 0.84 + 0.07 + 0.15 + 0.04
	Kit.cyl(map.Decor, ro * C(12, top + 0.25, 3.4) * A(0, 0, 90), 0.5, 2.1, P.Rubber, Mat.Rubber, DECOR)
	for _, at in { { 10.5, -4.4 }, { 15.5, 6.1 } } do
		Kit.box(map.Decor, ro * C(at[1], top + 0.2, at[2]) * A(0, rng:NextNumber(0, 90), 0), V(0.9, 0.4, 0.45), Kit.jitter(P.Brick, 0.06, rng), Mat.Brick, DECOR)
	end
	return function(x: number, z: number): Vector3
		return (ro * C((x + 8.5) / cosP, top + 0.2, z)).Position
	end
end

-- Пол из досок (несколько выпало), пятна крови
local function buildFloor(map, cf: CFrame, rng: Random)
	local base = Kit.jitter(P.OldWood, 0.04, rng)
	for i = 0, 14 do
		if rng:NextNumber() > 0.08 then
			local x = -7.0 + i
			Kit.box(map.Decor, cf * C(x, 0.1, rng:NextNumber(-0.05, 0.05)), V(0.94, 0.2, 14.9), Kit.jitter(Kit.dark(base, 0.15), 0.07, rng), Mat.WoodPlanks, DECOR)
		end
	end
	for _ = 1, 2 do
		Kit.box(map.Decor, cf * C(rng:NextNumber(-3, 3), 0.21, rng:NextNumber(-3, 3)) * A(0, rng:NextNumber(0, 180), 0), V(rng:NextNumber(1, 2.2), 0.02, rng:NextNumber(0.6, 1.2)), P.DryBlood, Mat.SmoothPlastic, DECOR)
	end
end

-- Внутренняя обстановка у стен (декор): верстак, ящики, цепь с крюком, лампочка на шнуре
local function buildInterior(map, cf: CFrame, rng: Random, roofY: (number) -> number)
	local wood = Kit.jitter(P.Wood, 0.05, rng)
	-- верстак в переднем правом углу
	local bench = cf * C(5.8, 0, -6.75)
	Kit.box(map.Decor, bench * C(0, 3.0, 0), V(3.2, 0.18, 1.2), wood, Mat.Wood, DECOR)
	Kit.box(map.Decor, bench * C(0, 0.9, 0), V(2.9, 0.1, 1.0), Kit.dark(wood, 0.15), Mat.Wood, DECOR)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Kit.box(map.Decor, bench * C(sx * 1.45, 1.46, sz * 0.45), V(0.2, 2.9, 0.2), Kit.dark(wood, 0.2), Mat.Wood, DECOR)
		end
	end
	Kit.box(map.Decor, bench * C(-0.6, 3.37, 0.1) * A(0, 8, 0), V(1.1, 0.55, 0.55), Kit.jitter(Color3.fromRGB(110, 40, 30), 0.05, rng), Mat.Metal, DECOR)
	Kit.cyl(map.Decor, bench * C(0.8, 3.12, 0.15) * A(0, 0, 90), 0.05, 1.0, P.Steel, Mat.Metal, DECOR)
	-- ящики в переднем левом углу
	local crate = Kit.jitter(P.Plank, 0.06, rng)
	Kit.box(map.Decor, cf * C(-6.4, 0.95, -6.4) * A(0, rng:NextNumber(-8, 8), 0), V(1.7, 1.5, 1.7), crate, Mat.WoodPlanks, DECOR)
	Kit.box(map.Decor, cf * C(-6.3, 2.3, -6.5) * A(0, rng:NextNumber(10, 25), 0), V(1.3, 1.2, 1.3), Kit.dark(crate, 0.15), Mat.WoodPlanks, DECOR)
	-- цепь с мясным крюком над полом (выше головы)
	local hx, hz = -3.6, -4
	local hook = cf * C(hx, 7.1, hz)
	Kit.chain(map.Decor, { (cf * C(hx, roofY(hx), hz)).Position, hook.Position }, 0.36, P.Iron)
	Kit.box(map.Decor, hook * C(0, -0.35, 0), V(0.08, 0.6, 0.08), P.DarkSteel, Mat.Metal, DECOR)
	Kit.wedge(map.Decor, hook * C(0, -0.72, -0.12) * A(180, 0, 0), V(0.07, 0.25, 0.3), P.DarkSteel, Mat.Metal, DECOR)
	-- лампочка на шнуре в центре
	local bulbY = 8
	Kit.rod(map.Decor, (cf * C(0, roofY(0), 0)).Position, (cf * C(0, bulbY + 0.3, 0)).Position, 0.06, P.Black, Mat.Rubber, DECOR)
	Kit.vcyl(map.Decor, cf * C(0, bulbY + 0.22, 0), 0.25, 0.22, P.DarkSteel, Mat.Metal, DECOR)
	local bulb = Kit.ball(map.Decor, cf * C(0, bulbY, 0), 0.45, Color3.fromRGB(255, 196, 120), Mat.Neon, DECOR)
	bulb.Name = "Bulb"
	Kit.pointLight(bulb, Color3.fromRGB(255, 160, 90), 16, 1.1)
	-- снаружи: доски у задней стены и поленница у левой
	for k = 0, 1 do
		local x = -6.3 + k * 0.9
		Kit.bar(map.Decor, (cf * C(x + 0.3, 0.05, 9.9 - k * 0.2)).Position, (cf * C(x, 4.2, 8.75)).Position, 0.8, Kit.jitter(P.OldWood, 0.06, rng), Mat.WoodPlanks, DECOR, 0.12)
	end
	for k = 0, 2 do
		local y = k == 2 and 1.0 or 0.36
		local z = 3.5 + (k == 2 and 0 or (k - 0.5) * 0.74)
		Kit.cyl(map.Decor, cf * C(-9.0, y, z) * A(0, 90, 0), 1.9, 0.72, Kit.jitter(Color3.fromRGB(78, 62, 48), 0.06, rng), Mat.Wood, DECOR)
	end
end

local function shack(map, cf: CFrame, rng: Random)
	buildWalls(map, cf, rng)
	local roofAt = buildRoof(map, cf, rng)
	local function roofY(x: number): number
		-- низ стропил над точкой x
		return PLATE + (x + 8.5) * SLOPE
	end
	buildFloor(map, cf, rng)
	buildInterior(map, cf, rng, roofY)
	Common.pallet(map, rng, cf * CFrame.new(-1.8, 3, -7) * A(0, 0, 78), cf * CFrame.new(0, 1.5, -8))
	Common.locker(map, rng, cf * CFrame.new(-5.5, 0, 6.2))
	table.insert(map.ChestSpots, cf * CFrame.new(5.2, 0, 5.4))
	table.insert(map.TotemSpots, cf * CFrame.new(-11, 0, -9))
	table.insert(map.CrowSpots, CFrame.new(roofAt(6, -6)) * cf.Rotation)
end

return shack
