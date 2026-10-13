-- Процедурно строит карту (каждый раунд новая раскладка) и лобби.
-- Ничего не нужно строить вручную в Studio.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage.Shared.Config)

local MapBuilder = {}

local CELL = 22

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		if k ~= "Parent" then
			p[k] = v
		end
	end
	p.Parent = props.Parent
	return p
end

local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function shuffle(list, rng)
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
end

local function wall(parent, cf, size)
	return part({
		Name = "Wall",
		Size = size,
		CFrame = cf,
		Color = Color3.fromRGB(92, 88, 84),
		Material = Enum.Material.Concrete,
		Parent = parent,
	})
end

------------------------------------------------------------------------
-- Объекты карты
------------------------------------------------------------------------

local function buildGenerator(parent, cf, index)
	local model = Instance.new("Model")
	model.Name = "Generator" .. index

	local body = part({
		Name = "Body",
		Size = Vector3.new(4, 3.5, 3),
		CFrame = cf * CFrame.new(0, 1.75, 0),
		Color = Color3.fromRGB(70, 75, 70),
		Material = Enum.Material.DiamondPlate,
		Parent = model,
	})
	part({
		Name = "Engine",
		Size = Vector3.new(2.6, 1.4, 2),
		CFrame = cf * CFrame.new(0, 4.2, 0),
		Color = Color3.fromRGB(40, 40, 40),
		Material = Enum.Material.Metal,
		Parent = model,
	})
	local bulb = part({
		Name = "Bulb",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.2, 1.2, 1.2),
		CFrame = cf * CFrame.new(0, 5.6, 0),
		Color = Color3.fromRGB(60, 60, 50),
		Material = Enum.Material.Glass,
		Parent = model,
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 230, 150)
	light.Range = 26
	light.Brightness = 3
	light.Enabled = false
	light.Parent = bulb

	model.PrimaryPart = body
	model:SetAttribute("Kind", "Generator")
	model:SetAttribute("Progress", 0)
	model:SetAttribute("Done", false)
	model:SetAttribute("Regressing", false)
	model.Parent = parent
	return model
end

local function buildHook(parent, cf, index)
	local model = Instance.new("Model")
	model.Name = "Hook" .. index
	local red = Color3.fromRGB(110, 20, 20)
	local pole = part({
		Name = "Pole",
		Size = Vector3.new(1, 12, 1),
		CFrame = cf * CFrame.new(0, 6, 0),
		Color = red,
		Material = Enum.Material.CorrodedMetal,
		Parent = model,
	})
	part({
		Name = "Arm",
		Size = Vector3.new(1, 1, 4),
		CFrame = cf * CFrame.new(0, 11.5, -2),
		Color = red,
		Material = Enum.Material.CorrodedMetal,
		Parent = model,
	})
	part({
		Name = "Hook",
		Size = Vector3.new(0.4, 2, 0.4),
		CFrame = cf * CFrame.new(0, 10.3, -3.6),
		Color = Color3.fromRGB(150, 150, 150),
		Material = Enum.Material.Metal,
		Parent = model,
	})
	-- Точка, где висит выживший (HumanoidRootPart)
	part({
		Name = "HangPoint",
		Size = Vector3.new(1, 1, 1),
		CFrame = cf * CFrame.new(0, 7.2, -3.9),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})
	model.PrimaryPart = pole
	model:SetAttribute("Kind", "Hook")
	model:SetAttribute("Occupant", 0)
	model.Parent = parent
	return model
end

local function buildPalletLoop(map, cf)
	local walls = map.Walls
	wall(walls, cf * CFrame.new(-5.5, 4, 0), Vector3.new(6, 8, 1.5))
	wall(walls, cf * CFrame.new(5.5, 4, 0), Vector3.new(6, 8, 1.5))
	wall(walls, cf * CFrame.new(-8.5, 4, 4), Vector3.new(1.5, 8, 8))
	wall(walls, cf * CFrame.new(8.5, 4, -4), Vector3.new(1.5, 8, 8))

	local size = Vector3.new(5.6, 3, 1.2)
	local upCF = cf * CFrame.new(-1.8, 3, 1) * CFrame.Angles(0, 0, math.rad(78))
	local dropCF = cf * CFrame.new(0, 1.5, 0)
	local pallet = part({
		Name = "Pallet",
		Size = size,
		CFrame = upCF,
		Color = Color3.fromRGB(140, 105, 60),
		Material = Enum.Material.WoodPlanks,
		CanCollide = false,
		Parent = map.Pallets,
	})
	pallet:SetAttribute("Kind", "Pallet")
	pallet:SetAttribute("State", "Up") -- Up / Dropped / Broken
	pallet:SetAttribute("DropCFrame", dropCF)
