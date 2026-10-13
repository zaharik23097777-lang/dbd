--!nocheck
-- Экспорт сцен в JSON для рендера превью (tools/preview/render.py).
-- Запуск: lune run tools/preview/export.luau <place.rbxlx> <out.json> <mode> [args...]
--   template <Name|all> [variant]   — шаблон(ы) объекта карты
--   structure <function> [seed]     — постройка из Art/Structures (ячейка 22x22)
--   nature <function> [seed]        — природа из Art/Nature
--   killer <Trapper|Huntress|Wraith> — маньяк R6 со снаряжением
--   item <Medkit|Toolbox|Flashlight> — выживший R6 с предметом
--   hatchet                          — топор Охотницы
--   lobby                            — лобби
--   map [seed]                       — вся карта сверху
--   poses [filter]                   — лист поз R6 (locomotion/state/action/oneshot)
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local Fake = require("../../tests/fakeroblox")

local args = process.args
local PLACE, OUT, MODE = args[1], args[2], args[3]
assert(PLACE and OUT and MODE, "usage: export.luau <place> <out.json> <mode> [args]")

local W = Fake.newWorld(PLACE)
W.Strict = true
local CF, V3 = Fake.CFrame, Fake.Vector3
local SSS = W:service("ServerScriptService")
local RS = W:service("ReplicatedStorage")
local Enum = roblox.Enum

W:require(SSS.Server.Core.Characters)

------------------------------------------------------------------------

local function cfList(cf)
	local c = { cf:GetComponents() }
	return c
end

local function colorList(c)
	return { c.R, c.G, c.B }
end

local function shapeOf(part)
	local cls = part._class
	if cls == "WedgePart" then
		return "Wedge"
	elseif cls == "CornerWedgePart" then
		return "CornerWedge"
	end
	local shape = part.Shape
	if shape == Enum.PartType.Ball then
		return "Ball"
	elseif shape == Enum.PartType.Cylinder then
		return "Cylinder"
	end
	return "Block"
end

local function exportParts(root, extra)
	local prims = {}
	local roots = type(root) == "table" and not Fake.isFake[root] and root or { root }
	for _, r in roots do
		local list = r:GetDescendants()
		if r:IsA("BasePart") then
			table.insert(list, r)
		end
		for _, p in list do
			if p:IsA("BasePart") then
				local t = p.Transparency or 0
				if t < 0.95 then
					table.insert(prims, {
						shape = shapeOf(p),
						cf = cfList(p.CFrame),
						size = { p.Size.X, p.Size.Y, p.Size.Z },
						color = colorList(p.Color or roblox.Color3.new(0.6, 0.6, 0.6)),
						material = tostring(p.Material or Enum.Material.Plastic):gsub("^Enum%.Material%.", ""),
						transparency = t,
						name = p.Name,
					})
				end
			end
		end
	end
	return prims
end

local function exportTerrain()
	local out = {}
	for _, f in W.TerrainFills or {} do
		local a = f.Args
		if f.Kind == "Block" then
			local mat = tostring(a[3]):gsub("^Enum%.Material%.", "")
			if mat ~= "Air" then
				table.insert(out, { shape = "Block", cf = cfList(a[1]), size = { a[2].X, a[2].Y, a[2].Z }, material = mat })
			end
		elseif f.Kind == "Ball" then
			local mat = tostring(a[3]):gsub("^Enum%.Material%.", "")
			table.insert(out, { shape = "Ball", cf = cfList(CF.new(a[1])), size = { a[2] * 2, a[2] * 2, a[2] * 2 }, material = mat })
		elseif f.Kind == "Cylinder" then
			local mat = tostring(a[4]):gsub("^Enum%.Material%.", "")
			-- FillCylinder: ось Y, height, radius -> наш цилиндр по оси X повернём
			local cf = a[1] * CF.Angles(0, 0, math.rad(90))
			table.insert(out, { shape = "Cylinder", cf = cfList(cf), size = { a[2], a[3] * 2, a[3] * 2 }, material = mat })
		end
	end
	return out
end

local function count(root)
	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

local scenes = {}
local function addScene(title, root, opts)
	opts = opts or {}
	table.insert(scenes, {
		title = title,
		parts = exportParts(root),
		terrain = opts.terrain and exportTerrain() or {},
		count = Fake.isFake[root] and count(root) or nil,
		views = opts.views,
		ground = opts.ground ~= false,
	})
end

local function newMap()
	local model = Fake.Instance.new("Model")
	model.Name = "Map"
	local map = { Model = model, TrapSpots = {}, CrowSpots = {}, ChestSpots = {}, TotemSpots = {} }
	for _, n in { "Walls", "Decor", "Generators", "Hooks", "Pallets", "Windows", "ExitGates", "Lockers", "Totems", "Chests", "Traps", "Crows", "Effects" } do
		local f = Fake.Instance.new("Folder")
		f.Name = n
		f.Parent = model
		map[n] = f
	end
	model.Parent = W:service("Workspace")
	return map
end

------------------------------------------------------------------------

if MODE == "template" then
	local Templates = W:require(SSS.Server.Map.Art.Templates)
	local names = args[4] == "all" and Templates.names() or { args[4] }
	for _, name in names do
		local variants = Templates.build(name)
		local which = tonumber(args[5])
		for v, model in variants do
			if not which or which == v then
				addScene(("%s #%d (%d деталей)"):format(name, v, count(model)), model)
			end
		end
	end
