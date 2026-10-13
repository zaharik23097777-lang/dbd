-- Процедурно строит карту (каждый раунд новая раскладка), лобби и освещение.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage.Shared.Config)
local Props = require(script.Parent.Props)

local P = Props.part
local A = Props.A

local MapBuilder = {}

local CELL = 22

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function shuffle(list, rng: Random)
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
end

export type MapData = {
	Model: Model,
	Walls: Folder,
	Decor: Folder,
	Generators: Folder,
	Hooks: Folder,
	Pallets: Folder,
	Windows: Folder,
	ExitGates: Folder,
	Lockers: Folder,
	Totems: Folder,
	Chests: Folder,
	Traps: Folder,
	Crows: Folder,
	Effects: Folder,
	Hatch: Model,
	TrapSpots: { CFrame },
	CrowSpots: { CFrame },
	SurvivorSpawn: Vector3,
	KillerSpawn: Vector3,
	ChestSpots: { CFrame },
	TotemSpots: { CFrame },
}

------------------------------------------------------------------------
-- Постройки
------------------------------------------------------------------------

local function palletLoop(map, cf: CFrame, rng: Random)
	local style = rng:NextNumber() < 0.5 and "Wood" or "Concrete"
	local walls = map.Walls
	Props.wall(walls, cf * CFrame.new(-5.6, 4, 0), Vector3.new(5.6, 8, 1.5), style)
	Props.wall(walls, cf * CFrame.new(5.6, 4, 0), Vector3.new(5.6, 8, 1.5), style)
	Props.wall(walls, cf * CFrame.new(-8.6, 4, 4), Vector3.new(1.5, 8, 8), style)
	Props.wall(walls, cf * CFrame.new(8.6, 4, -4), Vector3.new(1.5, 8, 8), style)
	local upCF = cf * CFrame.new(-1.8, 3, 1) * A(0, 0, 78)
	Props.pallet(map.Pallets, upCF, cf * CFrame.new(0, 1.5, 0))
	table.insert(map.TrapSpots, cf * CFrame.new(0, 0, rng:NextNumber() < 0.5 and 3.5 or -3.5))
	table.insert(map.CrowSpots, cf * CFrame.new(-5.6, 8, 0))
end

