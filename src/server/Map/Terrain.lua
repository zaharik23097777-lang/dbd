-- Ландшафт (Roblox Terrain): трава, тропинки, грязь, камни, холмы за стенами.
-- Поверхность земли на карте — y = 0, внутри стен она ровная (рельеф — только снаружи).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Terrain = {}

local M = Enum.Material

local function terrain(): Terrain?
	return workspace:FindFirstChildOfClass("Terrain")
end

-- Вызов метода Terrain с защитой (в тестах/эмуляторе части методов может не быть)
local function call(method: string, ...)
	local t = terrain()
	if not t then
		return
	end
	local args = table.pack(...)
	pcall(function()
		(t :: any)[method](t, table.unpack(args, 1, args.n))
	end)
end
Terrain.call = call

-- Отложенные заливки. Природа (бугры под камнями, земля под кукурузой) добавляет их во время
-- раскладки ячеек, а buildMap применяет после основы — иначе clearMap стёр бы их.
local pending: { any } = {}

function Terrain.defer(method: string, ...)
	table.insert(pending, table.pack(method, ...))
end

local function flush()
	for _, job in pending do
		call(table.unpack(job, 1, job.n))
	end
	table.clear(pending)
end

function Terrain.setupColors()
	call("SetMaterialColor", M.Grass, Color3.fromRGB(60, 72, 42))
	call("SetMaterialColor", M.LeafyGrass, Color3.fromRGB(42, 56, 34))
	call("SetMaterialColor", M.Ground, Color3.fromRGB(76, 63, 48))
	call("SetMaterialColor", M.Mud, Color3.fromRGB(52, 42, 34))
	call("SetMaterialColor", M.Rock, Color3.fromRGB(88, 86, 84))
	call("SetMaterialColor", M.Slate, Color3.fromRGB(68, 68, 72))
end

-- Очистить область карты (лобби высоко над картой не трогаем)
function Terrain.clearMap()
	local size = Config.MapSize + 280
	call("FillBlock", CFrame.new(0, 20, 0), Vector3.new(size, 80, size), M.Air)
end

-- Пятно материала заподлицо с землёй (верх на y = top): 2-3 перекрывающихся круга — неровный край
local function patch(pos: Vector3, radius: number, material: Enum.Material, rng: Random, top: number?)
	local y = (top or 0) - 1
	for i = 1, rng:NextInteger(2, 3) do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = i == 1 and 0 or radius * rng:NextNumber(0.4, 0.8)
		local r = radius * (i == 1 and 1 or rng:NextNumber(0.45, 0.75))
		call("FillCylinder", CFrame.new(pos.X + math.cos(a) * d, y, pos.Z + math.sin(a) * d), 2, r, material)
	end
end

-- Извилистая полоса (тропа) от a до b: отрезки со смещёнными серединами
local function track(a: Vector3, b: Vector3, width: number, material: Enum.Material, rng: Random, top: number?)
	local y = (top or 0) - 1
	local len = (b - a).Magnitude
	if len < 1 then
		return
	end
	local dir = (b - a).Unit
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local steps = math.max(1, math.floor(len / 9))
	local prev = a
	for i = 1, steps do
		local t = i / steps
		local p = a:Lerp(b, t)
		if i < steps then
			p += side * rng:NextNumber(-1.4, 1.4)
		end
		local mid = (prev + p) / 2
		local seg = (p - prev).Magnitude
		local cf = CFrame.lookAt(Vector3.new(mid.X, y, mid.Z), Vector3.new(p.X, y, p.Z))
		call("FillBlock", cf, Vector3.new(width * rng:NextNumber(0.85, 1.15), 2, seg + width * 0.6), material)
		prev = p
	end
end