elseif MODE == "structure" or MODE == "nature" then
	local mod = W:require(MODE == "structure" and SSS.Server.Map.Art.Structures or SSS.Server.Map.Art.Nature)
	local fnName = args[4]
	local seed = tonumber(args[5]) or 1
	local fn = mod[fnName]
	assert(fn, "нет функции " .. tostring(fnName))
	local map = newMap()
	fn(map, CF.identity, Random and Random.new(seed) or W:env().Random.new(seed))
	addScene(("%s.%s (%d деталей)"):format(MODE, fnName, count(map.Model)), map.Model)
elseif MODE == "killer" or MODE == "item" then
	local Characters = W:require(SSS.Server.Core.Characters)
	local player = W:addPlayer("Preview", 1)
	local char
	if MODE == "killer" then
		char = Characters.build(player, "Killer", args[4])
	else
		char = Characters.build(player, "Survivor", nil)
		local ItemArt = W:require(SSS.Server.Map.Art.Items)
		local arm = char:FindFirstChild("Right Arm")
		ItemArt.held(args[4], arm).Parent = char
	end
	char:PivotTo(CF.new(0, 3, 0))
	char.Parent = W:service("Workspace")
	addScene(("%s %s (%d деталей)"):format(MODE, args[4] or "", count(char)), char, { views = { "front", "threequarter", "side", "back" } })
elseif MODE == "hatchet" then
	local Hatchet = W:require(RS.Shared.Art.Hatchet)
	local m = Hatchet.build()
	m.Parent = W:service("Workspace")
	addScene(("hatchet (%d деталей)"):format(count(m)), m, { ground = false })
elseif MODE == "lobby" then
	local MapBuilder = W:require(SSS.Server.Map.MapBuilder)
	local lobby = MapBuilder.BuildLobby()
	addScene(("lobby (%d деталей)"):format(count(lobby)), lobby, { terrain = true, views = { "top", "threequarter" } })
elseif MODE == "map" then
	local MapBuilder = W:require(SSS.Server.Map.MapBuilder)
	local map = MapBuilder.BuildMap((tonumber(args[4]) or 1) * 7919)
	addScene(("map (%d деталей)"):format(count(map.Model)), map.Model, { terrain = true, views = { "top", "threequarter" } })
elseif MODE == "poses" then
	local Rig = W:require(RS.Shared.Anim.Rig)
	local Poses = W:require(RS.Shared.Anim.Poses)
	local filter = args[4]
	local function poseScene(title, pose, killer)
		local char = Fake.buildR6()
		local hrp = char.HumanoidRootPart
		hrp.CFrame = CF.new(0, 3, 0)
		local rig = Rig.find(char)
		local order = { "Root", "Neck", "LArm", "RArm", "LLeg", "RLeg" }
		for _, name in order do
			local joint = rig.Joints[name]
			local rot = pose[name] or CF.identity
			local offset = name == "Root" and (pose.RootPos or V3.zero) or nil
			local t = Rig.transform(joint, rot, offset)
			local m = joint.Motor
			m.Part1.CFrame = m.Part0.CFrame * joint.C0 * t * joint.C1:Inverse()
		end
		for _, p in char:GetChildren() do
			if p:IsA("BasePart") then
				p.Color = p.Name == "Torso" and (killer and roblox.Color3.fromRGB(70, 40, 40) or roblox.Color3.fromRGB(60, 90, 130))
					or p.Name == "Head" and roblox.Color3.fromRGB(230, 190, 150)
					or (p.Name:match("Leg") and roblox.Color3.fromRGB(50, 50, 60) or roblox.Color3.fromRGB(230, 190, 150))
			end
		end
		char.Parent = W:service("Workspace")
		addScene(title, char, { views = { "side", "threequarter" } })
	end
	local params = { Speed = 0, Phase = 0, LookYaw = 0 }
	local function want(name)
		return not filter or name:lower():find(filter:lower(), 1, true)
	end
	for _, spec in {
		{ "idle", 0, 0, {} },
		{ "walk", 10, 1.2, {} },
		{ "run", 16, 1.2, {} },
		{ "injured run", 16, 1.2, { Injured = true } },
		{ "crouch walk", 5, 1.2, { Crouching = true } },
		{ "killer walk", 18, 1.2, { Killer = true } },
		{ "killer carry", 16, 1.2, { Killer = true, Carrying = true } },
	} do
		if want(spec[1]) then
			local p = table.clone(params)
			p.Speed, p.Phase = spec[2], spec[3]
			for k, v in spec[4] do
				p[k] = v
			end
			poseScene("locomotion: " .. spec[1], Poses.locomotion(0.4, p), p.Killer)
		end
	end
	for name, fn in Poses.State do
		if want(name) then
			poseScene("state: " .. name, fn(0.4, { Speed = 2, Phase = 1, Wiggle = 0.5, Struggle = name == "Hooked" }), false)
		end
	end
	for name, fn in Poses.Action do
		if want(name) then
			poseScene("action: " .. name, Poses.merge(Poses.locomotion(0.4, params), fn(0.4, params)), false)
		end
	end
	for name, shot in Poses.OneShot do
		if want(name) then
			for _, a in { 0.15, 0.4, 0.7 } do
				poseScene(("oneshot: %s @%.2f"):format(name, a), Poses.merge(Poses.locomotion(0.4, params), shot.Fn(a, params)), false)
			end
		end
	end
else
	error("неизвестный режим " .. MODE)
end

if #Fake.Sched.Errors > 0 then
	for _, e in Fake.Sched.Errors do
		print("ERROR: " .. e)
	end
end

fs.writeFile(OUT, serde.encode("json", { scenes = scenes }))
print(("exported %d scene(s) -> %s"):format(#scenes, OUT))