local function windowLoop(map, cf: CFrame, rng: Random)
	local style = rng:NextNumber() < 0.5 and "Brick" or "Concrete"
	Props.wallWithOpenings(map.Walls, cf, 18, 10, 1.5, {
		{ Center = 0, Width = 4, Sill = 3, Top = 7 },
	}, style, map.Windows)
	Props.wall(map.Walls, cf * CFrame.new(-9.75, 5, -5), Vector3.new(1.5, 10, 10), style)
	Props.wall(map.Walls, cf * CFrame.new(9.75, 5, 5), Vector3.new(1.5, 10, 10), style)
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
local function shack(map, cf: CFrame)
	local walls = map.Walls
	local h = 9
	Props.wallWithOpenings(walls, cf * CFrame.new(0, 0, -8), 17, h, 1, {
		{ Center = 0, Width = 5.8, Sill = 0, Top = 7 },
	}, "Wood", map.Windows)
	Props.wallWithOpenings(walls, cf * CFrame.new(0, 0, 8), 17, h, 1, {
		{ Center = 3, Width = 4, Sill = 3, Top = 7 },
	}, "Wood", map.Windows)
	Props.wallWithOpenings(walls, cf * CFrame.new(-8, 0, 0) * A(0, 90, 0), 15, h, 1, {
		{ Center = 2, Width = 4, Sill = 3, Top = 7 },
	}, "Wood", map.Windows)
	Props.wallWithOpenings(walls, cf * CFrame.new(8, 0, 0) * A(0, 90, 0), 15, h, 1, {
		{ Center = -2, Width = 5, Sill = 0, Top = 7 },
	}, "Wood", map.Windows)
	roof(walls, cf * CFrame.new(0, h + 0.3, 0) * A(0, 0, 4), Vector3.new(19, 0.6, 19))
	floor(map.Decor, cf, Vector2.new(15.5, 15.5))
	Props.pallet(map.Pallets, cf * CFrame.new(-1.8, 3, -7) * A(0, 0, 78), cf * CFrame.new(0, 1.5, -8))
	Props.locker(map.Lockers, cf * CFrame.new(-5.5, 0, 6.2))
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
local function house(map, cf: CFrame)
	local walls = map.Walls
	local h = 10
	Props.wallWithOpenings(walls, cf * CFrame.new(0, 0, -9), 21, h, 1, {
		{ Center = -5, Width = 5.8, Sill = 0, Top = 7.5 },
		{ Center = 5, Width = 4, Sill = 3, Top = 7 },
	}, "Brick", map.Windows)
	Props.wallWithOpenings(walls, cf * CFrame.new(0, 0, 9), 21, h, 1, {
		{ Center = -5, Width = 4, Sill = 3, Top = 7 },
		{ Center = 5, Width = 4.5, Sill = 0, Top = 7.5 },
	}, "Brick", map.Windows)
	Props.wallWithOpenings(walls, cf * CFrame.new(-10, 0, 0) * A(0, 90, 0), 17, h, 1, {
		{ Center = 2, Width = 4, Sill = 3, Top = 7 },
	}, "Brick", map.Windows)
	Props.wall(walls, cf * CFrame.new(10, h / 2, 0), Vector3.new(1, h, 17), "Brick")
	Props.wallWithOpenings(walls, cf * CFrame.new(0, 0, 0) * A(0, 90, 0), 17, h, 0.8, {
		{ Center = 3, Width = 4.5, Sill = 0, Top = 7.5 },
	}, "Wood", map.Windows)
	roof(walls, cf * CFrame.new(0, h + 0.3, 0), Vector3.new(23, 0.6, 21))
	floor(map.Decor, cf, Vector2.new(19.5, 17.5))
	Props.pallet(map.Pallets, cf * CFrame.new(-6.8, 3, -8) * A(0, 0, 78), cf * CFrame.new(-5, 1.5, -9))
	Props.locker(map.Lockers, cf * CFrame.new(-8, 0, 6.8))
	Props.locker(map.Lockers, cf * CFrame.new(7.6, 0, 6.8))
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

------------------------------------------------------------------------
-- Карта
------------------------------------------------------------------------

