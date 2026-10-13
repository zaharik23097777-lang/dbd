--!nocheck
-- Звук в эмуляторе: выбор найденных в библиотеке звуков, порядок источников
-- (свой ID > библиотека > синтез), работа без сети, проверка загрузки на клиенте,
-- петли «по требованию», предел одновременных звуков и уборка, все имена звуков из кода.
local Fake = require("./fakeroblox")
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local PLACE = process.args[1] or "DeadByDaylight.rbxlx"
local Sched = Fake.Sched
local V3 = Fake.Vector3
local Enum = roblox.Enum

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
		for _, e in Sched.Errors do
			print("  " .. e)
		end
		failures += #Sched.Errors
		table.clear(Sched.Errors)
	end
end

local function newWorld()
	local W = Fake.newWorld(PLACE)
	return W, W:service("ReplicatedStorage"), W:service("ServerScriptService")
end

-- Все звуки (Sound) мира
local function allSounds(W)
	local out = {}
	for _, root in { W:service("SoundService"), W:service("Workspace") } do
		for _, d in root:GetDescendants() do
			if d._class == "Sound" then
				table.insert(out, d)
			end
		end
	end
	return out
end

local function soundsNamed(W, name, looped)
	local out = {}
	for _, s in allSounds(W) do
		if s.Name == name and (looped == nil or (s.Looped == true) == looped) then
			table.insert(out, s)
		end
	end
	return out
end