-- Холмы и скальные выходы за стенами. Ничего выше y = 0 не заходит ближе inner к центру по оси стены,
-- коридоры ворот (север/юг, |x| < 14) остаются свободными. side: (нормаль наружу, вдоль стены).
local function borderHills(rng: Random, half: number)
	local inner = half + 3
	local sides = {
		{ Vector3.new(1, 0, 0), Vector3.new(0, 0, 1), false },
		{ Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), false },
		{ Vector3.new(0, 0, 1), Vector3.new(1, 0, 0), true },
		{ Vector3.new(0, 0, -1), Vector3.new(1, 0, 0), true },
	}
	-- Шар с верхом на высоте top: возвращает центр по высоте и радиус «шапки» над землёй
	local function cap(r: number, top: number): (number, number)
		local yc = top - r
		return yc, math.sqrt(math.max(r * r - yc * yc, 0))
	end
	for _, s in sides do
		local out: Vector3, along: Vector3, gated: boolean = s[1], s[2], s[3]
		local a = -half - 70
		while a < half + 70 do
			local function ok(dist: number, reach: number): boolean
				-- Коридор ворот уходит от стены на ~40 стад: рядом с ним — только дальние холмы
				return not (gated and math.abs(a) < 14 + reach and dist - reach < half + 45)
			end
			-- Ближний вал: невысокий, травянистый
			local r1 = rng:NextNumber(9, 15)
			local yc1, rc1 = cap(r1, rng:NextNumber(4, 11))
			local d1 = inner + rc1 + rng:NextNumber(0, 6)
			if ok(d1, rc1) then
				local p = out * d1 + along * a + Vector3.new(0, yc1, 0)
				call("FillBall", p, r1, rng:NextNumber() < 0.65 and M.LeafyGrass or M.Grass)
			end
			-- Дальний холм: высокий, с камнем
			local r2 = rng:NextNumber(18, 28)
			local top2 = rng:NextNumber(16, 32)
			local yc2, rc2 = cap(r2, top2)
			local d2 = math.max(half + 28 + rng:NextNumber(0, 18), inner + rc2)
			if ok(d2, rc2) then
				local roll = rng:NextNumber()
				local mat = roll < 0.72 and M.LeafyGrass or (roll < 0.88 and M.Ground or M.Grass)
				call("FillBall", out * d2 + along * a + Vector3.new(0, yc2, 0), r2, mat)
				-- Скальный выход на склоне, обращённом к карте
				if rng:NextNumber() < 0.45 then
					local size = Vector3.new(rng:NextNumber(6, 13), rng:NextNumber(5, 10), rng:NextNumber(4, 8))
					local reach = size.Magnitude / 2
					local dist = math.max(d2 - rc2 * 0.45, inner + reach)
					local h = math.max(top2 * 0.45, 2)
					local cf = CFrame.new(out * dist + along * (a + rng:NextNumber(-4, 4)) + Vector3.new(0, h, 0))
						* CFrame.Angles(math.rad(rng:NextNumber(-30, 30)), rng:NextNumber(0, math.pi * 2), math.rad(rng:NextNumber(-30, 30)))
					call("FillBlock", cf, size, rng:NextNumber() < 0.6 and M.Rock or M.Slate)
				elseif rng:NextNumber() < 0.3 then
					-- Валун, наполовину ушедший в склон
					local rb = rng:NextNumber(3.5, 6)
					local dist = math.max(d2 - rc2 * 0.6, inner + rb)
					call("FillBall", out * dist + along * a + Vector3.new(0, top2 * 0.35, 0), rb, M.Rock)
				end
			end
			a += rng:NextNumber(10, 16)
		end
	end
	-- Дорога из ворот в лес
	for _, z in { 1, -1 } do
		track(Vector3.new(0, 0, z * (half + 2)), Vector3.new(0, 0, z * (half + 120)), 7, M.Ground, rng)
	end
end

