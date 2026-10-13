-- Природа: деревья, сухие деревья, камни, кукуруза, туман, огонь.
-- Функции ячеек получают (map, cf, rng); cf — центр ячейки 22x22, ничего твёрдого дальше ±10.5.
local Legacy = require(script.Parent.Legacy)

local Nature = {}

-- Группа деревьев в ячейке
function Nature.trees(map, cf: CFrame, rng: Random)
	for _ = 1, rng:NextInteger(2, 3) do
		Legacy.tree(map.Walls, cf * CFrame.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8)), rng)
	end
end

-- Сухое дерево (на нём сидят вороны)
function Nature.deadTree(map, cf: CFrame, rng: Random)
	Legacy.deadTree(map.Walls, cf, rng)
	table.insert(map.CrowSpots, cf * CFrame.new(0, 0, 3))
end

function Nature.rocks(map, cf: CFrame, rng: Random)
	Legacy.rock(map.Walls, cf, rng)
end

-- Кукурузное поле: сквозь него можно пройти и спрятаться
function Nature.corn(map, cf: CFrame, rng: Random)
	Legacy.corn(map.Decor, cf, rng)
end

function Nature.fog(map, pos: Vector3, rng: Random)
	Legacy.fog(map.Decor, pos, rng)
end

-- Огонь (костёр, бочка). Возвращает невидимую деталь-источник.
function Nature.fire(parent: Instance, cf: CFrame, size: number): BasePart
	return Legacy.fire(parent, cf, size)
end

-- Одиночное дерево (лобби, края карты)
function Nature.tree(parent: Instance, cf: CFrame, rng: Random)
	Legacy.tree(parent, cf, rng)
end

-- Мелочи по всей карте (трава, ветки, мусор). Пока пусто.
function Nature.scatter(_map, _rng: Random) end

return Nature
