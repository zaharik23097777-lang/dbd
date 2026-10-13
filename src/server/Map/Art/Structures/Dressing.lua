-- Оформление ячеек: петли с паллетой/окном, укрытие у генератора, шкафчики, свалка, бочки, сено,
-- надгробия, забор, фонарь. Функции получают map, cf (центр ячейки 22x22, -Z = «перед») и rng.
local Common = require(script.Parent.Common)
local Legacy = require(script.Parent.Parent.Legacy)

local P = Legacy.part
local A = Legacy.A

local Dressing = {}

-- Укрытие рядом с генератором (генератор стоит в cf)
function Dressing.generatorCover(map, cf: CFrame, rng: Random)
	Legacy.wall(map.Walls, cf * CFrame.new(0, 3, 6.5), Vector3.new(10, 6, 1.5), rng:NextNumber() < 0.5 and "Wood" or "Brick")
end

-- Стенка с двумя шкафчиками
function Dressing.lockerNook(map, cf: CFrame, rng: Random)
	Legacy.wall(map.Walls, cf * CFrame.new(0, 4, 2), Vector3.new(8, 8, 1.2), "Wood")
	Common.locker(map, rng, cf * CFrame.new(-2, 0, 0.3))
	Common.locker(map, rng, cf * CFrame.new(1.4, 0, 0.3))
end

function Dressing.junk(map, cf: CFrame, rng: Random)
	Legacy.junkPile(map.Walls, cf, rng)
end

function Dressing.barrelFire(map, cf: CFrame, rng: Random)
	Legacy.barrel(map.Walls, cf * CFrame.new(-3, 0, 0), rng)
	Legacy.barrel(map.Walls, cf * CFrame.new(-0.6, 0, 1), rng)
	Legacy.fire(map.Decor, cf * CFrame.new(-3, 3.2, 0), 1)
	Legacy.hay(map.Walls, cf * CFrame.new(4, 0, 0), rng)
end

function Dressing.hay(map, cf: CFrame, rng: Random)
	Legacy.hay(map.Walls, cf, rng)
end

function Dressing.tombstones(map, cf: CFrame, rng: Random)
	Legacy.tombstones(map.Walls, cf, rng)
end

function Dressing.fence(map, cf: CFrame, rng: Random)
	Legacy.fence(map.Walls, cf * CFrame.new(0, 0, -4), 16)
	table.insert(map.CrowSpots, cf * CFrame.new(rng:NextNumber(-6, 6), 4.5, -4))
end

function Dressing.lamp(map, cf: CFrame, _rng: Random)
	Legacy.lamp(map.Decor, cf)
end


function Dressing.palletLoop(map, cf: CFrame, rng: Random)
	local style = rng:NextNumber() < 0.5 and "Wood" or "Concrete"
	local walls = map.Walls
	Legacy.wall(walls, cf * CFrame.new(-5.6, 4, 0), Vector3.new(5.6, 8, 1.5), style)
	Legacy.wall(walls, cf * CFrame.new(5.6, 4, 0), Vector3.new(5.6, 8, 1.5), style)
	Legacy.wall(walls, cf * CFrame.new(-8.6, 4, 4), Vector3.new(1.5, 8, 8), style)
	Legacy.wall(walls, cf * CFrame.new(8.6, 4, -4), Vector3.new(1.5, 8, 8), style)
	local upCF = cf * CFrame.new(-1.8, 3, 1) * A(0, 0, 78)
	Common.pallet(map, rng, upCF, cf * CFrame.new(0, 1.5, 0))
	table.insert(map.TrapSpots, cf * CFrame.new(0, 0, rng:NextNumber() < 0.5 and 3.5 or -3.5))
	table.insert(map.CrowSpots, cf * CFrame.new(-5.6, 8, 0))
end

function Dressing.windowLoop(map, cf: CFrame, rng: Random)
	local style = rng:NextNumber() < 0.5 and "Brick" or "Concrete"
	Legacy.wallWithOpenings(map.Walls, cf, 18, 10, 1.5, {
		{ Center = 0, Width = 4, Sill = 3, Top = 7 },
	}, style, map.Windows)
	Legacy.wall(map.Walls, cf * CFrame.new(-9.75, 5, -5), Vector3.new(1.5, 10, 10), style)
	Legacy.wall(map.Walls, cf * CFrame.new(9.75, 5, 5), Vector3.new(1.5, 10, 10), style)
	table.insert(map.TrapSpots, cf * CFrame.new(0, 0, -3))
end


return Dressing
