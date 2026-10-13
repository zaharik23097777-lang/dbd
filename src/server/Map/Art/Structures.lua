-- Постройки (ячейка карты 22x22, центр ячейки = cf, -Z = «перед»).
-- Каждая функция получает map (папки и списки точек из MapBuilder), cf и rng.
-- Правила геймплея:
--   * паллета: Structures.pallet(map, rng, upCF, dropCF) — хитбокс 5.6x3x1.2, проход сквозь проём вдоль локальной Z;
--   * окно: деталь Kind="Window" в map.Windows, высота подоконника 3, перелезают вдоль локальной Z детали;
--   * шкафчик: Structures.locker(map, rng, cf) — пол, дверь смотрит в -Z, перед дверью 3 стада свободно;
--   * ничего твёрдого дальше ±10.5 от центра ячейки; стены «петель» ≥ 7 в высоту (закрывают обзор).
--   * точки: map.TrapSpots / CrowSpots / ChestSpots / TotemSpots (CFrame на земле или на верхушке стены).
local Templates = require(script.Parent.Templates)
local Legacy = require(script.Parent.Legacy)

local P = Legacy.part
local A = Legacy.A

local Structures = {}

function Structures.pallet(map, rng: Random, upCF: CFrame, dropCF: CFrame): Model
	local pallet = Templates.spawn("Pallet", upCF, map.Pallets, rng)
	pallet:SetAttribute("DropCFrame", dropCF)
	return pallet
end

function Structures.locker(map, rng: Random, cf: CFrame): Model
	return Templates.spawn("Locker", cf, map.Lockers, rng)
end

function Structures.wall(parent: Instance, cf: CFrame, size: Vector3, style: string?)
	return Legacy.wall(parent, cf, size, style)
end

-- Внешняя стена карты с проёмами под ворота (север и юг)
function Structures.outerWalls(map, size: number, gateGap: number)
	local half = size / 2
	local wallH = 16
	local sideLen = (size - gateGap) / 2
	for _, side in { 1, -1 } do
		for _, dir in { 1, -1 } do
			Legacy.wall(map.Walls, CFrame.new(dir * (gateGap / 2 + sideLen / 2), wallH / 2, side * half), Vector3.new(sideLen, wallH, 2))
		end
		Legacy.wall(map.Walls, CFrame.new(side * half, wallH / 2, 0), Vector3.new(2, wallH, size))
	end
end

-- Укрытие рядом с генератором (генератор стоит в cf)
function Structures.generatorCover(map, cf: CFrame, rng: Random)
	Legacy.wall(map.Walls, cf * CFrame.new(0, 3, 6.5), Vector3.new(10, 6, 1.5), rng:NextNumber() < 0.5 and "Wood" or "Brick")
end

-- Стенка с двумя шкафчиками
function Structures.lockerNook(map, cf: CFrame, rng: Random)
	Legacy.wall(map.Walls, cf * CFrame.new(0, 4, 2), Vector3.new(8, 8, 1.2), "Wood")
	Structures.locker(map, rng, cf * CFrame.new(-2, 0, 0.3))
	Structures.locker(map, rng, cf * CFrame.new(1.4, 0, 0.3))
end

function Structures.junk(map, cf: CFrame, rng: Random)
	Legacy.junkPile(map.Walls, cf, rng)
end

function Structures.barrelFire(map, cf: CFrame, rng: Random)
	Legacy.barrel(map.Walls, cf * CFrame.new(-3, 0, 0), rng)
	Legacy.barrel(map.Walls, cf * CFrame.new(-0.6, 0, 1), rng)
	Legacy.fire(map.Decor, cf * CFrame.new(-3, 3.2, 0), 1)
	Legacy.hay(map.Walls, cf * CFrame.new(4, 0, 0), rng)
end

function Structures.hay(map, cf: CFrame, rng: Random)
	Legacy.hay(map.Walls, cf, rng)
end

function Structures.tombstones(map, cf: CFrame, rng: Random)
	Legacy.tombstones(map.Walls, cf, rng)