end

local function buildWindowLoop(map, cf)
	local walls = map.Walls
	wall(walls, cf * CFrame.new(-5.5, 5, 0), Vector3.new(7, 10, 1.5))
	wall(walls, cf * CFrame.new(5.5, 5, 0), Vector3.new(7, 10, 1.5))
	wall(walls, cf * CFrame.new(0, 8.5, 0), Vector3.new(4, 3, 1.5))
	wall(walls, cf * CFrame.new(-9.75, 5, -5), Vector3.new(1.5, 10, 10))
	wall(walls, cf * CFrame.new(9.75, 5, 5), Vector3.new(1.5, 10, 10))
	local sill = part({
		Name = "Window",
		Size = Vector3.new(4, 3, 1.5),
		CFrame = cf * CFrame.new(0, 1.5, 0),
		Color = Color3.fromRGB(75, 60, 45),
		Material = Enum.Material.Wood,
		Parent = map.Windows,
	})
	sill:SetAttribute("Kind", "Window")
end

local function buildRock(map, cf, rng)
	local s = Vector3.new(rng:NextNumber(5, 10), rng:NextNumber(5, 9), rng:NextNumber(5, 10))
	part({
		Name = "Rock",
		Size = s,
		CFrame = cf * CFrame.new(0, s.Y / 2, 0) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
		Color = Color3.fromRGB(85, 85, 90),
		Material = Enum.Material.Slate,
		Parent = map.Walls,
	})
end

local function buildTrees(map, cf, rng)
	for _ = 1, rng:NextInteger(2, 4) do
		local offset = Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8))
		local h = rng:NextNumber(14, 22)
		local base = cf * CFrame.new(offset)
		part({
			Name = "Trunk",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(h, 2, 2),
			CFrame = base * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(60, 45, 35),
			Material = Enum.Material.Wood,
			Parent = map.Decor,
		})
		part({
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(9, 9, 9),
			CFrame = base * CFrame.new(0, h, 0),
			Color = Color3.fromRGB(30, 50, 30),
			Material = Enum.Material.Grass,
			CanCollide = false,
			Parent = map.Decor,
		})
	end
end

