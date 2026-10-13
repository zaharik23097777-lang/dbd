local Harness = require("./harness")
local process = require("@lune/process")
local Vector3 = require("@lune/roblox").Vector3

local game, req = Harness.load(process.args[1] or "DeadByDaylight.rbxlx")
local MapBuilder = req(game.ServerScriptService.Server.Map.MapBuilder)
local Config = req(game.ReplicatedStorage.Shared.Config)

local failures = 0
local function check(cond, msg)
	if not cond then
		failures += 1
		print("FAIL: " .. msg)
	end
end

local function count(folder, kind)
	local n = 0
	for _, c in folder:GetChildren() do
		if c:GetAttribute("Kind") == kind then
			n += 1
		end
	end
	return n
end

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
	local hex = 0
	for _, t in map.Totems:GetChildren() do
		if t:GetAttribute("Hex") then
			hex += 1
		end
	end
	check(hex == 1, "exactly one hex totem seed " .. seed)
	check((map.SurvivorSpawn - map.KillerSpawn).Magnitude > 60, "spawns far apart seed " .. seed)
	-- Ключевые объекты не должны стоять друг на друге
	local keys = {}
	for _, f in { map.Generators, map.Hooks, map.Totems, map.Chests, map.Lockers } do
		for _, m in f:GetChildren() do
			table.insert(keys, { m.Name, m.PrimaryPart.CFrame.Position })
		end
	end
	for i = 1, #keys do
		for j = i + 1, #keys do
			local d = (keys[i][2] - keys[j][2]) * Vector3.new(1, 0, 1)
			check(d.Magnitude > 2.5, ("overlap %s / %s seed %d"):format(keys[i][1], keys[j][1], seed))
		end
	end
end

local lobby = MapBuilder.BuildLobby()
check(lobby ~= nil, "lobby")
MapBuilder.SetupLighting()

local parts = 0
for _, d in game.Workspace.Map:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	end
end
print(("map parts: %d"):format(parts))
if failures > 0 then
	print(("%d checks failed"):format(failures))
	process.exit(1)
end
print("map tests OK")
