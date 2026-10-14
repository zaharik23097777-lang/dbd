-- Природа: деревья, сухие деревья, камни, кукуруза, туман, огонь, мелочи по всей карте.
-- Функции ячеек получают (map, cf, rng); cf — центр ячейки 22x22, ничего твёрдого дальше ±10.5.
-- Модули: NatureTrees (ели, сухие деревья, пни), NatureGround (камни, кукуруза, трава),
-- NatureFX (огонь, туман), NatureScatter (разброс мелочей и лес за стеной).
local Trees = require(script.Parent.NatureTrees)
local Ground = require(script.Parent.NatureGround)
local FX = require(script.Parent.NatureFX)
local Scatter = require(script.Parent.NatureScatter)

local Nature = {}

-- Группа из 2-3 елей в ячейке (≤ 40 деталей на дерево; твёрдый только ствол)
function Nature.trees(map, cf: CFrame, rng: Random)
	local count = rng:NextInteger(2, 3)
	local yaw = rng:NextNumber(0, math.pi * 2)
	for i = 1, count do
		-- Разносим деревья по кругу, чтобы кроны не слипались в один ком; первое — самое большое
		local a = yaw + i * math.pi * 2 / count + rng:NextNumber(-0.3, 0.3)
		local r = rng:NextNumber(6, 8.5)
		Trees.pine(map.Walls, cf * CFrame.new(math.cos(a) * r, 0, math.sin(a) * r), rng, { Scale = i == 1 and 1.1 or 0.85 })
	end
end

-- Сухое дерево (на нём сидят вороны)
function Nature.deadTree(map, cf: CFrame, rng: Random)
	Trees.dead(map.Walls, cf, rng)
	table.insert(map.CrowSpots, cf * CFrame.new(0, 0, 3))
end

-- Группа валунов на каменном бугре (≤ 14 деталей)
function Nature.rocks(map, cf: CFrame, rng: Random)
	Ground.rocks(map.Walls, cf, rng)
end

-- Кукурузное поле: сквозь него можно пройти и спрятаться (≤ 120 деталей, ничего не сталкивается)
function Nature.corn(map, cf: CFrame, rng: Random)
	Ground.corn(map.Decor, cf, rng)
end

-- Низкий туман (одна деталь-излучатель)
function Nature.fog(map, pos: Vector3, rng: Random)
	FX.fog(map.Decor, pos, rng)
end

-- Огонь (костёр, бочка). Возвращает невидимую деталь-источник.
function Nature.fire(parent: Instance, cf: CFrame, size: number): BasePart
	return FX.fire(parent, cf, size)
end

-- Одиночная ель (лобби, края карты)
function Nature.tree(parent: Instance, cf: CFrame, rng: Random)
	Trees.pine(parent, cf, rng)
end

-- Мелочи по всей карте и лес за внешней стеной (≤ 450 деталей)
function Nature.scatter(map, rng: Random)
	Scatter.run(map, rng)
end

return Nature
