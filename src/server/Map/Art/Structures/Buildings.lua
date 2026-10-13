-- Здания: хижина маньяка (центр карты), дом из двух комнат, внешняя стена карты.
-- Функции получают map (папки и списки точек из MapBuilder), cf (центр ячейки 22x22, -Z = «перед») и rng.
local Common = require(script.Parent.Common)
local Legacy = require(script.Parent.Parent.Legacy)

local P = Legacy.part
local A = Legacy.A

local Buildings = {}

-- Внешняя стена карты с проёмами под ворота (север и юг)
function Buildings.outerWalls(map, size: number, gateGap: number)
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
function Buildings.shack(map, cf: CFrame, rng: Random)
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
	Common.pallet(map, rng, cf * CFrame.new(-1.8, 3, -7) * A(0, 0, 78), cf * CFrame.new(0, 1.5, -8))
	Common.locker(map, rng, cf * CFrame.new(-5.5, 0, 6.2))
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
function Buildings.house(map, cf: CFrame, rng: Random)
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
	Common.pallet(map, rng, cf * CFrame.new(-6.8, 3, -8) * A(0, 0, 78), cf * CFrame.new(-5, 1.5, -9))
	Common.locker(map, rng, cf * CFrame.new(-8, 0, 6.8))
	Common.locker(map, rng, cf * CFrame.new(7.6, 0, 6.8))
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


return Buildings
