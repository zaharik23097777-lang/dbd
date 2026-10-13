--!nocheck
-- Карта и шаблоны в строгом эмуляторе: свойства проверяются по базе Roblox, шаблоны — по контракту.
local Fake = require("./fakeroblox")
local process = require("@lune/process")

local W = Fake.newWorld(process.args[1] or "DeadByDaylight.rbxlx")
W.Strict = true
local V3 = Fake.Vector3
local CFrame = Fake.CFrame
local SSS = W:service("ServerScriptService")
local RS = W:service("ReplicatedStorage")
local Sched = Fake.Sched

local failures = 0
local function check(cond, msg)
	if not cond then
		failures += 1
		print("FAIL: " .. msg)
	end
end
local function errorsOk(stage)
	if #Sched.Errors > 0 then
		print("ERRORS during " .. stage .. ":")
		local seen = {}
		for _, e in Sched.Errors do
			if not seen[e] then
				seen[e] = true
				print("  " .. e)
			end
		end
		failures += #Sched.Errors
		table.clear(Sched.Errors)
	end
end

local Characters = W:require(SSS.Server.Core.Characters) -- регистрирует группы столкновений
local _ = Characters
local Templates = W:require(SSS.Server.Map.Art.Templates)
local Contract = W:require(SSS.Server.Map.Art.Contract)
local PropFX = W:require(SSS.Server.Map.PropFX)
local MapBuilder = W:require(SSS.Server.Map.MapBuilder)
local Config = W:require(RS.Shared.Config)
errorsOk("require")

-- 1. Каждый шаблон: контракт, бюджет, опора в начале координат, подвижные группы работают
for _, name in Templates.names() do
	for v, model in Templates.build(name) do
		for _, e in Contract.check(name, model) do
			check(false, e .. " (вариант " .. v .. ")")
		end
		local pivot = model:GetPivot()
		check(pivot.Position.Magnitude < 0.01, name .. ": опора не в начале координат: " .. tostring(pivot.Position))
		-- все группы: 0 -> 1 -> 0 возвращает детали на место
		local groups = {}
		for _, d in model:GetDescendants() do
			local g = d:GetAttribute("FX")
			if g then
				groups[g] = true
			end
		end
		for g in groups do
			local before = {}
			for _, p in PropFX.parts(model, g) do
				before[p] = p.CFrame
			end
			PropFX.setGroup(model, g, 1)
			PropFX.setGroup(model, g, 0)
			for p, cf in before do
				check((p.CFrame.Position - cf.Position).Magnitude < 1e-3, name .. ": группа " .. g .. " не возвращается в CF0")
			end
		end
	end
end
errorsOk("templates")

-- 2. Копия шаблона встаёт на землю там, где сказали
local probe = Templates.spawn("Generator", CFrame.new(50, 0, 50) * CFrame.Angles(0, math.rad(90), 0), W:service("Workspace"))
check((probe:GetPivot().Position - V3.new(50, 0, 50)).Magnitude < 1e-3, "spawn pivot")
check(probe.PrimaryPart.Position.Y > 0.5, "generator body above ground")
PropFX.genProgress(probe, 0.6)
PropFX.genDone(probe)
PropFX.genExplode(probe)
probe:Destroy()
errorsOk("propfx")

-- 3. Карта на 20 сидах
local function count(folder, kind)
	local n = 0
	for _, c in folder:GetChildren() do
		if c:GetAttribute("Kind") == kind then
			n += 1
		end
	end
	return n
end
local maxParts = 0
for seed = 1, 20 do
	local map = MapBuilder.BuildMap(seed * 7919)
	check(count(map.Generators, "Generator") == Config.GeneratorCount, "generators seed " .. seed)
	check(count(map.Hooks, "Hook") == 8, "hooks seed " .. seed)
	check(count(map.Pallets, "Pallet") == 10, "pallets seed " .. seed .. " = " .. count(map.Pallets, "Pallet"))
	check(count(map.Lockers, "Locker") == 7, "lockers seed " .. seed .. " = " .. count(map.Lockers, "Locker"))
	check(count(map.Totems, "Totem") == 5, "totems seed " .. seed)
	check(count(map.Chests, "Chest") == 5, "chests seed " .. seed)
	check(count(map.ExitGates, "ExitGate") == 2, "gates seed " .. seed)
	check(#map.Windows:GetChildren() >= 8, "windows seed " .. seed .. " = " .. #map.Windows:GetChildren())
	check(map.Hatch ~= nil and map.Hatch:GetAttribute("Kind") == "Hatch", "hatch seed " .. seed)
	check(#map.TrapSpots >= 10, "trap spots seed " .. seed)
	check(#map.CrowSpots >= 8, "crow spots seed " .. seed)
	for _, p in map.Pallets:GetChildren() do
		check(typeof(p:GetAttribute("DropCFrame")) == "CFrame", "pallet DropCFrame")
	end
	local hex = 0
	for _, t in map.Totems:GetChildren() do
		if t:GetAttribute("Hex") then
			hex += 1
		end
	end
	check(hex == 1, "exactly one hex totem seed " .. seed)
	check((map.SurvivorSpawn - map.KillerSpawn).Magnitude > 60, "spawns far apart seed " .. seed)
	local keys = {}
	for _, f in { map.Generators, map.Hooks, map.Totems, map.Chests, map.Lockers } do
		for _, m in f:GetChildren() do
			table.insert(keys, { m.Name, m:GetPivot().Position })
		end
	end
	for i = 1, #keys do
		for j = i + 1, #keys do
			local d = (keys[i][2] - keys[j][2]) * V3.new(1, 0, 1)
			check(d.Magnitude > 2.5, ("overlap %s / %s seed %d"):format(keys[i][1], keys[j][1], seed))
		end
	end
	local parts = 0
	for _, d in map.Model:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	maxParts = math.max(maxParts, parts)
	check(#(W.TerrainFills or {}) > 10, "terrain filled")
	errorsOk("map seed " .. seed)
end
check(maxParts <= 6500, "map part budget: " .. maxParts)

MapBuilder.SetupLighting()
local lobby = MapBuilder.BuildLobby()
check(lobby ~= nil, "lobby")
local seats = 0
for _, d in lobby:GetDescendants() do
	if d:IsA("Seat") then
		seats += 1
		check(d.CollisionGroup == "DBDSeats", "seat collision group")
	end
end
check(seats >= 4, "lobby seats")
errorsOk("lobby")

print(("max map parts: %d"):format(maxParts))
if failures > 0 then
	print(("%d checks failed"):format(failures))
	process.exit(1)
end
print("map tests OK")