local function buildLamp(map, cf)
	part({
		Name = "LampPost",
		Size = Vector3.new(0.6, 12, 0.6),
		CFrame = cf * CFrame.new(0, 6, 0),
		Color = Color3.fromRGB(30, 30, 30),
		Material = Enum.Material.Metal,
		Parent = map.Decor,
	})
	local head = part({
		Name = "LampHead",
		Size = Vector3.new(1.4, 1, 1.4),
		CFrame = cf * CFrame.new(0, 12.3, 0),
		Color = Color3.fromRGB(255, 200, 120),
		Material = Enum.Material.Neon,
		Parent = map.Decor,
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 170, 90)
	light.Range = 30
	light.Brightness = 1.5
	light.Parent = head
end

local function buildExitGate(map, side, index)
	local half = Config.MapSize / 2
	-- side = 1 (север, +Z) или -1 (юг, -Z)
	local gateX = 0
	local cf = CFrame.new(gateX, 0, side * half) * CFrame.Angles(0, side == 1 and 0 or math.pi, 0)
	-- В локальных координатах ворот: -Z смотрит внутрь карты, +Z наружу.
	local model = Instance.new("Model")
	model.Name = "ExitGate" .. index

	local door = part({
		Name = "Door",
		Size = Vector3.new(12, 12, 1.5),
		CFrame = cf * CFrame.new(0, 6, 0),
		Color = Color3.fromRGB(60, 60, 65),
		Material = Enum.Material.DiamondPlate,
		Parent = model,
	})
	part({
		Name = "Frame",
		Size = Vector3.new(14, 2, 2),
		CFrame = cf * CFrame.new(0, 13, 0),
		Color = Color3.fromRGB(40, 40, 40),
		Material = Enum.Material.Metal,
		Parent = model,
	})
	local switch = part({
		Name = "Switch",
		Size = Vector3.new(2, 4, 1.5),
		CFrame = cf * CFrame.new(9, 2, -2),
		Color = Color3.fromRGB(50, 50, 50),
		Material = Enum.Material.Metal,
		Parent = model,
	})
	local lamps = {}
	for i = 1, 3 do
		local lamp = part({
			Name = "Lamp" .. i,
			Size = Vector3.new(0.6, 0.6, 0.3),
			CFrame = cf * CFrame.new(8.3 + (i - 1) * 0.7, 3.6, -2.8),
			Color = Color3.fromRGB(40, 0, 0),
			Material = Enum.Material.Neon,
			Parent = model,
		})
		table.insert(lamps, lamp)
	end
	-- Коридор за воротами и зона побега
	part({
		Name = "Corridor",
		Size = Vector3.new(12, 1, 30),
		CFrame = cf * CFrame.new(0, -0.5, 15.75),
		Color = Color3.fromRGB(50, 45, 40),
		Material = Enum.Material.Ground,
		Parent = model,
	})
	wall(model, cf * CFrame.new(-6.75, 6, 15.75), Vector3.new(1.5, 12, 30))
	wall(model, cf * CFrame.new(6.75, 6, 15.75), Vector3.new(1.5, 12, 30))
	local escape = part({
		Name = "EscapeZone",
		Size = Vector3.new(12, 12, 10),
		CFrame = cf * CFrame.new(0, 6, 24),
		Transparency = 0.85,
		Color = Color3.fromRGB(255, 255, 255),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})
	local glow = Instance.new("PointLight")
	glow.Range = 40
	glow.Brightness = 2
	glow.Parent = escape

	model.PrimaryPart = switch
	model:SetAttribute("Kind", "ExitGate")
	model:SetAttribute("Powered", false)
	model:SetAttribute("Progress", 0)
	model:SetAttribute("Open", false)
	model.Parent = map.ExitGates
	return model, door
end

------------------------------------------------------------------------
-- Публичные функции
------------------------------------------------------------------------

function MapBuilder.BuildLobby()
	local existing = workspace:FindFirstChild("Lobby")
	if existing then
		return existing
	end
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	local pos = Config.LobbyPosition
	part({
		Name = "Floor",
		Size = Vector3.new(80, 2, 80),
		CFrame = CFrame.new(pos),
		Color = Color3.fromRGB(45, 40, 40),
		Material = Enum.Material.Slate,
		Parent = lobby,
	})
	for _, data in
		{
			{ Vector3.new(0, 10, 40), Vector3.new(80, 20, 2) },
			{ Vector3.new(0, 10, -40), Vector3.new(80, 20, 2) },
			{ Vector3.new(40, 10, 0), Vector3.new(2, 20, 80) },
			{ Vector3.new(-40, 10, 0), Vector3.new(2, 20, 80) },
		}
	do
		part({
			Name = "Wall",
			Size = data[2],
			CFrame = CFrame.new(pos + data[1]),
			Color = Color3.fromRGB(30, 25, 25),
			Material = Enum.Material.Brick,
			Parent = lobby,
		})
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(pos + Vector3.new(0, 1.5, 0))
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(120, 20, 20)
	spawn.Material = Enum.Material.Neon
	spawn.Parent = lobby

	local fire = part({
		Name = "Campfire",
		Size = Vector3.new(3, 1, 3),
		CFrame = CFrame.new(pos + Vector3.new(0, 1.5, 18)),
		Color = Color3.fromRGB(80, 50, 30),
		Material = Enum.Material.Wood,
		Parent = lobby,
	})
	Instance.new("Fire").Parent = fire
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 140, 60)
	light.Range = 40
	light.Brightness = 2
	light.Parent = fire

	lobby.Parent = workspace
	return lobby
end