end

function Structures.fence(map, cf: CFrame, rng: Random)
	Legacy.fence(map.Walls, cf * CFrame.new(0, 0, -4), 16)
	table.insert(map.CrowSpots, cf * CFrame.new(rng:NextNumber(-6, 6), 4.5, -4))
end

function Structures.lamp(map, cf: CFrame, _rng: Random)
	Legacy.lamp(map.Decor, cf)
end


function Structures.palletLoop(map, cf: CFrame, rng: Random)
	local style = rng:NextNumber() < 0.5 and "Wood" or "Concrete"
	local walls = map.Walls
	Legacy.wall(walls, cf * CFrame.new(-5.6, 4, 0), Vector3.new(5.6, 8, 1.5), style)
	Legacy.wall(walls, cf * CFrame.new(5.6, 4, 0), Vector3.new(5.6, 8, 1.5), style)
	Legacy.wall(walls, cf * CFrame.new(-8.6, 4, 4), Vector3.new(1.5, 8, 8), style)
	Legacy.wall(walls, cf * CFrame.new(8.6, 4, -4), Vector3.new(1.5, 8, 8), style)
	local upCF = cf * CFrame.new(-1.8, 3, 1) * A(0, 0, 78)
	Structures.pallet(map, rng, upCF, cf * CFrame.new(0, 1.5, 0))
	table.insert(map.TrapSpots, cf * CFrame.new(0, 0, rng:NextNumber() < 0.5 and 3.5 or -3.5))
	table.insert(map.CrowSpots, cf * CFrame.new(-5.6, 8, 0))
end

function Structures.windowLoop(map, cf: CFrame, rng: Random)
	local style = rng:NextNumber() < 0.5 and "Brick" or "Concrete"
	Legacy.wallWithOpenings(map.Walls, cf, 18, 10, 1.5, {
		{ Center = 0, Width = 4, Sill = 3, Top = 7 },
	}, style, map.Windows)
	Legacy.wall(map.Walls, cf * CFrame.new(-9.75, 5, -5), Vector3.new(1.5, 10, 10), style)
	Legacy.wall(map.Walls, cf * CFrame.new(9.75, 5, 5), Vector3.new(1.5, 10, 10), style)
	table.insert(map.TrapSpots, cf * CFrame.new(0, 0, -3))
end

local function roof(parent: Instance, cf: CFrame, size: Vector3)
	P(parent, {
		Name = "Roof",
		Size = size,
		CFrame = cf,
		Color = Color3.fromRGB(90, 60, 45),
		Material = Enum.Material.CorrodedMetal,
	})
end

local function floor(parent: Instance, cf: CFrame, size: Vector2)
	P(parent, {
		Name = "Floor",
		Size = Vector3.new(size.X, 0.2, size.Y),
		CFrame = cf * CFrame.new(0, 0.1, 0),
		Color = Color3.fromRGB(80, 60, 45),
		Material = Enum.Material.WoodPlanks,
	})
end