function MapBuilder.BuildMap(seed: number?): MapData
	local old = workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end

	local rng = Random.new(seed or os.clock() * 1000)
	local size = Config.MapSize
	local half = size / 2

	local model = Instance.new("Model")
	model.Name = "Map"
	local map = {
		Model = model,
		Walls = folder("Walls", model),
		Decor = folder("Decor", model),
		Generators = folder("Generators", model),
		Hooks = folder("Hooks", model),
		Pallets = folder("Pallets", model),
		Windows = folder("Windows", model),
		ExitGates = folder("ExitGates", model),
		Lockers = folder("Lockers", model),
		Totems = folder("Totems", model),
		Chests = folder("Chests", model),
		Traps = folder("Traps", model),
		Crows = folder("Crows", model),
		Effects = folder("Effects", model),
		TrapSpots = {},
		CrowSpots = {},
		ChestSpots = {},
		TotemSpots = {},
	}

	P(model, {
		Name = "Ground",
		Size = Vector3.new(size + 4, 2, size + 4),
		CFrame = CFrame.new(0, -1, 0),
		Color = Color3.fromRGB(42, 52, 33),
		Material = Enum.Material.Grass,
	})

	-- Внешние стены с проёмами под ворота на севере и юге
	local wallH = 16
	local gateGap = 16
	local sideLen = (size - gateGap) / 2
	for _, side in { 1, -1 } do
		for _, dir in { 1, -1 } do
			Props.wall(
				map.Walls,
				CFrame.new(dir * (gateGap / 2 + sideLen / 2), wallH / 2, side * half),
				Vector3.new(sideLen, wallH, 2)
			)
		end
		Props.wall(map.Walls, CFrame.new(side * half, wallH / 2, 0), Vector3.new(2, wallH, size))
	end
	for i, side in { 1, -1 } do
		Props.exitGate(map.ExitGates, side, i)
	end

	-- Сетка ячеек
	local n = math.floor(size / CELL)
	local cells = {}
	local center
	for ix = 1, n do
		for iz = 1, n do
			local cx = -half + CELL * (ix - 0.5)
			local cz = -half + CELL * (iz - 0.5)
			local nearGate = math.abs(cx) < CELL and (iz == 1 or iz == n)
			if ix == math.ceil(n / 2) and iz == math.ceil(n / 2) then
				center = Vector3.new(cx, 0, cz)
			elseif not nearGate then
				table.insert(cells, Vector3.new(cx, 0, cz))
			end
		end
	end
	shuffle(cells, rng)

	local idx = 0
	local function nextCell(): (CFrame, Vector3)
		idx += 1
		local c = cells[idx]
		local rot = rng:NextInteger(0, 3) * 90
		return CFrame.new(c) * A(0, rot, 0), c
	end

	shack(map, CFrame.new(center) * A(0, rng:NextInteger(0, 3) * 90, 0))
	house(map, (nextCell()))

	for i = 1, Config.GeneratorCount do
		local cf = nextCell()
		Props.generator(map.Generators, cf, i)
		Props.wall(map.Walls, cf * CFrame.new(0, 3, 6.5), Vector3.new(10, 6, 1.5), rng:NextNumber() < 0.5 and "Wood" or "Brick")
		table.insert(map.TrapSpots, cf * CFrame.new(rng:NextNumber(-4, 4), 0, -4))
	end
	for i = 1, 8 do
		local cf = nextCell()
		Props.hook(map.Hooks, cf, i)
		table.insert(map.CrowSpots, cf * CFrame.new(0, 12, 0))
	end
	for _ = 1, 8 do
		palletLoop(map, (nextCell()), rng)
	end
	for _ = 1, 3 do
		windowLoop(map, (nextCell()), rng)
	end
	for _ = 1, 2 do
		local cf = nextCell()
		Props.wall(map.Walls, cf * CFrame.new(0, 4, 2), Vector3.new(8, 8, 1.2), "Wood")
		Props.locker(map.Lockers, cf * CFrame.new(-2, 0, 0.3))
		Props.locker(map.Lockers, cf * CFrame.new(1.4, 0, 0.3))
	end
	for _ = 1, 3 do
		local cf = nextCell()
		table.insert(map.TotemSpots, cf)
		Props.rock(map.Walls, cf * CFrame.new(0, 0, 6), rng)
	end
	for _ = 1, 3 do
		local cf = nextCell()
		table.insert(map.ChestSpots, cf)
		Props.hay(map.Walls, cf * CFrame.new(0, 0, 5), rng)
	end

	-- Люк
	local hatchCF = nextCell()
	map.Hatch = Props.hatch(map.Model, hatchCF)

	-- Тотемы (один — проклятый) и сундуки
	shuffle(map.TotemSpots, rng)
	for i = 1, math.min(5, #map.TotemSpots) do
		Props.totem(map.Totems, map.TotemSpots[i], i == 1, rng)
	end
	for _, cf in map.ChestSpots do
		Props.chest(map.Chests, cf)
	end

	-- Декор
	for _ = 1, 4 do
		Props.junkPile(map.Walls, (nextCell()), rng)
	end
	for _ = 1, 3 do
		Props.corn(map.Decor, (nextCell()), rng)
	end
	for _ = 1, 6 do
		local cf = nextCell()
		for _ = 1, rng:NextInteger(2, 3) do
			Props.tree(map.Walls, cf * CFrame.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8)), rng)
		end
	end
	for _ = 1, 3 do
		local cf = nextCell()
		Props.deadTree(map.Walls, cf, rng)
		table.insert(map.CrowSpots, cf * CFrame.new(0, 0, 3))
	end
	for _ = 1, 4 do
		Props.rock(map.Walls, (nextCell()), rng)
	end
	for _ = 1, 2 do
		Props.tombstones(map.Walls, (nextCell()), rng)
	end
	for _ = 1, 3 do
		local cf = nextCell()
		Props.barrel(map.Walls, cf * CFrame.new(-3, 0, 0), rng)
		Props.barrel(map.Walls, cf * CFrame.new(-0.6, 0, 1), rng)
		Props.fire(map.Decor, cf * CFrame.new(-3, 3.2, 0), 1)
		Props.hay(map.Walls, cf * CFrame.new(4, 0, 0), rng)
	end
	for _ = 1, 3 do
		local cf = nextCell()
		Props.fence(map.Walls, cf * CFrame.new(0, 0, -4), 16)
		table.insert(map.CrowSpots, cf * CFrame.new(rng:NextNumber(-6, 6), 4.5, -4))
	end
	for _ = 1, 5 do
		Props.lamp(map.Decor, (nextCell()))
	end

	-- Туман по всей карте
	for _ = 1, 14 do
		Props.fog(map.Decor, Vector3.new(rng:NextNumber(-half, half), 1, rng:NextNumber(-half, half)), rng)
	end

	-- Оставшиеся пустые ячейки — для спавна
	local free = {}
	for i = idx + 1, #cells do
		table.insert(free, cells[i])
	end
	local survivorSpawn = free[1] or Vector3.new(30, 0, 30)
	local killerSpawn = survivorSpawn
	local best = -1
	for _, c in free do
		local d = (c - survivorSpawn).Magnitude
		if d > best then
			best = d
			killerSpawn = c
		end
	end
	map.SurvivorSpawn = survivorSpawn + Vector3.new(0, 3.2, 0)
	map.KillerSpawn = killerSpawn + Vector3.new(0, 3.5, 0)
	for i = 2, #free do
		table.insert(map.CrowSpots, CFrame.new(free[i] + Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6))))
	end

	model.Parent = workspace
	return map :: any