function MapBuilder.SetupLighting()
	Lighting.ClockTime = 0.5
	Lighting.Brightness = 1
	Lighting.Ambient = Color3.fromRGB(45, 45, 60)
	Lighting.OutdoorAmbient = Color3.fromRGB(60, 60, 75)
	Lighting.FogColor = Color3.fromRGB(20, 22, 28)
	Lighting.FogStart = 20
	Lighting.FogEnd = 140
	Lighting.GlobalShadows = true
	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") or child:IsA("Sky") then
			child:Destroy()
		end
	end
	local cc = Lighting:FindFirstChild("DBDColor") or Instance.new("ColorCorrectionEffect")
	cc.Name = "DBDColor"
	cc.Saturation = -0.35
	cc.Contrast = 0.1
	cc.TintColor = Color3.fromRGB(220, 225, 255)
	cc.Parent = Lighting
end

-- Возвращает таблицу с папками и точками спавна
function MapBuilder.BuildMap()
	local old = workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end

	local rng = Random.new()
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
		GateDoors = {},
	}

	part({
		Name = "Ground",
		Size = Vector3.new(size + 4, 2, size + 4),
		CFrame = CFrame.new(0, -1, 0),
		Color = Color3.fromRGB(45, 55, 35),
		Material = Enum.Material.Grass,
		Parent = model,
	})

	-- Внешние стены с проёмами под ворота на севере и юге
	local wallH = 16
	local gateGap = 12
	local sideLen = (size - gateGap) / 2
	for _, side in { 1, -1 } do
		for _, dir in { 1, -1 } do
			wall(
				map.Walls,
				CFrame.new(dir * (gateGap / 2 + sideLen / 2), wallH / 2, side * half),
				Vector3.new(sideLen, wallH, 2)
			)
		end
		wall(map.Walls, CFrame.new(side * half, wallH / 2, 0), Vector3.new(2, wallH, size))
	end

	for i, side in { 1, -1 } do
		local _, door = buildExitGate(map, side, i)
		table.insert(map.GateDoors, door)
	end

	-- Сетка ячеек
	local n = math.floor(size / CELL)
	local cells = {}
	for ix = 1, n do
		for iz = 1, n do
			local cx = -half + CELL * (ix - 0.5)
			local cz = -half + CELL * (iz - 0.5)
			-- не ставим ничего прямо перед воротами
			local nearGate = math.abs(cx) < CELL and (iz == 1 or iz == n)
			if not nearGate then
				table.insert(cells, Vector3.new(cx, 0, cz))
			end
		end
	end
	shuffle(cells, rng)

	local idx = 0
	local function nextCell()
		idx += 1
		local c = cells[idx]
		local rot = rng:NextInteger(0, 3) * math.pi / 2
		return CFrame.new(c) * CFrame.Angles(0, rot, 0), c
	end

	for i = 1, Config.GeneratorCount do
		local cf = nextCell()
		buildGenerator(map.Generators, cf, i)
		-- немного укрытия рядом с генератором
		wall(map.Walls, cf * CFrame.new(0, 3, 6), Vector3.new(10, 6, 1.5))
	end
	for i = 1, 7 do
		local cf = nextCell()
		buildHook(map.Hooks, cf, i)
	end
	for _ = 1, 10 do
		buildPalletLoop(map, (nextCell()))
	end
	for _ = 1, 4 do
		buildWindowLoop(map, (nextCell()))
	end
	for _ = 1, 8 do
		buildRock(map, (nextCell()), rng)
	end
	for _ = 1, 8 do
		local cf = nextCell()
		buildTrees(map, cf, rng)
	end
	for _ = 1, 6 do
		local cf = nextCell()
		buildLamp(map, cf)
	end

	-- Оставшиеся пустые ячейки — для спавна
	local free = {}
	for i = idx + 1, #cells do
		table.insert(free, cells[i])
	end
	local survivorSpawn = free[1] or Vector3.new(0, 0, 0)
	local killerSpawn = survivorSpawn
	local best = -1
	for _, c in free do
		local d = (c - survivorSpawn).Magnitude
		if d > best then
			best = d
			killerSpawn = c
		end
	end
	map.SurvivorSpawn = survivorSpawn + Vector3.new(0, 3, 0)
	map.KillerSpawn = killerSpawn + Vector3.new(0, 3, 0)

	model.Parent = workspace
	return map
end

return MapBuilder
