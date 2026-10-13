-- Процедурно строит карту (каждый раунд новая раскладка) и освещение.
-- Здесь только РАСКЛАДКА по ячейкам 22x22; внешний вид — в модулях Art/* и Terrain.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage.Shared.Config)
local Templates = require(script.Parent.Art.Templates)
local Structures = require(script.Parent.Art.Structures)
local Nature = require(script.Parent.Art.Nature)
local Lobby = require(script.Parent.Art.Lobby)
local Terrain = require(script.Parent.Terrain)

local function A(x: number?, y: number?, z: number?): CFrame
	return CFrame.Angles(math.rad(x or 0), math.rad(y or 0), math.rad(z or 0))
end

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

	-- Внешние стены с проёмами под ворота на севере и юге
	Structures.outerWalls(map, size, 16)
	for i, side in { 1, -1 } do
		local gateCF = CFrame.new(0, 0, side * half) * A(0, side == 1 and 0 or 180, 0)
		local gate = Templates.spawn("ExitGate", gateCF, map.ExitGates)
		gate.Name = "ExitGate" .. i
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

	Structures.shack(map, CFrame.new(center) * A(0, rng:NextInteger(0, 3) * 90, 0), rng)
	Structures.house(map, (nextCell()), rng)

	for i = 1, Config.GeneratorCount do
		local cf = nextCell()
		local gen = Templates.spawn("Generator", cf, map.Generators, rng)
		gen.Name = "Generator" .. i
		Structures.generatorCover(map, cf, rng)
		table.insert(map.TrapSpots, cf * CFrame.new(rng:NextNumber(-4, 4), 0, -4))
	end
	for i = 1, 8 do
		local cf = nextCell()
		local hook = Templates.spawn("Hook", cf, map.Hooks, rng)
		hook.Name = "Hook" .. i
		table.insert(map.CrowSpots, cf * CFrame.new(0, 12, 0))
	end
	for _ = 1, 8 do
		Structures.palletLoop(map, (nextCell()), rng)
	end
	for _ = 1, 3 do
		Structures.windowLoop(map, (nextCell()), rng)
	end
	for _ = 1, 2 do
		Structures.lockerNook(map, (nextCell()), rng)
	end
	for _ = 1, 3 do
		local cf = nextCell()
		table.insert(map.TotemSpots, cf)
		Nature.rocks(map, cf * CFrame.new(0, 0, 6), rng)
	end
	for _ = 1, 3 do
		local cf = nextCell()
		table.insert(map.ChestSpots, cf)
		Structures.hay(map, cf * CFrame.new(0, 0, 5), rng)
	end

	-- Люк
	local hatchCF = nextCell()
	map.Hatch = Templates.spawn("Hatch", hatchCF, map.Model)

	-- Тотемы (один — проклятый) и сундуки
	shuffle(map.TotemSpots, rng)
	for i = 1, math.min(5, #map.TotemSpots) do
		Templates.spawn(i == 1 and "HexTotem" or "Totem", map.TotemSpots[i], map.Totems, rng)
	end
	for _, cf in map.ChestSpots do
		Templates.spawn("Chest", cf, map.Chests, rng)
	end

	-- Декор
	for _ = 1, 4 do
		Structures.junk(map, (nextCell()), rng)
	end
	for _ = 1, 3 do
		Nature.corn(map, (nextCell()), rng)
	end
	for _ = 1, 6 do
		Nature.trees(map, (nextCell()), rng)
	end
	for _ = 1, 3 do
		Nature.deadTree(map, (nextCell()), rng)
	end
	for _ = 1, 4 do
		Nature.rocks(map, (nextCell()), rng)
	end
	for _ = 1, 2 do
		Structures.tombstones(map, (nextCell()), rng)
	end
	for _ = 1, 3 do
		Structures.barrelFire(map, (nextCell()), rng)
	end
	for _ = 1, 3 do
		Structures.fence(map, (nextCell()), rng)
	end
	for _ = 1, 5 do
		Structures.lamp(map, (nextCell()), rng)
	end

	-- Туман по всей карте
	for _ = 1, 14 do
		Nature.fog(map, Vector3.new(rng:NextNumber(-half, half), 1, rng:NextNumber(-half, half)), rng)
	end
	Nature.scatter(map, rng)

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

	-- Ландшафт: тропинки от центра к воротам и между соседними ячейками
	local paths = {
		{ From = center, To = Vector3.new(0, 0, half), Width = 6 },
		{ From = center, To = Vector3.new(0, 0, -half), Width = 6 },
	}
	for i = 1, 10 do
		local a, b = cells[i], cells[i + 1]
		if a and b and (a - b).Magnitude < CELL * 3 then
			table.insert(paths, { From = a, To = b, Width = 4 })
		end
	end
	Terrain.buildMap(rng, paths)

	model.Parent = workspace
	return map :: any
end


------------------------------------------------------------------------
-- Освещение
------------------------------------------------------------------------

-- Лобби (модуль Art/Lobby) и ландшафт поляны
function MapBuilder.BuildLobby(): Model
	local existing = workspace:FindFirstChild("Lobby")
	if existing then
		return existing :: Model
	end
	Terrain.setupColors()
	Terrain.buildLobby()
	return Lobby.build()
end

function MapBuilder.LobbySpawn(): CFrame
	return Lobby.spawnCFrame()
end

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