end

------------------------------------------------------------------------
-- Лобби у костра
------------------------------------------------------------------------

function MapBuilder.BuildLobby(): Model
	local existing = workspace:FindFirstChild("Lobby")
	if existing then
		return existing :: Model
	end
	local rng = Random.new(42)
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	local pos = Config.LobbyPosition
	local base = CFrame.new(pos)

	P(lobby, {
		Name = "Ground",
		Size = Vector3.new(120, 2, 120),
		CFrame = base * CFrame.new(0, -1, 0),
		Color = Color3.fromRGB(38, 48, 30),
		Material = Enum.Material.Grass,
	})
	-- Невидимые стены
	for _, d in
		{
			{ Vector3.new(0, 15, 60), Vector3.new(120, 30, 2) },
			{ Vector3.new(0, 15, -60), Vector3.new(120, 30, 2) },
			{ Vector3.new(60, 15, 0), Vector3.new(2, 30, 120) },
			{ Vector3.new(-60, 15, 0), Vector3.new(2, 30, 120) },
		}
	do
		P(lobby, { Name = "Barrier", Size = d[2], CFrame = base * CFrame.new(d[1]), Transparency = 1 })
	end

	-- Костёр
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		P(lobby, {
			Name = "FireStone",
			Size = Vector3.new(1.2, 0.8, 1),
			CFrame = base * CFrame.new(math.cos(a) * 2.4, 0.4, math.sin(a) * 2.4) * A(0, -math.deg(a), 0),
			Color = Color3.fromRGB(80, 78, 75),
			Material = Enum.Material.Slate,
		})
	end
	for i = 1, 4 do
		P(lobby, {
			Name = "FireLog",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3, 0.6, 0.6),
			CFrame = base * CFrame.new(0, 0.5, 0) * A(0, i * 45, 25),
			Color = Color3.fromRGB(50, 35, 25),
			Material = Enum.Material.Wood,
		})
	end
	Props.fire(lobby, base * CFrame.new(0, 1.2, 0), 2.2)

	-- Брёвна-сиденья вокруг костра
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		local seatPos = pos + Vector3.new(math.cos(a) * 9, 0.7, math.sin(a) * 9)
		local seat = Instance.new("Seat")
		seat.Name = "LogSeat"
		seat.Anchored = true
		seat.Shape = Enum.PartType.Cylinder
		seat.Size = Vector3.new(5, 1.4, 1.4)
		seat.CFrame = CFrame.lookAt(seatPos, Vector3.new(pos.X, seatPos.Y, pos.Z))
		seat.Color = Color3.fromRGB(70, 50, 35)
		seat.Material = Enum.Material.Wood
		seat.CollisionGroup = "DBDSeats"
		seat.Parent = lobby
	end

	-- Палатки, деревья, туман
	for i = 1, 3 do
		local a = i / 3 * math.pi * 2 + 0.5
		local tcf = CFrame.lookAt(pos + Vector3.new(math.cos(a) * 22, 0, math.sin(a) * 22), pos)
		for _, side in { -1, 1 } do
			local w = Instance.new("WedgePart")
			w.Anchored = true
			w.Size = Vector3.new(0.3, 4, 3)
			w.CFrame = tcf * CFrame.new(side * 1.5, 2, 0) * A(0, side * 90, 0)
			w.Color = Color3.fromRGB(70 + i * 20, 80, 60)
			w.Material = Enum.Material.Fabric
			w.Parent = lobby
		end
		P(lobby, {
			Name = "TentFloor",
			Size = Vector3.new(6, 0.2, 6),
			CFrame = tcf * CFrame.new(0, 0.1, 0),
			Color = Color3.fromRGB(60, 55, 45),
			Material = Enum.Material.Fabric,
		})
	end
	for _ = 1, 26 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(32, 55)
		Props.tree(lobby, base * CFrame.new(math.cos(a) * r, 0, math.sin(a) * r), rng)
	end
	for _ = 1, 6 do
		Props.fog(lobby, pos + Vector3.new(rng:NextNumber(-40, 40), 1, rng:NextNumber(-40, 40)), rng)
	end

	-- Табличка
	local board = P(lobby, {
		Name = "Sign",
		Size = Vector3.new(12, 4, 0.4),
		CFrame = base * CFrame.new(0, 5, -26),
		Color = Color3.fromRGB(60, 40, 30),
		Material = Enum.Material.WoodPlanks,
	})
	for _, x in { -5, 5 } do
		P(lobby, {
			Name = "SignPost",
			Size = Vector3.new(0.5, 5, 0.5),
			CFrame = base * CFrame.new(x, 2.5, -26),
			Color = Color3.fromRGB(50, 35, 25),
			Material = Enum.Material.Wood,
		})
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.CanvasSize = Vector2.new(600, 200)
	gui.Parent = board
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = "DEAD BY DAYLIGHT"
	text.Font = Enum.Font.Creepster
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(190, 20, 20)
	text.Parent = gui

	lobby.Parent = workspace
	return lobby
