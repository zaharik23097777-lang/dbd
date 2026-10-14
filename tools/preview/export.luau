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
--   poses [filter]                   — лист поз R6 (locomotion/state/action/oneshot), фильтр по заголовку
--   gait <пресет> [кадров]           — цикл походки: кадры + «стробоскоп» (стопа не должна скользить)
--   clip <OneShot> [кадров] [killer] — одноразовая анимация по кадрам
--     для поз: VIEWS=side,front — ракурсы, SPRING=1 — с пружинами суставов, как в игре
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
elseif MODE == "poses" or MODE == "gait" or MODE == "clip" then
	-- Позы R6. VIEWS (через запятую) переопределяет ракурсы; SPRING=1 — с пружинами суставов.
	local Rig = W:require(RS.Shared.Anim.Rig)
	local Poses = W:require(RS.Shared.Anim.Poses)
	local Clip = W:require(RS.Shared.Anim.Clip)
	local Driver = W:require(RS.Shared.Anim.Driver)
	local Color3 = roblox.Color3
	local envViews = process.env.VIEWS
	local useSpring = process.env.SPRING == "1"
	local function viewsOr(default)
		return (envViews and envViews ~= "") and nil or default
	end
	local ORDER = { "Root", "Neck", "LArm", "RArm", "LLeg", "RLeg" }

	-- Персонаж R6 с HumanoidRootPart в rootCF; tint — яркость (для «стробоскопа»)
	local function newChar(rootCF, killer, tint)
		local char = Fake.buildR6()
		char.HumanoidRootPart.CFrame = rootCF
		local k = tint or 1
		for _, part in char:GetChildren() do
			if part:IsA("BasePart") then
				-- левые конечности чуть холоднее правых, чтобы различать ноги в профиль
				local left = part.Name:match("^Left") ~= nil
				local c = part.Name == "Torso" and (killer and Color3.fromRGB(80, 38, 38) or Color3.fromRGB(60, 90, 130))
					or part.Name == "Head" and Color3.fromRGB(230, 190, 150)
					or (part.Name:match("Leg") and (left and Color3.fromRGB(40, 50, 75) or Color3.fromRGB(70, 52, 40)))
					or (left and Color3.fromRGB(200, 185, 170) or Color3.fromRGB(235, 185, 140))
				part.Color = Color3.new(c.R * k, c.G * k, c.B * k)
			end
		end
		char.Parent = W:service("Workspace")
		return char, Rig.find(char)
	end
	-- Детали по Motor6D.Transform (как движок)
	local function solveParts(rig)
		for _, name in ORDER do
			local joint = rig.Joints[name]
			local m = joint.Motor
			m.Part1.CFrame = m.Part0.CFrame * joint.C0 * m.Transform * joint.C1:Inverse()
		end
	end
	local function setPose(rig, pose)
		for _, name in ORDER do
			local joint = rig.Joints[name]
			local offset = name == "Root" and (pose.RootPos or V3.zero) or nil
			joint.Motor.Transform = Rig.transform(joint, pose[name] or CF.identity, offset)
		end
		solveParts(rig)
	end
	local function copyTransforms(from, to)
		for _, name in ORDER do
			to.Joints[name].Motor.Transform = from.Joints[name].Motor.Transform
		end
		solveParts(to)
	end
	local function box(cf, size, color, list)
		local part = Fake.Instance.new("Part")
		part.CFrame = cf
		part.Size = size
		part.Color = color
		part.Parent = W:service("Workspace")
		table.insert(list, part)
		return part
	end
	-- Земля (верх на y = 0)
	local function ground(list, width, depth, x, z)
		box(CF.new(x or 0, -0.05, z or 0), V3.new(width or 7, 0.1, depth or 7), Color3.fromRGB(70, 75, 60), list)
	end

	local function want(title)
		return not args[4] or title:lower():find(args[4]:lower(), 1, true)
	end
	local LOCO = {
		{ "idle", 0, {} },
		{ "walk", 10, {} },
		{ "run", 16, {} },
		{ "sprint", 22, {} },
		{ "injured idle", 0, { Injured = true } },
		{ "injured walk", 10, { Injured = true } },
		{ "injured run", 16, { Injured = true } },
		{ "crouch idle", 0, { Crouching = true } },
		{ "crouch walk", 5, { Crouching = true } },
		{ "killer idle", 0, { Killer = true } },
		{ "killer walk", 6, { Killer = true } },
		{ "killer stride", 16, { Killer = true } },
		{ "killer strafe", 16, { Killer = true, Forward = 0, Strafe = 1 } },
		{ "killer backpedal", 12, { Killer = true, Forward = -1 } },
		{ "wraith stride", 16, { Killer = true, KillerType = "Wraith" } },
		{ "killer carry", 14.3, { Killer = true, Carrying = true } },
		{ "run accelerating", 12, { AccelForward = 40 } },
		{ "run braking", 6, { AccelForward = -40 } },
		{ "run turning left", 16, { AccelSide = -45, TurnRate = 3 } },
	}
	local function params(spec)
		local p = { Speed = spec[2], Phase = 0, LookYaw = 0, Seed = 0.3, Breath = 0.7 }
		for k, v in spec[3] do
			p[k] = v
		end
		return p
	end
	local function findSpec(name)
		for _, spec in LOCO do
			if spec[1] == name then
				return spec
			end
		end
		error("нет пресета походки " .. tostring(name))
	end

	-- Пошаговая симуляция, как в Animator: поза -> пружины (60 кадров/с).
	-- poseAt(t, dt) -> поза, жёсткость; capture(i) — в моменты times[i].
	local function simulate(rig, poseAt, times, capture)
		local driver = Driver.new(rig)
		local dt = 1 / 60
		local t = 0
		local nextI = 1
		while nextI <= #times do
			local pose, stiff = poseAt(t, dt)
			Driver.apply(driver, pose, dt, stiff)
			while nextI <= #times and t + dt * 0.5 >= times[nextI] do
				capture(nextI)
				nextI += 1
			end
			t += dt
		end
	end

	local function single(title, pose, killer)
		local list = {}
		local char, rig = newChar(CF.new(0, 3, 0), killer)
		setPose(rig, pose)
		ground(list)
		table.insert(list, char)
		addScene(title, list, { views = viewsOr({ "side", "threequarter" }) })
	end

	if MODE == "poses" then
		for _, spec in LOCO do
			local title = "locomotion: " .. spec[1]
			if want(title) then
				local p = params(spec)
				p.Phase = 1.2
				single(title, Poses.locomotion(0.4, p), p.Killer)
			end
		end
		local stateParams = { Speed = 0, Phase = 1, Wiggle = 0.5, Seed = 0.3, Breath = 0.7, LookYaw = 0 }
		for name, fn in Poses.State do
			local title = "state: " .. name
			if want(title) then
				local list = {}
				local p = table.clone(stateParams)
				if name == "Carried" then
					-- на плече у маньяка (как Carry.startCarry)
					local kp = { Speed = 0, Phase = 1, Killer = true, Carrying = true, Seed = 0.6, Breath = 0.7 }
					local kchar, krig = newChar(CF.new(0, 3, 0), true)
					setPose(krig, Poses.locomotion(0.4, kp))
					table.insert(list, kchar)
					local scf = CF.new(0, 3, 0) * CF.new(1.4, 1.7, 0.6) * CF.Angles(math.rad(90), 0, 0) * CF.Angles(0, math.pi, 0)
					local char, rig = newChar(scf, false)
					setPose(rig, fn(0.4, p))
					table.insert(list, char)
					ground(list)
				elseif name == "Hooked" then
					-- упрощённый крюк (как Art/Props/Hook.lua); справа — борьба с Сущностью
					local red = Color3.fromRGB(95, 25, 20)
					for _, x in { 0, 6 } do
						box(CF.new(x, 6, 0), V3.new(0.9, 12, 0.9), red, list)
						box(CF.new(x, 11.4, -2), V3.new(0.7, 0.7, 4.4), red, list)
						box(CF.new(x, 10.2, -3.9), V3.new(0.3, 1.6, 0.3), Color3.fromRGB(80, 80, 80), list)
						box(CF.new(x, 8.8, -3.6), V3.new(0.3, 1.2, 0.3), Color3.fromRGB(150, 150, 150), list)
					end
					for i, struggle in { false, true } do
						local q = table.clone(p)
						q.Struggle = struggle
						local char, rig = newChar(CF.new(0.25 + (i - 1) * 6, 7, -4.3), false)
						setPose(rig, fn(0.4, q))
						table.insert(list, char)
					end
					ground(list, 14, 10, 3, -3)
				else
					if name == "Sit" then
						box(CF.new(0, 0.75, 0.2), V3.new(3, 1.5, 1.4), Color3.fromRGB(90, 60, 40), list)
					elseif name == "Crawl" then
						p.Speed = 2.5
					end
					local char, rig = newChar(CF.new(0, 3, 0), false)
					setPose(rig, fn(0.4, p))
					table.insert(list, char)
					ground(list)
				end
				addScene(title, list, { views = viewsOr({ "side", "threequarter" }) })
			end
		end
		local base = params(findSpec("idle"))
		for name, fn in Poses.Action do
			local title = "action: " .. name
			if want(title) then
				single(title, Clip.layer(Clip.copy(Poses.locomotion(0.4, base), {}), fn(0.4, base), 1), false)
			end
		end
		for name, shot in Poses.OneShot do
			for _, a in { 0.15, 0.4, 0.7 } do
				local title = ("oneshot: %s @%.2f"):format(name, a)
				if want(title) then
					local pose = Clip.copy(Poses.locomotion(0.4, base), {})
					single(title, Clip.layer(pose, shot.Fn(a, base), Clip.weight(shot, a * shot.Duration), shot.Additive), false)
				end
			end
		end
	elseif MODE == "gait" then
		-- Цикл походки: кадры по фазе + «стробоскоп» — все кадры со смещением тела на пройденный
		-- путь, опорная стопа должна стоять на месте. gait <пресет> [кадров]
		local spec = findSpec(args[4] or "walk")
		local frames = tonumber(args[5]) or 8
		local p = params(spec)
		local v = p.Speed
		local rate = Poses.stepRate(v, p.Crouching, p)
		local period = rate > 0 and (2 * math.pi / rate) or 2
		local phases, times = {}, {}
		for i = 1, frames do
			phases[i] = (i - 1) / frames * 2 * math.pi
			times[i] = period * 2 + (i - 1) / frames * period
		end
		local dirX, dirZ = (p.Strafe or 0), -(p.Forward or 1)
		local _, simRig = newChar(CF.new(100, 3, 0), p.Killer)
		local strobe, tiles = {}, {}
		local function emit(i)
			local list = {}
			local travel = v * (i - 1) / frames * period
			for k, rootCF in { CF.new(0, 3, 0), CF.new(dirX * travel, 3, dirZ * travel) } do
				local char, rig = newChar(rootCF, p.Killer, k == 1 and 1 or 0.55 + 0.45 * i / frames)
				if useSpring then
					copyTransforms(simRig, rig)
				else
					local q = table.clone(p)
					q.Phase = phases[i]
					setPose(rig, Poses.locomotion(times[i], q))
				end
				table.insert(k == 1 and list or strobe, char)
			end
			ground(list)
			tiles[i] = list
		end
		if useSpring then
			local phase = 0
			simulate(simRig, function(t, dt)
				phase += Poses.stepRate(v, p.Crouching, p) * dt
				local q = table.clone(p)
				q.Phase = phase
				return Poses.locomotion(t, q), 1
			end, times, emit)
		else
			for i = 1, frames do
				emit(i)
			end
		end
		local span = v * period
		ground(strobe, 6 + span * math.abs(dirX), 6 + span * math.abs(dirZ), dirX * span / 2, dirZ * span / 2)
		local head = ("gait %s v=%.1f, %.2f шаг/с%s"):format(spec[1], v, rate / math.pi, useSpring and ", пружины" or "")
		addScene(head .. " — стробоскоп", strobe, { views = viewsOr({ "side" }) })
		for i, list in tiles do
			addScene(("%s φ=%.0f°"):format(spec[1], math.deg(phases[i])), list, { views = viewsOr({ "side" }) })
		end
	elseif MODE == "clip" then
		-- Одноразовая анимация по кадрам поверх стояния: clip <Имя> [кадров] [killer]
		local name = args[4]
		local shot = Poses.OneShot[name]
		assert(shot, "нет Poses.OneShot." .. tostring(name))
		local frames = math.max(2, tonumber(args[5]) or 8)
		local p = params(findSpec(args[6] == "killer" and "killer idle" or "idle"))
		local lead = useSpring and 0.5 or 0 -- с пружинами: полсекунды стояния перед клипом
		local times = {}
		for i = 1, frames do
			times[i] = lead + (i - 1) / (frames - 1) * shot.Duration
		end
		local function poseAt(t)
			local pose = Clip.copy(Poses.locomotion(t, p), {})
			local e = t - lead
			if e < 0 then
				return pose, 1
			end
			local w = Clip.weight(shot, e)
			Clip.layer(pose, shot.Fn(math.clamp(e / shot.Duration, 0, 1), p), w, shot.Additive)
			return pose, 1 + ((shot.Stiffness or 1) - 1) * w
		end
		local _, simRig = newChar(CF.new(100, 3, 0), p.Killer)
		local function emit(i)
			local list = {}
			local char, rig = newChar(CF.new(0, 3, 0), p.Killer)
			if useSpring then
				copyTransforms(simRig, rig)
			else
				setPose(rig, (poseAt(times[i])))
			end
			table.insert(list, char)
			ground(list)
			local e = times[i] - lead
			addScene(("%s t=%.2f вес %.2f%s"):format(name, e, Clip.weight(shot, e), useSpring and " (пружины)" or ""), list, { views = viewsOr({ "side", "threequarter" }) })
		end
		if useSpring then
			simulate(simRig, poseAt, times, emit)
		else
			for i = 1, frames do
				emit(i)
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