-- Хижина маньяка в центре карты
function Structures.shack(map, cf: CFrame, rng: Random)
	local walls = map.Walls
	local h = 9
	Legacy.wallWithOpenings(walls, cf * CFrame.new(0, 0, -8), 17, h, 1, {
		{ Center = 0, Width = 5.8, Sill = 0, Top = 7 },
	}, "Wood", map.Windows)
	Legacy.wallWithOpenings(walls, cf * CFrame.new(0, 0, 8), 17, h, 1, {
		{ Center = 3, Width = 4, Sill = 3, Top = 7 },
	}, "Wood", map.Windows)
	Legacy.wallWithOpenings(walls, cf * CFrame.new(-8, 0, 0) * A(0, 90, 0), 15, h, 1, {
		{ Center = 2, Width = 4, Sill = 3, Top = 7 },
	}, "Wood", map.Windows)
	Legacy.wallWithOpenings(walls, cf * CFrame.new(8, 0, 0) * A(0, 90, 0), 15, h, 1, {
		{ Center = -2, Width = 5, Sill = 0, Top = 7 },
	}, "Wood", map.Windows)
	roof(walls, cf * CFrame.new(0, h + 0.3, 0) * A(0, 0, 4), Vector3.new(19, 0.6, 19))
	floor(map.Decor, cf, Vector2.new(15.5, 15.5))
	Structures.pallet(map, rng, cf * CFrame.new(-1.8, 3, -7) * A(0, 0, 78), cf * CFrame.new(0, 1.5, -8))
	Structures.locker(map, rng, cf * CFrame.new(-5.5, 0, 6.2))
	table.insert(map.ChestSpots, cf * CFrame.new(5.2, 0, 5.4))
	table.insert(map.TotemSpots, cf * CFrame.new(-11, 0, -9))
	table.insert(map.CrowSpots, cf * CFrame.new(6, h + 0.6, -6))
	-- Тусклая лампочка внутри
	local bulb = P(map.Decor, {
		Name = "Bulb",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.6, 0.6, 0.6),
		CFrame = cf * CFrame.new(0, h - 1, 0),
		Color = Color3.fromRGB(255, 200, 120),
		Material = Enum.Material.Neon,
		Decor = true,
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 160, 90)
	light.Range = 16
	light.Brightness = 1.2
	light.Shadows = true
	light.Parent = bulb
end

-- Дом из двух комнат
function Structures.house(map, cf: CFrame, rng: Random)
	local walls = map.Walls
	local h = 10
	Legacy.wallWithOpenings(walls, cf * CFrame.new(0, 0, -9), 21, h, 1, {
		{ Center = -5, Width = 5.8, Sill = 0, Top = 7.5 },
		{ Center = 5, Width = 4, Sill = 3, Top = 7 },
	}, "Brick", map.Windows)
	Legacy.wallWithOpenings(walls, cf * CFrame.new(0, 0, 9), 21, h, 1, {
		{ Center = -5, Width = 4, Sill = 3, Top = 7 },
		{ Center = 5, Width = 4.5, Sill = 0, Top = 7.5 },
	}, "Brick", map.Windows)
	Legacy.wallWithOpenings(walls, cf * CFrame.new(-10, 0, 0) * A(0, 90, 0), 17, h, 1, {
		{ Center = 2, Width = 4, Sill = 3, Top = 7 },
	}, "Brick", map.Windows)
	Legacy.wall(walls, cf * CFrame.new(10, h / 2, 0), Vector3.new(1, h, 17), "Brick")
	Legacy.wallWithOpenings(walls, cf * CFrame.new(0, 0, 0) * A(0, 90, 0), 17, h, 0.8, {
		{ Center = 3, Width = 4.5, Sill = 0, Top = 7.5 },
	}, "Wood", map.Windows)
	roof(walls, cf * CFrame.new(0, h + 0.3, 0), Vector3.new(23, 0.6, 21))
	floor(map.Decor, cf, Vector2.new(19.5, 17.5))
	Structures.pallet(map, rng, cf * CFrame.new(-6.8, 3, -8) * A(0, 0, 78), cf * CFrame.new(-5, 1.5, -9))
	Structures.locker(map, rng, cf * CFrame.new(-8, 0, 6.8))
	Structures.locker(map, rng, cf * CFrame.new(7.6, 0, 6.8))
	table.insert(map.ChestSpots, cf * CFrame.new(-7.5, 0, -2) * A(0, 90, 0))
	table.insert(map.TotemSpots, cf * CFrame.new(7, 0, -6))
	for _, x in { -5, 5 } do
		local bulb = P(map.Decor, {
			Name = "Bulb",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.6, 0.6, 0.6),
			CFrame = cf * CFrame.new(x, h - 1, 0),
			Color = Color3.fromRGB(255, 210, 140),
			Material = Enum.Material.Neon,
			Decor = true,
		})
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 170, 100)
		light.Range = 14
		light.Brightness = 1
		light.Parent = bulb
	end
end


return Structures