-- Земля карты. paths — список {From = Vector3, To = Vector3, Width = number} (тропинки между ячейками)
function Terrain.buildMap(rng: Random, paths: { any }?)
	local size = Config.MapSize
	local half = size / 2
	Terrain.clearMap()
	-- Основание: трава толщиной 8 стад, верх на y = 0
	call("FillBlock", CFrame.new(0, -4, 0), Vector3.new(size + 260, 8, size + 260), M.Grass)
	-- Пятна: густая трава, голая земля, лужи грязи (неровные, разного размера)
	for _, spec in { { 26, M.LeafyGrass, 5, 12 }, { 16, M.Ground, 3, 7 }, { 10, M.Mud, 2, 4.5 } } do
		for _ = 1, spec[1] do
			patch(Vector3.new(rng:NextNumber(-half, half), 0, rng:NextNumber(-half, half)), rng:NextNumber(spec[3], spec[4]), spec[2], rng)
		end
	end
	-- Густая трава вдоль подножия внешних стен
	for _, s in { 1, -1 } do
		call("FillBlock", CFrame.new(s * (half - 2.5), -1, 0), Vector3.new(4, 2, size), M.LeafyGrass)
		call("FillBlock", CFrame.new(0, -1, s * (half - 2.5)), Vector3.new(size, 2, 4), M.LeafyGrass)
	end
	-- Тропинки (земля, местами грязь)
	if paths then
		for _, path in paths do
			local a: Vector3, b: Vector3 = path.From, path.To
			local w = path.Width or 5
			track(a, b, w, M.Ground, rng)
			if rng:NextNumber() < 0.5 then
				local p = a:Lerp(b, rng:NextNumber(0.2, 0.8))
				patch(p, w * 0.45, M.Mud, rng)
			end
		end
	end
	flush()
	borderHills(rng, half)
end

-- Направления троп от костра в лобби (градусы от +X к +Z)
Terrain.LobbyPaths = { 34, 166, 290 }

-- Поляна в лобби: плоская внутри ограды (±60), холмы и скалы снаружи
function Terrain.buildLobby()
	local pos = Config.LobbyPosition
	local rng = Random.new(7)
	call("FillBlock", CFrame.new(pos + Vector3.new(0, -4, 0)), Vector3.new(240, 8, 240), M.Grass)
	-- Опушка: густая трава кольцом, ближе к костру — вытоптанная земля
	for _ = 1, 22 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(26, 56)
		patch(pos + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), rng:NextNumber(6, 12), M.LeafyGrass, rng, pos.Y)
	end
	patch(pos, 12, M.Ground, rng, pos.Y)
	patch(pos, 5, M.Mud, rng, pos.Y)
	for _ = 1, 8 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(8, 16)
		patch(pos + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), rng:NextNumber(2.5, 4.5), rng:NextNumber() < 0.5 and M.Mud or M.Ground, rng, pos.Y)
	end
	-- Тропы от костра в лес (Art/Lobby оставляет их свободными от деревьев)
	for _, deg in Terrain.LobbyPaths do
		local a = math.rad(deg)
		track(pos, pos + Vector3.new(math.cos(a) * 58, 0, math.sin(a) * 58), 4, M.Ground, rng, pos.Y)
	end
	-- Холмы за оградой
	for i = 1, 30 do
		local a = i / 30 * math.pi * 2 + rng:NextNumber(-0.08, 0.08)
		local r = rng:NextNumber(14, 24)
		local top = rng:NextNumber(8, 22)
		local dist = 64 + math.sqrt(math.max(r * r - (top - r) ^ 2, 0)) + rng:NextNumber(0, 10)
		local p = pos + Vector3.new(math.cos(a) * dist, top - r, math.sin(a) * dist)
		call("FillBall", p, r, rng:NextNumber() < 0.75 and M.LeafyGrass or M.Ground)
		if rng:NextNumber() < 0.4 then
			local size = Vector3.new(rng:NextNumber(5, 10), rng:NextNumber(4, 8), rng:NextNumber(4, 7))
			local cf = CFrame.new(pos + Vector3.new(math.cos(a) * (dist - r * 0.4), top * 0.5, math.sin(a) * (dist - r * 0.4)))
				* CFrame.Angles(math.rad(rng:NextNumber(-25, 25)), rng:NextNumber(0, math.pi * 2), math.rad(rng:NextNumber(-25, 25)))
			call("FillBlock", cf, size, M.Slate)
		end
	end
end

return Terrain