end

-- Точка появления в лобби (по кругу у костра)
function MapBuilder.LobbySpawn(): CFrame
	local pos = Config.LobbyPosition
	local a = math.random() * math.pi * 2
	local p = pos + Vector3.new(math.cos(a) * 14, 3.5, math.sin(a) * 14)
	return CFrame.lookAt(p, Vector3.new(pos.X, p.Y, pos.Z))
end

------------------------------------------------------------------------
-- Освещение
------------------------------------------------------------------------

function MapBuilder.SetupLighting()
	Lighting.ClockTime = 0.3
	Lighting.Brightness = 1.2
	Lighting.Ambient = Color3.fromRGB(35, 35, 50)
	Lighting.OutdoorAmbient = Color3.fromRGB(70, 70, 90)
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true
	Lighting.FogEnd = 100000
	for _, child in Lighting:GetChildren() do
		child:Destroy()
	end

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.48
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(120, 130, 155)
	atmosphere.Decay = Color3.fromRGB(40, 45, 60)
	atmosphere.Glare = 0
	atmosphere.Haze = 2.2
	atmosphere.Parent = Lighting

	local sky = Instance.new("Sky")
	sky.CelestialBodiesShown = true
	sky.MoonAngularSize = 14
	sky.StarCount = 1500
	sky.Parent = Lighting

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = -0.35
	cc.Contrast = 0.15
	cc.Brightness = 0.02
	cc.TintColor = Color3.fromRGB(215, 225, 255)
	cc.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 30
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
end

return MapBuilder
