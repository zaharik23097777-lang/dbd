-- Камни, кукуруза и мелкая растительность (трава, папоротник, куст, камешки).
local Kit = require(script.Parent.Kit)
local Terrain = require(script.Parent.Parent.Terrain)

local Mat = Kit.Mat
local A = Kit.A
local V = Vector3.new
local C = CFrame.new

local Ground = {}

local DECOR = { Decor = true }

local STONE = {
	Color3.fromRGB(86, 86, 90),
	Color3.fromRGB(96, 92, 86),
	Color3.fromRGB(74, 76, 80),
}
local MOSS = Color3.fromRGB(64, 80, 46)

------------------------------------------------------------------------
-- Камни
------------------------------------------------------------------------

-- Поставить повёрнутую коробку так, чтобы её нижний угол ушёл в землю (y = cf.Y) на sink
local function seat(cf: CFrame, size: Vector3, sink: number): CFrame
	local r = cf.Rotation
	local hy = (math.abs(r.XVector.Y) * size.X + math.abs(r.YVector.Y) * size.Y + math.abs(r.ZVector.Y) * size.Z) / 2
	return r + Vector3.new(cf.X, cf.Y + hy - sink, cf.Z)
end
Ground.seat = seat

-- Валун из сильно наклонённых, наполовину вкопанных блоков и клина сверху: над землёй видны
-- косые плоскости сколов, а не коробка. facets = 2..4 детали; твёрдые — две основные плиты.
-- Возвращает CFrame основного блока и его размер (для мха).
local function boulder(parent: Instance, at: CFrame, size: Vector3, facets: number, rng: Random): (CFrame, Vector3)
	local color = Kit.jitter(STONE[rng:NextInteger(1, #STONE)], 0.05, rng)
	local mat = rng:NextNumber() < 0.6 and Mat.Slate or Mat.Rock
	local yaw = rng:NextNumber(0, 360)
	-- Основа — плита, наклонённая на 18-32° и почти наполовину вкопанная
	local lean = rng:NextNumber() < 0.5 and -1 or 1
	local rot = at * A(0, yaw, 0) * A(rng:NextNumber(18, 32) * lean, 0, rng:NextNumber(-12, 12))
	local core = seat(rot, size, size.Y * 0.45)
	local p = Kit.box(parent, core, size, color, mat)
	p.Name = "Rock"
	-- Вторая плита почти того же размера, развёрнута поперёк и наклонена в другую сторону:
	-- вместе они дают ломаный силуэт двух сросшихся глыб
	local side = size * V(rng:NextNumber(0.75, 0.95), rng:NextNumber(0.8, 0.95), rng:NextNumber(0.85, 1.05))
	local sideRot = at * C(rot:VectorToWorldSpace(V(size.X * 0.2, 0, 0))) * A(0, yaw + rng:NextNumber(40, 80), 0) * A(-lean * rng:NextNumber(14, 28), 0, rng:NextNumber(-18, 18))
	Kit.box(parent, seat(sideRot, side, side.Y * 0.4), side, Kit.jitter(color, 0.04, rng), mat).Name = "Rock"
	-- Клин-скол сверху с налётом мха
	if facets >= 3 then
		local top = V(size.X * rng:NextNumber(0.6, 0.8), size.Y * rng:NextNumber(0.35, 0.55), size.Z * rng:NextNumber(0.6, 0.8))
		local topRot = at * C(rot:VectorToWorldSpace(V(-size.X * 0.15, 0, 0))) * A(0, rng:NextNumber(0, 360), 0) * A(rng:NextNumber(-12, 12), 0, rng:NextNumber(-12, 12))
		Kit.wedge(parent, seat(topRot, top, -size.Y * 0.32), top, Kit.jitter(color:Lerp(MOSS, 0.22), 0.04, rng), mat, DECOR)
	end
	-- Ещё один плоский обломок у подножия
	if facets >= 4 then
		local slab = size * V(rng:NextNumber(0.5, 0.7), 0.35, rng:NextNumber(0.4, 0.6))
		local slabRot = at * C(rot:VectorToWorldSpace(V(-size.X * 0.45, 0, size.Z * 0.3))) * A(rng:NextNumber(-25, 25), rng:NextNumber(0, 360), rng:NextNumber(-25, 25))
		Kit.box(parent, seat(slabRot, slab, slab.Y * 0.3), slab, Kit.jitter(color, 0.05, rng), mat, DECOR)
	end
	return core, size
end

-- Пятно мха на верхней грани блока: косой плоский клин, наполовину утопленный в камень
local function moss(parent: Instance, core: CFrame, size: Vector3, rng: Random)
	local s = V(size.X * rng:NextNumber(0.35, 0.55), 0.2, size.Z * rng:NextNumber(0.4, 0.6))
	local cf = core * C(size.X * rng:NextNumber(-0.15, 0.15), size.Y / 2 + 0.02, size.Z * rng:NextNumber(-0.15, 0.15)) * A(0, rng:NextNumber(25, 65), 0)
	Kit.wedge(parent, cf, s, Kit.jitter(MOSS, 0.06, rng), Mat.LeafyGrass, DECOR)
end

-- Мелкий камень (1 деталь, декор)
function Ground.pebble(parent: Instance, cf: CFrame, rng: Random)
	local size = V(rng:NextNumber(0.8, 1.6), rng:NextNumber(0.35, 0.7), rng:NextNumber(0.7, 1.3))
	local rot = cf * A(rng:NextNumber(-20, 20), rng:NextNumber(0, 360), rng:NextNumber(-20, 20))
	local color = Kit.jitter(Kit.dark(STONE[rng:NextInteger(1, #STONE)], 0.1), 0.06, rng)
	if rng:NextNumber() < 0.7 then
		Kit.wedge(parent, seat(rot, size, size.Y * 0.4), size, color, Mat.Slate, DECOR)
	else
		Kit.box(parent, seat(rot, size, size.Y * 0.5), size, color, Mat.Rock, DECOR)
	end
end

-- Группа валунов (≤ 14 деталей) на каменном бугре из Terrain. Твёрдое — в радиусе ~4.5 от cf.
-- MapBuilder ставит камни и в 6 стадах перед тотемом (тотем — в -Z от cf), поэтому группа
-- смещена в +Z: подойти к тотему и обойти его можно с любой стороны.
function Ground.rocks(parent: Instance, cf: CFrame, rng: Random)
	local base = cf * C(0, 0, 0.8)
	-- Главный валун: шире, чем выше
	local main = V(rng:NextNumber(5, 6), rng:NextNumber(5, 6), rng:NextNumber(3.2, 4))
	local core, size = boulder(parent, base * C(rng:NextNumber(-0.4, 0.4), 0, rng:NextNumber(0, 0.4)), main, 4, rng)
	moss(parent, core, size, rng)
	-- Два валуна поменьше рядом, с дальней от тотема стороны
	for i = 1, 2 do
		local a = math.rad(i == 1 and rng:NextNumber(15, 70) or rng:NextNumber(110, 165))
		local d = rng:NextNumber(2.3, 2.9)
		local s = V(rng:NextNumber(1.8, 2.4), rng:NextNumber(1.3, 2.3), rng:NextNumber(1.6, 2.2))
		local c2, s2 = boulder(parent, base * C(math.cos(a) * d, 0, math.sin(a) * d), s, 4 - i, rng)
		if i == 1 then
			moss(parent, c2, s2, rng)
		end
	end
	-- Осыпь
	for _ = 1, 3 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(3, 4.5)
		Ground.pebble(parent, base * C(math.cos(a) * d, 0, math.sin(a) * d), rng)
	end
	-- Бугор под группой (заливается вместе с ландшафтом): земляная «юбка», из неё — каменное ядро
	local p = base.Position
	Terrain.defer("FillBall", Vector3.new(p.X, -4.2, p.Z), 5.5, Enum.Material.Ground)
	Terrain.defer("FillBall", Vector3.new(p.X, -2.2, p.Z), 3.6, Enum.Material.Rock)
end

------------------------------------------------------------------------
-- Кукуруза
------------------------------------------------------------------------

local STALK = { Color3.fromRGB(150, 140, 72), Color3.fromRGB(122, 124, 60), Color3.fromRGB(166, 148, 86) }
local LEAF = { Color3.fromRGB(150, 146, 78), Color3.fromRGB(110, 118, 56), Color3.fromRGB(170, 152, 96), Color3.fromRGB(132, 112, 70) }
local HUSK = Color3.fromRGB(184, 166, 112)

-- Лист: тонкий высокий треугольник от стебля (широкое основание у стебля, кончик отклонён наружу).
-- Листья под разными углами перекрывают друг друга и закрывают обзор лучше плоских лент.
local function leaf(parent: Instance, at: CFrame, yaw: number, lean: number, len: number, width: number, rng: Random)
	local cf = at * A(0, yaw, 0) * A(-lean, 0, 0) * C(0, len / 2, -width / 2)
	Kit.wedge(parent, cf, V(0.05, len, width), Kit.jitter(LEAF[rng:NextInteger(1, #LEAF)], 0.06, rng), Mat.Grass, DECOR)
end

-- Кукурузное поле ±8.5 (≤ 120 деталей): ряды стеблей с листьями, початками и метёлками.
-- Сквозь поле можно пройти (ничего не сталкивается), но листва закрывает обзор.
function Ground.corn(parent: Instance, cf: CFrame, rng: Random)
	local count = 0
	local LIMIT = 120
	local rows = 7
	for r = 1, rows do
		local z = -7.5 + (r - 1) * 2.5 + rng:NextNumber(-0.25, 0.25)
		local x0, x1 = -8.5 + rng:NextNumber(0, 1.2), 8.5 - rng:NextNumber(0, 1.2)
		local row = cf * C(0, 0, z) * A(0, rng:NextNumber(-2, 2), 0)
		local n = rng:NextInteger(5, 6)
		for i = 0, n - 1 do
			if count > LIMIT - 4 then
				return
			end
			local x = x0 + (i + rng:NextNumber(0.15, 0.85)) * (x1 - x0) / n
			local h = rng:NextNumber(6, 9)
			local stalk = row * C(x, 0, rng:NextNumber(-0.4, 0.4)) * A(rng:NextNumber(-5, 5), rng:NextNumber(0, 360), rng:NextNumber(-5, 5))
			Kit.box(parent, stalk * C(0, h / 2 - 0.2, 0), V(0.22, h, 0.22), Kit.jitter(STALK[rng:NextInteger(1, #STALK)], 0.05, rng), Mat.Grass, DECOR)
			-- Два листа: нижний широкий и пониклый, верхний узкий и торчащий
			local yaw = rng:NextNumber(0, 360)
			leaf(parent, stalk * C(0, h * rng:NextNumber(0.12, 0.25), 0), yaw, rng:NextNumber(28, 44), h * rng:NextNumber(0.5, 0.62), rng:NextNumber(1.1, 1.6), rng)
			leaf(parent, stalk * C(0, h * rng:NextNumber(0.4, 0.55), 0), yaw + rng:NextNumber(140, 220), rng:NextNumber(14, 30), h * rng:NextNumber(0.4, 0.5), rng:NextNumber(0.8, 1.2), rng)
			count += 3
			local roll = rng:NextNumber()
			if roll < 0.3 then
				-- Початок в обёртке, отходит от стебля
				local cob = stalk * C(0, h * 0.48, 0) * A(0, yaw + 90, 0) * A(-28, 0, 0) * C(0, 0.5, -0.25)
				Kit.vcyl(parent, cob, 1, 0.36, Kit.jitter(HUSK, 0.05, rng), Mat.Fabric, DECOR)
				count += 1
			elseif roll < 0.55 then
				-- Сухая метёлка на макушке
				leaf(parent, stalk * C(0, h - 0.3, 0), yaw + 60, rng:NextNumber(4, 14), rng:NextNumber(1, 1.6), 0.45, rng)
				count += 1
			end
		end
	end
	-- Под полем — вспаханная земля
	local p = cf.Position
	Terrain.defer("FillBlock", CFrame.new(p.X, -1, p.Z) * cf.Rotation, Vector3.new(18, 2, 18), Enum.Material.Ground)
end

------------------------------------------------------------------------
-- Мелкая растительность для разброса
------------------------------------------------------------------------

local GRASS = { Color3.fromRGB(78, 88, 50), Color3.fromRGB(96, 96, 58), Color3.fromRGB(66, 80, 46), Color3.fromRGB(110, 102, 64) }

-- Пучок травы: 2-3 узких клина веером (2-3 детали)
function Ground.tuft(parent: Instance, cf: CFrame, rng: Random)
	local color = GRASS[rng:NextInteger(1, #GRASS)]
	local yaw = rng:NextNumber(0, 360)
	for k = 1, rng:NextInteger(2, 3) do
		local h = rng:NextNumber(0.9, 1.8)
		local w = rng:NextNumber(0.9, 1.6)
		local blade = cf * A(0, yaw + k * 60, 0) * A(0, 0, rng:NextNumber(-18, 18)) * C(0, h / 2 - 0.1, 0) * A(0, 90, 0)
		Kit.wedge(parent, blade, V(0.05, h, w), Kit.jitter(color, 0.06, rng), Mat.Grass, DECOR)
	end
end

-- Папоротник: розетка из 4-5 провисающих листьев (4-5 деталей)
function Ground.fern(parent: Instance, cf: CFrame, rng: Random)
	local color = Kit.jitter(Color3.fromRGB(58, 76, 42), 0.06, rng)
	local n = rng:NextInteger(4, 5)
	local yaw0 = rng:NextNumber(0, 360)
	for k = 1, n do
		local len = rng:NextNumber(1.6, 2.4)
		local cf2 = cf * C(0, 0.15, 0) * A(0, yaw0 + k * 360 / n + rng:NextNumber(-15, 15), 0) * A(rng:NextNumber(18, 34), 0, 0) * C(0, 0, -len / 2) * A(0, 0, 90)
		Kit.wedge(parent, cf2, V(0.05, rng:NextNumber(0.6, 0.8), len), Kit.jitter(color, 0.05, rng), Mat.LeafyGrass, DECOR)
	end
end

-- Куст: низкий колючий холмик из клиньев, расходящихся от центра, и пара сухих веток (5-6 деталей)
function Ground.bush(parent: Instance, cf: CFrame, rng: Random)
	local color = Kit.jitter(Color3.fromRGB(46, 60, 38), 0.06, rng)
	local r = rng:NextNumber(1.3, 1.9)
	local h = rng:NextNumber(1.2, 1.8)
	local n = 4
	local yaw0 = rng:NextNumber(0, 360)
	for k = 1, n do
		local rr = r * rng:NextNumber(0.8, 1.15)
		local hh = h * rng:NextNumber(0.75, 1.1)
		local wedge = cf * A(0, yaw0 + k * 360 / n + rng:NextNumber(-20, 20), 0) * A(rng:NextNumber(-8, 4), 0, rng:NextNumber(-12, 12)) * C(0, hh / 2 - 0.15, -rr / 2 + 0.2)
		Kit.wedge(parent, wedge, V(rr * 1.1, hh, rr), Kit.jitter(color, 0.06, rng), Mat.LeafyGrass, DECOR)
	end
	-- Сухие прутья торчат из куста
	for _ = 1, rng:NextInteger(1, 2) do
		local a = rng:NextNumber(0, math.pi * 2)
		local from = cf.Position + Vector3.new(0, 0.3, 0)
		local to = from + Vector3.new(math.cos(a) * r * 0.8, h * rng:NextNumber(0.9, 1.3), math.sin(a) * r * 0.8)
		Kit.bar(parent, from, to, 0.1, Color3.fromRGB(78, 64, 50), Mat.Wood, DECOR)
	end
end

return Ground