------------------------------------------------------------------------
print("== Слоты и имена звуков в коде")
do
	local W, RS = newWorld()
	local Sounds = W:require(RS.Shared.Sounds)
	local BUILTIN = {}
	for _, f in {
		"action_footsteps_plastic.mp3",
		"action_jump.mp3",
		"action_jump_land.mp3",
		"action_falling.ogg",
		"action_swim.mp3",
		"impact_water.mp3",
		"action_get_up.mp3",
		"uuhhh.mp3",
	} do
		BUILTIN["rbxasset://sounds/" .. f] = true
	end
	local GROUPS = { SFX = true, Ambience = true, Music = true, Voice = true, UI = true }
	local count = 0
	for _, def in Sounds.List do
		count += 1
		check(Sounds.Defs[def.Name] == def, def.Name .. " in Defs")
		check(def.Name ~= "Status" and def.Name ~= "Version", "slot name clashes with folder attribute: " .. def.Name)
		check(GROUPS[def.Group], def.Name .. " has a mix group: " .. tostring(def.Group))
		check(def.Search and #def.Search.Keywords > 0, def.Name .. " has search keywords")
		if def.Search and def.Search.Min and def.Search.Max then
			check(def.Search.Min < def.Search.Max, def.Name .. " duration range")
		end
		check(def.Synth or def.Melody or def.Name == "AmbientMusic", def.Name .. " has an offline synth fallback")
		for _, layer in def.Synth or (def.Melody and { def.Melody.Layer }) or {} do
			check(BUILTIN[layer.Id], def.Name .. " synth uses a built-in sound: " .. tostring(layer.Id))
			check(layer.Speed > 0 and layer.Volume > 0, def.Name .. " layer speed/volume")
		end
	end
	check(count >= 45, "enough sound slots: " .. count)

	-- Каждое имя звука, которое встречается в коде, есть в Sounds.Defs
	local used = 0
	local function scan(dir)
		for _, entry in fs.readDir(dir) do
			local path = dir .. "/" .. entry
			if fs.isDir(path) then
				scan(path)
			elseif path:match("%.lua$") then
				local src = fs.readFile(path)
				for _, pattern in {
					'State%.sfx%(%s*"([%w_]+)"',
					'State%.sfxTo%([^,]+,%s*"([%w_]+)"',
					'Audio%.play%(%s*"([%w_]+)"',
					'want%(%s*"([%w_]+)"',
				} do
					for name in src:gmatch(pattern) do
						used += 1
						check(Sounds.Defs[name] ~= nil, path .. ": unknown sound " .. name)
					end
				end
			end
		end
	end
	scan("src")
	check(used >= 40, "sound usages found in code: " .. used)
	errorsOk("defs")
end

------------------------------------------------------------------------
print("== Выбор лучшего результата поиска")
do
	local W, RS, SSS = newWorld()
	local SoundLibrary = W:require(SSS.Server.Core.SoundLibrary)
	local spec = { Keywords = { "footstep dirt" }, Min = 0.1, Max = 1.2, Count = 2 }
	local results = {
		{ Id = 101, Title = "Footstep dirt long walk", Duration = 6 }, -- слишком длинный
		{ Id = 102, Title = "Footstep dirt", Duration = 0.5 },
		{ Id = 103, Title = "dirt step", Duration = 0.4, IsEndorsed = true }, -- одобрен Roblox
		{ Id = 104, Title = "footstep dirt meme", Duration = 0.5 }, -- плохое слово
		{ Title = "no id", Duration = 0.5 },
		{ Id = 105, Title = "Footstep dirt short", Duration = 0.05 }, -- слишком короткий
		"garbage",
	}
	local picked = SoundLibrary.pick(results, spec, "footstep dirt", 2)
	check(#picked == 2, "picked 2: " .. #picked)
	check(picked[1] and picked[1].Id == "rbxassetid://103", "endorsed result preferred")
	check(picked[2] and picked[2].Id == "rbxassetid://102", "duration limits and bad words respected")

	-- Другие названия полей
	local c = SoundLibrary.readResult({ AssetId = "rbxassetid://201", Name = "Bell toll", duration = 3 }, 1)
	check(c and c.Id == "rbxassetid://201" and c.Title == "Bell toll" and c.Duration == 3, "alternative field names")
	check(SoundLibrary.readResult({ id = "202" }, 1).Id == "rbxassetid://202", "numeric string id")
	check(SoundLibrary.readResult({ Id = 0 }, 1) == nil, "zero id rejected")

	-- Загруженный самим Roblox выше обычного
	local bells = SoundLibrary.pick({
		{ Id = 302, Title = "church bell", Duration = 2 },
		{ Id = 301, Title = "bell", Duration = 2, Creator = { Id = 1, Name = "Roblox" } },
	}, { Keywords = { "church bell" }, Min = 1, Max = 8 }, "church bell", 1)
	check(bells[1] and bells[1].Id == "rbxassetid://301", "Roblox-made result preferred")

	-- Плохие слова ищутся с начала слова
	local roof = SoundLibrary.pick({ { Id = 501, Title = "rain on roof", Duration = 2 } }, { Keywords = { "x" }, Max = 4 }, "x", 1)
	check(#roof == 1, "'oof' does not reject 'roof'")
	local walks = SoundLibrary.pick({ { Id = 502, Title = "footsteps walking", Duration = 1 } }, { Keywords = { "x" }, Max = 4, Avoid = { "walk" } }, "x", 1)
	check(#walks == 0, "avoid words match word starts")

	-- Музыке не мешает слово «music», звукам — мешает
	local sfx = SoundLibrary.pick({ { Id = 401, Title = "scary music", Duration = 2 } }, { Keywords = { "x" }, Max = 4 }, "x", 1)
	check(#sfx == 0, "music titles skipped for sound effects")
	local music = SoundLibrary.pick({ { Id = 402, Title = "scary music", Duration = 60 } }, { Keywords = { "x" }, Music = true }, "x", 1)
	check(#music == 1, "music titles allowed for music")
	errorsOk("pick")
end

------------------------------------------------------------------------
print("== Поиск на сервере (заглушка SearchAudioAsync)")
do
	local W, RS, SSS = newWorld()
	local Sounds = W:require(RS.Shared.Sounds)
	local Config = W:require(RS.Shared.Config)
	Config.SoundOverrides.Bell = "rbxassetid://999" -- свой ID: этот слот не ищем
	local calls, keywords = 0, {}
	local nextId = 1000
	W.AudioSearch = function(params)
		calls += 1
		keywords[params.SearchKeyword] = true
		check(params.AudioSubType ~= nil, "AudioSubType set")
		local lo, hi = params.MinDuration or 0, params.MaxDuration or 600
		local page = {}
		for i = 1, 5 do
			nextId += 1
			page[i] = { Id = nextId, Title = params.SearchKeyword .. " " .. i, Duration = (lo + hi) / 2, IsEndorsed = i == 3 }
		end
		return {
			GetCurrentPage = function()
				return page
			end,
		}
	end
	local SoundLibrary = W:require(SSS.Server.Core.SoundLibrary)
	SoundLibrary.start()
	SoundLibrary.start() -- второй вызов ничего не делает
	W:step(60, 0.25)
	errorsOk("search")
	local folder = RS:FindFirstChild(Sounds.LibraryFolder)
	check(folder ~= nil, "SoundLibrary folder published")
	check(folder and folder:GetAttribute("Status") == "Ready", "status Ready: " .. tostring(folder and folder:GetAttribute("Status")))
	check(folder and (folder:GetAttribute("Version") or 0) > 40, "version grows with each publish")
	local missing = 0
	for _, def in Sounds.List do
		local ids = Sounds.parseIds(folder and folder:GetAttribute(def.Name))
		if def.Name == "Bell" then
			check(#ids == 0, "overridden slot not searched")
		elseif #ids == 0 then
			missing += 1
			print("  not found: " .. def.Name)
		else
			check(#ids == (def.Search.Count or 1), def.Name .. " variants: " .. #ids)
			check(ids[1]:match("^rbxassetid://%d+$"), def.Name .. " id format")
		end
	end
	check(missing == 0, "all slots found")
	check(not keywords["church bell"], "override skips search")
	local footsteps = Sounds.parseIds(folder:GetAttribute("FootstepDirt"))
	check(#footsteps == 4, "4 footstep variants")
	-- Одинаковый запрос второй раз не отправляется
	local before = calls
	local ok = SoundLibrary.query("heartbeat", Sounds.Defs.Heartbeat.Search, math.huge)
	check(ok and calls == before, "queries cached per server")
end

------------------------------------------------------------------------
print("== Без сети: всё на встроенных звуках")
do
	local W, RS, SSS = newWorld()
	local Sounds = W:require(RS.Shared.Sounds)
	local SoundLibrary = W:require(SSS.Server.Core.SoundLibrary)
	SoundLibrary.start() -- W.AudioSearch нет: SearchAudioAsync бросает ошибку
	W:step(40, 0.25)
	errorsOk("offline")
	local folder = RS:FindFirstChild(Sounds.LibraryFolder)
	check(folder and folder:GetAttribute("Status") == "Offline", "status Offline: " .. tostring(folder and folder:GetAttribute("Status")))
	for _, def in Sounds.List do
		check(folder:GetAttribute(def.Name) == nil, "nothing published offline: " .. def.Name)
		local r = Sounds.get(def.Name)
		if def.Name == "AmbientMusic" then
			check(r == nil, "AmbientMusic silent offline")
		else
			check(r and r.Source == "Synth", def.Name .. " falls back to synth")
		end
	end
end

------------------------------------------------------------------------
print("== Порядок источников: свой ID > библиотека > синтез")
do
	local W, RS = newWorld()
	local Sounds = W:require(RS.Shared.Sounds)
	local Config = W:require(RS.Shared.Config)
	check(Sounds.get("Bell").Source == "Synth", "synth by default")
	check(Sounds.get("NoSuchSound") == nil, "unknown slot")
	Config.SoundOverrides.Bell = { "rbxassetid://7", "rbxassetid://8" }
	Sounds.setLibrary("Bell", { "rbxassetid://5" })
	local r = Sounds.get("Bell")
	check(r.Source == "Override" and #r.Variants == 2 and r.Variants[1][1].Id == "rbxassetid://7", "override first")
	Sounds.markFailed("rbxassetid://7")
	check(#Sounds.get("Bell").Variants == 1, "failed override variant dropped")
	Sounds.markFailed("rbxassetid://8")
	r = Sounds.get("Bell")
	check(r.Source == "Library" and r.Variants[1][1].Id == "rbxassetid://5", "library second")
	Sounds.markFailed("rbxassetid://5")
	check(Sounds.get("Bell").Source == "Synth", "synth last")
	local parsed = Sounds.parseIds({ 123, "456", "rbxassetid://7,rbxassetid://8" })
	check(#parsed == 4 and parsed[1] == "rbxassetid://123" and parsed[2] == "rbxassetid://456" and parsed[4] == "rbxassetid://8", "override id formats")
	local steps = Sounds.get("Footstep")
	check(#steps.Variants == 4, "synth footstep variants")
	check(steps.Variants[1][1].Speed ~= steps.Variants[4][1].Speed, "synth variants differ in pitch")
end

------------------------------------------------------------------------
print("== Клиент: проверка загрузки, петли, шаги, предел звуков")
do
	local W, RS, SSS = newWorld()
	local Sounds = W:require(RS.Shared.Sounds)
	local Config = W:require(RS.Shared.Config)
	local SoundLibrary = W:require(SSS.Server.Core.SoundLibrary)
	local folder = SoundLibrary.folder()
	W.FailedAssets = { ["rbxassetid://22"] = true, ["rbxassetid://31"] = true }
	local function publish(name, ids)
		folder:SetAttribute(name, ids)
		folder:SetAttribute("Version", (folder:GetAttribute("Version") or 0) + 1)
	end

	local Players = W:service("Players")
	local me = W:addPlayer("Alice", 2)
	local gui = Fake.Instance.new("PlayerGui")
	gui.Name = "PlayerGui"
	gui.Parent = me
	local screen = Fake.Instance.new("ScreenGui")
	screen.Parent = gui
	local button = Fake.Instance.new("TextButton")
	button.Parent = screen
	Players.LocalPlayer = me
	W.LocalPlayer = me
	local Audio = W:require(W:service("StarterPlayer").StarterPlayerScripts.Client.Audio)
	W:service("RunService").RenderStepped:Connect(function(dt)
		Audio.update(dt)
	end)
	errorsOk("client start")

	for _, name in { "Master", "SFX", "Ambience", "Music", "Voice", "UI" } do
		check(Audio.Groups[name] and Audio.Groups[name]._class == "SoundGroup", "sound group " .. name)
	end
	check(Audio.Groups.SFX.Parent == Audio.Groups.Master, "groups nested under Master")
	for _, def in Sounds.List do
		check(Audio.Groups[def.Group] ~= nil, def.Name .. " group exists on client")
	end

	-- Атмосфера лобби на синтезе
	W:step(1)
	errorsOk("lobby")
	local wind = soundsNamed(W, "Wind", true)
	check(#wind == 2 and wind[1].SoundId == "rbxasset://sounds/action_falling.ogg", "synth wind loop (2 layers)")
	check(wind[1] and wind[1].SoundGroup == Audio.Groups.Ambience, "wind in Ambience group")
	check(wind[1] and wind[1].IsPlaying, "wind playing")
	check(#soundsNamed(W, "AmbientMusic") == 0, "no lobby music without library")
	button.Activated:Fire()
	check(#soundsNamed(W, "UiClick") == 1, "button click sound")
	RS.Remotes.Sfx.OnClientEvent:Fire("Clank", V3.new(3, 0, 0))
	check(#soundsNamed(W, "Clank") == 1, "server sfx played")
	check(soundsNamed(W, "Clank")[1].Parent.Name == "SfxPoint", "sfx at a world point")

	-- Сервер нашёл звуки: клиент проверяет загрузку
	publish("Wind", "rbxassetid://11")
	publish("FootstepDirt", "rbxassetid://21,rbxassetid://22")
	publish("Heartbeat", "rbxassetid://31")
	publish("FootstepWood", "rbxassetid://51,rbxassetid://52,rbxassetid://53")
	publish("AmbientMusic", "rbxassetid://61")
	W:step(3)
	errorsOk("verify")
	check(Sounds.get("Wind").Source == "Library", "wind from library")
	wind = soundsNamed(W, "Wind", true)
	check(#wind == 1 and wind[1].SoundId == "rbxassetid://11", "wind loop rebuilt with library sound")
	local dirt = Sounds.get("FootstepDirt")
	check(dirt.Source == "Library" and #dirt.Variants == 1 and dirt.Variants[1][1].Id == "rbxassetid://21", "failed variant dropped")
	check(Sounds.Failed["rbxassetid://22"] and Sounds.Failed["rbxassetid://31"], "failed ids remembered")
	check(Sounds.get("Heartbeat").Source == "Synth", "failed heartbeat falls back to synth")
	check(#soundsNamed(W, "AmbientMusic", true) == 1, "lobby music from library")
	check(#soundsNamed(W, "Preload") == 0, "preload probes removed")

	-- Звук прошёл проверку, но потом не загрузился: слот уходит на синтез
	publish("Bell", "rbxassetid://41")
	W:step(2)
	check(Sounds.get("Bell").Source == "Library", "bell from library")
	W.FailedAssets["rbxassetid://41"] = true
	Audio.play("Bell")
	W:step(Config.SoundLoadTimeout + 1)
	errorsOk("watchdog")
	check(Sounds.get("Bell").Source == "Synth", "bell falls back after load timeout")

	-- Шаги по материалу пола, без повторов подряд
	check(Audio.surface(Enum.Material.Grass) == "FootstepDirt", "grass -> dirt")
	check(Audio.surface(Enum.Material.LeafyGrass) == "FootstepDirt", "leafy grass -> dirt")
	check(Audio.surface(Enum.Material.WoodPlanks) == "FootstepWood", "planks -> wood")
	check(Audio.surface(Enum.Material.DiamondPlate) == "FootstepMetal", "plate -> metal")
	check(Audio.surface(Enum.Material.CorrodedMetal) == "FootstepMetal", "corroded -> metal")
	check(Audio.surface(Enum.Material.Cobblestone) == "FootstepStone", "cobblestone -> stone")
	check(Audio.surface(Enum.Material.Plastic) == "Footstep", "plastic -> generic")
	for _, m in Enum.Material:GetEnumItems() do
		check(Sounds.Defs[Audio.surface(m)] ~= nil, "surface slot exists for " .. m.Name)
	end
	local char = Fake.buildR6()
	char.Parent = W:service("Workspace")
	char.Humanoid.FloorMaterial = Enum.Material.Mud
	Audio.footstep(char, false, 16, false)
	check(#soundsNamed(W, "FootstepDirt") == 1, "dirt step on mud")
	check(soundsNamed(W, "FootstepDirt")[1].Parent == char.HumanoidRootPart, "step sound on root")
	Audio.footstep(char, true, 16, false)
	check(#soundsNamed(W, "KillerFootstep") == 2, "killer heavy step layer (synth, 2 layers)")
	local last, repeats, used = nil, 0, {}
	for _ = 1, 30 do
		local s = Audio.play("FootstepWood", V3.new(2, 0, 0))
		if s then
			if s.SoundId == last then
				repeats += 1
			end
			last = s.SoundId
			used[s.SoundId] = true
		end
	end
	check(repeats == 0, "no immediate footstep repeats")
	check(used["rbxassetid://51"] and used["rbxassetid://52"] and used["rbxassetid://53"], "all footstep variants used")
	check(Audio.play("Footstep", V3.new(500, 0, 0)) == nil, "far one-shot culled")

	-- Предел одновременных звуков, важные вытесняют шаги
	for _ = 1, 100 do
		Audio.play("Footstep", V3.new(1, 0, 1))
	end
	local oneShots = 0
	for _, s in allSounds(W) do
		if not s.Looped then
			oneShots += 1
		end
	end
	check(oneShots <= Config.MaxSounds, "one-shots capped: " .. oneShots)
	check(Audio.play("Scream", V3.new(1, 0, 1)) ~= nil, "scream evicts a footstep")
	W:step(20)
	errorsOk("cleanup")
	local left, points = 0, 0
	for _, s in allSounds(W) do
		if not s.Looped and s.Name ~= "Thunder" then -- гром случаен по времени
			left += 1
		end
	end
	for _, d in W:service("Workspace").Terrain:GetChildren() do
		if d.Name == "SfxPoint" then
			points += 1
		end
	end
	check(left == 0, "one-shots cleaned up: " .. left)
	check(points == 0, "temporary sound points cleaned up: " .. points)

	-- Матч: радиус ужаса, сердце, погоня с приглушением атмосферы
	local killer = W:addPlayer("Killer", 1)
	local kchar = Fake.buildR6()
	kchar.Parent = W:service("Workspace")
	killer.Character = kchar
	killer:SetAttribute("Role", "Killer")
	killer:SetAttribute("Status", "Playing")
	killer:SetAttribute("KillerType", "Trapper")
	killer:SetAttribute("TerrorRadius", 32)
	kchar:PivotTo(Fake.CFrame.new(10, 0, 0))
	local mychar = Fake.buildR6()
	mychar.Parent = W:service("Workspace")
	me.Character = mychar
	me:SetAttribute("Role", "Survivor")
	me:SetAttribute("Status", "Playing")
	me:SetAttribute("Health", 2)
	W:step(3)
	errorsOk("terror")
	check(Audio.terrorIntensity() > 0.5, "terror intensity near killer")
	check(#soundsNamed(W, "TerrorDrone", true) == 2, "terror drone loop")
	check(#soundsNamed(W, "Heartbeat") > 0, "heartbeat beats")
	check(#soundsNamed(W, "KillerBreath", true) == 1, "killer breathing nearby")
	local ambience = Audio.Groups.Ambience.Volume
	me:SetAttribute("Chase", true)
	W:step(2)
	check(#soundsNamed(W, "ChaseMusic", true) == 3, "chase music loop (synth, 3 layers)")
	check(Audio.Groups.Ambience.Volume < ambience * 0.6, "ambience ducked in chase")
	me:SetAttribute("Chase", false)
	W:step(5)
	check(#soundsNamed(W, "ChaseMusic") == 0, "chase music removed after fade-out")
	check(#soundsNamed(W, "AmbientMusic") == 0, "lobby music off in match")

	-- Из шкафчика всё звучит глухо
	me:SetAttribute("Hidden", true)
	W:step(1)
	check(Audio.Groups.SFX:FindFirstChildOfClass("EqualizerSoundEffect").HighGain < -10, "muffled while hidden")
	me:SetAttribute("Hidden", false)

	-- Раненый дышит, лишний звук пропадает, когда его не нужно
	me:SetAttribute("Health", 1)
	W:step(1)
	check(#soundsNamed(W, "BreathInjured", true) == 1, "injured breathing")
	me:SetAttribute("Health", 2)
	W:step(3)
	check(#soundsNamed(W, "BreathInjured") == 0, "breathing stops when healed")

	-- Охотница: колыбельная вместо гула и сердца (синтез — ноты мелодии)
	killer:SetAttribute("KillerType", "Huntress")
	killer:SetAttribute("TerrorRadius", 22)
	W:step(4)
	check(#soundsNamed(W, "Lullaby", false) > 0, "lullaby melody notes")
	check(#soundsNamed(W, "TerrorDrone") == 0, "no drone with lullaby")
	errorsOk("match")
end

if failures > 0 then
	print(failures .. " audio test failures")
	process.exit(1)
end
print("audio tests OK")
