-- Звук на клиенте.
--  * Микшер: SoundGroup Master -> SFX / Ambience / Music / Voice / UI с эквалайзером, ревербом
--    и компрессором; приглушение атмосферы в погоне, «глухой» звук из шкафчика.
--  * Одноразовые звуки (Audio.play): варианты без повторов подряд, разброс высоты и громкости,
--    отсев слишком далёких, предел одновременных звуков (на телефоне меньше), уборка за собой.
--  * Петли «по требованию» (want): существуют, только пока нужны в этом кадре, плавно
--    появляются и затухают — атмосфера, радиус ужаса, погоня, генераторы, дыхание, костёр.
--  * Найденные сервером звуки библиотеки сначала проверяются (ContentProvider:PreloadAsync,
--    IsLoaded); не загрузился — слот навсегда переходит на встроенный синтез.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Util = require(ReplicatedStorage.Shared.Util)
local KillerDefs = require(ReplicatedStorage.Shared.KillerDefs)

local player = Players.LocalPlayer
local Audio = {}

local MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local MAX_SOUNDS = if MOBILE then Config.MaxSoundsMobile else Config.MaxSounds

------------------------------------------------------------------------
-- Микшер
------------------------------------------------------------------------

-- Группы и их эффекты (свойства эффектов Roblox). Громкости — Config.SoundGroupVolumes.
-- Реверберация леса — в группах (SoundService.AmbientReverb выключен), поэтому музыка и интерфейс сухие.
local MIX = {
	{
		Name = "Master",
		Compressor = { Threshold = -16, Ratio = 3, Attack = 0.005, Release = 0.25, GainMakeup = 2 },
		-- Динамики телефона не тянут низы: убираем гул, поднимаем середину
		Equalizer = if MOBILE then { LowGain = -5, MidGain = 2, HighGain = 0 } else nil,
	},
	{
		Name = "SFX",
		Parent = "Master",
		Equalizer = { LowGain = 1, MidGain = 0, HighGain = 0 },
		Reverb = { DecayTime = 1.8, Density = 0.7, Diffusion = 0.8, DryLevel = 0, WetLevel = -12 },
	},
	{
		Name = "Ambience",
		Parent = "Master",
		Equalizer = { LowGain = -2, MidGain = -3, HighGain = -4 },
		Reverb = { DecayTime = 3, Density = 1, Diffusion = 1, DryLevel = 0, WetLevel = -14 },
	},
	{
		Name = "Music",
		Parent = "Master",
		Equalizer = { LowGain = 0, MidGain = -2, HighGain = -1 },
		Compressor = { Threshold = -20, Ratio = 2, Attack = 0.02, Release = 0.4, GainMakeup = 0 },
	},
	{
		Name = "Voice",
		Parent = "Master",
		Equalizer = { LowGain = -3, MidGain = 2, HighGain = 0 },
		Reverb = { DecayTime = 1.4, Density = 0.8, Diffusion = 0.8, DryLevel = 0, WetLevel = -16 },
	},
	{ Name = "UI", Parent = "Master" },
} :: { { [string]: any } }

-- Группы, которые глушатся, когда выживший в шкафчике (музыка и сердце — «в голове», их не глушим)
local MUFFLED = { SFX = true, Ambience = true, Voice = true }

Audio.Groups = {} :: { [string]: SoundGroup }
local groupEq: { [string]: EqualizerSoundEffect } = {}
local baseHighGain: { [string]: number } = {}

for _, spec in MIX do
	local parent: Instance = if spec.Parent then Audio.Groups[spec.Parent] else SoundService
	local group = parent:FindFirstChild(spec.Name) :: SoundGroup?
	if not (group and group:IsA("SoundGroup")) then
		local g = Instance.new("SoundGroup")
		g.Name = spec.Name
		for _, class in { "Equalizer", "Compressor", "Reverb" } do
			local props = spec[class]
			if props then
				local effect = Instance.new(class .. "SoundEffect") :: any
				for k, v in props do
					effect[k] = v
				end
				effect.Parent = g
			end
		end
		g.Parent = parent
		group = g
	end
	local g = group :: SoundGroup
	g.Volume = Config.SoundGroupVolumes[spec.Name] or 1
	Audio.Groups[spec.Name] = g
	local eq = g:FindFirstChildOfClass("EqualizerSoundEffect")
	if eq then
		groupEq[spec.Name] = eq
		baseHighGain[spec.Name] = eq.HighGain
	end
end

------------------------------------------------------------------------
-- Создание звуков
------------------------------------------------------------------------

local function addEffects(sound: Sound, fx: Sounds.Effects?)
	if not fx then
		return
	end
	if fx.Distortion then
		local d = Instance.new("DistortionSoundEffect")
		d.Level = fx.Distortion
		d.Parent = sound
	end
	if fx.Echo then
		local e = Instance.new("EchoSoundEffect")
		e.Delay = fx.Echo[1]
		e.Feedback = fx.Echo[2]
		e.WetLevel = -6
		e.Parent = sound
	end
	if fx.LowPass or fx.HighPass then
		local cut = fx.LowPass or 0
		local eq = Instance.new("EqualizerSoundEffect")
		eq.HighGain = -cut
		eq.MidGain = -cut * 0.3
		eq.LowGain = (if fx.LowPass then 3 else 0) - (fx.HighPass or 0)
		eq.Parent = sound
	end
	if fx.Tremolo then
		local t = Instance.new("TremoloSoundEffect")
		t.Frequency = fx.Tremolo[1]
		t.Depth = fx.Tremolo[2]
		t.Duty = fx.Tremolo[3] or 0.5
		t.Parent = sound
	end
	if fx.Reverb then
		local r = Instance.new("ReverbSoundEffect")
		r.DecayTime = fx.Reverb[1]
		r.WetLevel = fx.Reverb[2]
		r.Parent = sound
	end
	if fx.Octave then
		local p = Instance.new("PitchShiftSoundEffect")
		p.Octave = fx.Octave
		p.Parent = sound
	end
end

local function newSound(layer: Sounds.Layer, def: Sounds.Def, parent: Instance, looped: boolean): Sound
	local s = Instance.new("Sound")
	s.Name = def.Name
	s.SoundId = layer.Id
	s.Looped = looped
	s.PlaybackSpeed = layer.Speed
	if layer.Start then
		s.TimePosition = layer.Start
	end
	s.SoundGroup = Audio.Groups[def.Group]
	if def.MaxDistance then
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = def.MinDistance or 6
		s.RollOffMaxDistance = def.MaxDistance
	end
	addEffects(s, layer.Effects)
	s.Parent = parent
	return s
end

local function listenerPosition(): Vector3
	local cam = workspace.CurrentCamera
	return if cam then cam.CFrame.Position else Vector3.zero
end

local function near(pos: Vector3, range: number): boolean
	return (pos - listenerPosition()).Magnitude <= range
end

-- Где звучит: деталь/вложение (звук едет вместе с ней) или точка в мире
local function locate(where: any): (Instance?, Vector3?)
	if typeof(where) == "Vector3" then
		return nil, where
	elseif typeof(where) ~= "Instance" then
		return nil, nil
	end
	local inst: Instance? = where
	if (where :: Instance):IsA("Model") then
		local m = where :: Model
		inst = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
	end
	if inst and inst:IsA("BasePart") then
		return inst, (inst :: BasePart).Position
	elseif inst and inst:IsA("Attachment") then
		return inst, (inst :: Attachment).WorldPosition
	end
	return nil, nil
end

------------------------------------------------------------------------
-- Проверка загрузки найденных звуков
------------------------------------------------------------------------

type Loop = {
	Name: string,
	Where: Instance?,
	Resolved: Sounds.Resolved,
	Sounds: { Sound },
	Base: { number }, -- громкость слоя
	Speeds: { number }, -- скорость слоя
	Gain: number,
	Target: number,
	Speed: number,
	Seen: number,
	Clock: number, -- мелодия: время до следующей ноты
	Note: number,
}
local loops: { [string]: { [Instance]: Loop } } = {}
local refreshLoops: () -> ()

-- Первый запуск каждого ID библиотеки: если звук так и не загрузился — больше его не берём
local watched: { [string]: boolean } = {}
local function watchLoad(s: Sound)
	local id = s.SoundId
	if watched[id] then
		return
	end
	watched[id] = true
	task.delay(Config.SoundLoadTimeout, function()
		if s.IsLoaded then
			return
		end
		if s.Parent == nil then
			watched[id] = nil -- звук убран раньше, чем успел загрузиться: проверим в следующий раз
			return
		end
		Sounds.markFailed(id)
		refreshLoops()
	end)
end

type Job = { Name: string, Ids: { string }, Library: boolean }
local jobs: { Job } = {}
local verified: { [string]: boolean } = {}
local workers = 0

-- Загружает ID слота через PreloadAsync и ждёт результата не дольше SoundLoadTimeout
local function verify(job: Job)
	local def = Sounds.Defs[job.Name]
	local timeout = Config.SoundLoadTimeout * (if def and def.Group == "Music" then 3 else 1) -- музыка длинная
	local probes: { [string]: Sound } = {}
	local status: { [string]: Enum.AssetFetchStatus } = {}
	local list = {}
	for _, id in job.Ids do
		if verified[id] == nil and not probes[id] then
			local probe = Instance.new("Sound")
			probe.Name = "Preload"
			probe.SoundId = id
			probe.Volume = 0
			probe.Parent = SoundService
			probes[id] = probe
			table.insert(list, probe)
		end
	end
	if #list > 0 then
		task.spawn(function()
			pcall(function()
				ContentProvider:PreloadAsync(list, function(contentId: string, fetch: Enum.AssetFetchStatus)
					local digits = contentId:match("%d+$")
					for id in probes do
						if id == contentId or (digits and id:match("%d+$") == digits) then
							status[id] = fetch
						end
					end
				end)
			end)
		end)
		local t0 = os.clock()
		while os.clock() - t0 < timeout do
			local pending = false
			for id, probe in probes do
				if status[id] == nil and not probe.IsLoaded then
					pending = true
				end
			end
			if not pending then
				break
			end
			task.wait(0.25)
		end
		for id, probe in probes do
			local fetch = status[id]
			local ok = if fetch then fetch == Enum.AssetFetchStatus.Success else probe.IsLoaded
			verified[id] = ok
			if not ok then
				Sounds.markFailed(id)
			end
			probe:Destroy()
		end
	end
	if job.Library then
		local good = {}
		for _, id in job.Ids do
			if verified[id] then
				table.insert(good, id)
			end
		end
		Sounds.setLibrary(job.Name, good)
	end
	refreshLoops()
end

local function pumpJobs()
	while workers < 3 and #jobs > 0 do
		workers += 1
		task.spawn(function()
			while #jobs > 0 do
				verify(table.remove(jobs, 1) :: Job)
			end
			workers -= 1
		end)
	end
end

-- Свои ID из Config тоже проверяем: не загрузились — библиотека или синтез
for _, def in Sounds.List do
	local ids = Sounds.parseIds(Config.SoundOverrides[def.Name])
	if #ids > 0 then
		table.insert(jobs, { Name = def.Name, Ids = ids, Library = false })
	end
end

-- Сервер публикует найденное постепенно: следим за версией папки
local libVersion: any = nil
local seenRaw: { [string]: string } = {}
local function syncLibrary()
	local folder = ReplicatedStorage:FindFirstChild(Sounds.LibraryFolder)
	if not folder then
		return
	end
	local version = folder:GetAttribute("Version")
	if version == libVersion then
		return
	end
	libVersion = version
	for _, def in Sounds.List do
		local raw = folder:GetAttribute(def.Name)
		if type(raw) == "string" and raw ~= seenRaw[def.Name] then
			seenRaw[def.Name] = raw
			table.insert(jobs, { Name = def.Name, Ids = Sounds.parseIds(raw), Library = true })
		end
	end
	pumpJobs()
end

------------------------------------------------------------------------
-- Одноразовые звуки
------------------------------------------------------------------------

type Voice = { Sound: Sound, Priority: number, Born: number }
local active: { Voice } = {}
local lastVariant: { [string]: number } = {}

-- Убирает звук и временную точку, на которой он висел
local function release(s: Sound)
	local holder = s.Parent
	s:Destroy()
	if holder and holder.Name == "SfxPoint" and #holder:GetChildren() == 0 then
		holder:Destroy()
	end
end

local function fadeOut(s: Sound, time: number)
	local tw = TweenService:Create(s, TweenInfo.new(time), { Volume = 0 })
	tw.Completed:Connect(function()
		release(s)
	end)
	tw:Play()
end

-- Освобождает место под need звуков приоритета priority; false — новый звук не нужен
local function makeRoom(priority: number, need: number): boolean
	for i = #active, 1, -1 do
		if active[i].Sound.Parent == nil then
			table.remove(active, i)
		end
	end
	while #active + need > MAX_SOUNDS do
		local victim = 0
		for i, v in active do
			local w = active[victim]
			if victim == 0 or v.Priority < w.Priority or (v.Priority == w.Priority and v.Born < w.Born) then
				victim = i
			end
		end
		if victim == 0 or active[victim].Priority > priority then
			return false
		end
		release((table.remove(active, victim) :: Voice).Sound)
	end
	return true
end

local function pickVariant(r: Sounds.Resolved): { Sounds.Layer }
	local n = #r.Variants
	if n <= 1 then
		return r.Variants[1]
	end
	-- Без повторов подряд
	local last = lastVariant[r.Name]
	local k = math.random(1, if last then n - 1 else n)
	if last and k >= last then
		k += 1
	end
	lastVariant[r.Name] = k
	return r.Variants[k]
end

local function spawnLayers(r: Sounds.Resolved, layers: { Sounds.Layer }, where: any, volume: number, speed: number): Sound?
	local def = r.Def
	local anchor, pos = nil, nil
	if def.MaxDistance then
		anchor, pos = locate(where)
		if pos and not near(pos, def.MaxDistance) then
			return nil -- всё равно не слышно
		end
	end
	local priority = def.Priority or 2
	if not makeRoom(priority, #layers) then
		return nil
	end
	local parent: Instance = anchor or SoundService
	if pos and not anchor then
		local att = Instance.new("Attachment")
		att.Name = "SfxPoint"
		att.Parent = workspace.Terrain
		att.WorldPosition = pos
		parent = att
	end
	local life = math.max(12, def.Search and def.Search.Max or 0)
	local first: Sound? = nil
	for _, layer in layers do
		local s = newSound(layer, def, parent, false)
		s.Volume = layer.Volume * volume
		s.PlaybackSpeed = layer.Speed * speed
		table.insert(active, { Sound = s, Priority = priority, Born = os.clock() })
		local delay = layer.Delay or 0
		if delay > 0 then
			task.delay(delay, function()
				if s.Parent then
					s:Play()
				end
			end)
		else
			s:Play()
		end
		s.Ended:Connect(function()
			release(s)
		end)
		local cut = layer.Duration or def.Duration
		if cut then
			task.delay(delay + cut, function()
				if s.Parent then
					fadeOut(s, 0.12)
				end
			end)
		end
		task.delay(delay + (cut or life) + 0.5, function()
			if s.Parent then
				release(s)
			end
		end)
		first = first or s
	end
	if r.Source ~= "Synth" and first then
		watchLoad(first)
	end
	return first
end

-- Проиграть звук слота. where: BasePart / Model / Attachment / Vector3 / nil (2D)
function Audio.play(name: string, where: any?, volumeScale: number?, speedScale: number?): Sound?
	local r = Sounds.get(name)
	if not r then
		return nil
	end
	local def = r.Def
	local volume = def.Volume * (volumeScale or 1) * (1 + (math.random() * 2 - 1) * (def.Jitter or 0))
	local speed = (speedScale or 1) * (1 + (math.random() * 2 - 1) * (def.Pitch or 0))
	return spawnLayers(r, pickVariant(r), where, volume, speed)
end

Remotes.Sfx.OnClientEvent:Connect(function(name, where)
	Audio.play(name, where)
end)

Remotes.Notify.OnClientEvent:Connect(function()
	Audio.play("Notify")
end)

Remotes.Effect.OnClientEvent:Connect(function(name)
	if name == "Intro" then
		Audio.play("EntityDrone")
	end
end)

------------------------------------------------------------------------
-- Петли по требованию
------------------------------------------------------------------------

local frame = 0

local function clearLoop(e: Loop)
	for _, s in e.Sounds do
		s:Destroy()
	end
	table.clear(e.Sounds)
	table.clear(e.Base)
	table.clear(e.Speeds)
end

local function buildLoop(e: Loop)
	clearLoop(e)
	local r = e.Resolved
	if r.Source == "Synth" and r.Def.Melody then
		return -- синтез мелодии играется отдельными нотами
	end
	local layers = r.Variants[math.random(1, #r.Variants)]
	for _, layer in layers do
		local s = newSound(layer, r.Def, e.Where or SoundService, true)
		s.Volume = 0
		table.insert(e.Sounds, s)
		table.insert(e.Base, layer.Volume * r.Def.Volume)
		table.insert(e.Speeds, layer.Speed)
	end
	if r.Source ~= "Synth" and e.Sounds[1] then
		watchLoad(e.Sounds[1])
	end
end

-- Источник слота сменился (библиотека проверена или звук не загрузился): пересобираем петли
refreshLoops = function()
	for _, byKey in loops do
		for key, e in byKey do
			local r = Sounds.get(e.Name)
			if not r then
				clearLoop(e)
				byKey[key] = nil
			elseif r ~= e.Resolved then
				e.Resolved = r
				buildLoop(e)
			end
		end
	end
end

-- Петля нужна в этом кадре. where — деталь (nil = 2D), gain — громкость 0..1
local function want(name: string, where: Instance?, gain: number, speed: number?)
	local byKey = loops[name]
	if not byKey then
		byKey = {}
		loops[name] = byKey
	end
	local key: Instance = where or SoundService
	local e: Loop? = byKey[key]
	if not e then
		local r = Sounds.get(name)
		if gain <= 0 or not r then
			return
		end
		local created: Loop = {
			Name = name,
			Where = where,
			Resolved = r,
			Sounds = {},
			Base = {},
			Speeds = {},
			Gain = 0,
			Target = 0,
			Speed = 1,
			Seen = 0,
			Clock = 0,
			Note = 0,
		}
		buildLoop(created)
		byKey[key] = created
		e = created
	end
	local loop = e :: Loop
	loop.Target = math.clamp(gain, 0, 1)
	loop.Speed = speed or 1
	loop.Seen = frame
end

local function tickMelody(e: Loop, dt: number)
	local melody = e.Resolved.Def.Melody :: Sounds.Melody
	e.Clock -= dt
	if e.Clock > 0 then
		return
	end
	e.Clock += melody.Step
	e.Note = e.Note % #melody.Notes + 1
	local note = melody.Notes[e.Note]
	if note then
		spawnLayers(e.Resolved, { melody.Layer }, e.Where, e.Gain * e.Resolved.Def.Volume, e.Speed * 2 ^ (note / 12))
	end
end

local function updateLoops(dt: number)
	for _, byKey in loops do
		for key, e in byKey do
			if e.Seen ~= frame or (e.Where and e.Where.Parent == nil) then
				e.Target = 0
			end
			local def = e.Resolved.Def
			if e.Target > e.Gain then
				e.Gain = math.min(e.Target, e.Gain + dt / (def.FadeIn or 0.5))
			else
				e.Gain = math.max(e.Target, e.Gain - dt / (def.FadeOut or 1))
			end
			if e.Gain <= 0 then
				clearLoop(e)
				byKey[key] = nil
				continue
			end
			for i, s in e.Sounds do
				s.Volume = e.Base[i] * e.Gain
				s.PlaybackSpeed = e.Speeds[i] * e.Speed
				if not s.Playing then
					s:Play()
				end
			end
			if #e.Sounds == 0 and def.Melody then
				tickMelody(e, dt)
			end
		end
	end
end

------------------------------------------------------------------------
-- Шаги (вызывает Animator в такт шагам)
------------------------------------------------------------------------

-- Материал пола (имя Enum.Material) -> слот шага
local SURFACE: { [string]: string } = {
	Grass = "FootstepDirt",
	LeafyGrass = "FootstepDirt",
	Ground = "FootstepDirt",
	Mud = "FootstepDirt",
	Sand = "FootstepDirt",
	Snow = "FootstepDirt",
	Pebble = "FootstepDirt",
	Wood = "FootstepWood",
	WoodPlanks = "FootstepWood",
	Metal = "FootstepMetal",
	DiamondPlate = "FootstepMetal",
	CorrodedMetal = "FootstepMetal",
	Concrete = "FootstepStone",
	Brick = "FootstepStone",
	Slate = "FootstepStone",
	Rock = "FootstepStone",
	Cobblestone = "FootstepStone",
	Pavement = "FootstepStone",
	Asphalt = "FootstepStone",
	Granite = "FootstepStone",
	Marble = "FootstepStone",
	Basalt = "FootstepStone",
	Limestone = "FootstepStone",
	Sandstone = "FootstepStone",
}

-- Слот шага для материала пола
function Audio.surface(material: Enum.Material): string
	return SURFACE[material.Name] or "Footstep"
end

-- Материал пола под персонажем. У чужих персонажей на клиенте Humanoid.FloorMaterial бывает Air
-- (их физику считает не этот клиент), поэтому тогда смотрим лучом вниз. nil — персонаж в воздухе.
local floorParams = RaycastParams.new()
floorParams.FilterType = Enum.RaycastFilterType.Exclude
function Audio.floorMaterial(char: Model): Enum.Material?
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum and hum.FloorMaterial ~= Enum.Material.Air then
		return hum.FloorMaterial
	end
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	floorParams.FilterDescendantsInstances = { char }
	-- R6: центр корня на 3 стада над землёй (у масштабированного маньяка — больше), плюс запас
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -(root.Size.Y * 1.5 + 1.5), 0), floorParams)
	return if hit then (hit.Material or Enum.Material.Plastic) else nil
end

function Audio.footstep(char: Model, isKiller: boolean, speed: number, crouching: boolean)
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local floor = Audio.floorMaterial(char)
	local slot = if floor then Audio.surface(floor) else "Footstep"
	local vol = if crouching then 0.35 else math.clamp(speed / 16, 0.45, 1.1)
	if isKiller and char == player.Character then
		vol *= 0.6 -- свои шаги маньяк слышит у самой камеры
	end
	if isKiller then
		-- Маньяк: тот же пол, но ниже и громче, плюс тяжёлый удар сапога
		Audio.play(slot, root, vol * 1.15, 0.85)
		Audio.play("KillerFootstep", root, vol)
	else
		Audio.play(slot, root, vol)
	end
end

------------------------------------------------------------------------
-- Радиус ужаса
------------------------------------------------------------------------

local function findKiller(): Player?
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("Role") == "Killer" then
			return p
		end
	end
	return nil
end

-- Близость маньяка для локального выжившего: 0 — вне радиуса (радиус × scale), 1 — вплотную
local function killerProximity(killer: Player?, scale: number): number
	if not killer or player:GetAttribute("Role") ~= "Survivor" or not Util.isInGameStatus(player:GetAttribute("Status")) then
		return 0
	end
	local kroot = Util.getRoot(killer)
	local myRoot = Util.getRoot(player)
	local tr = (tonumber(killer:GetAttribute("TerrorRadius")) or 32) * scale
	if not kroot or not myRoot or tr <= 0 then
		return 0
	end
	return math.clamp(1 - Util.flatDist(kroot.Position, myRoot.Position) / tr, 0, 1)
end

-- Сила радиуса ужаса для локального выжившего (0..1)
function Audio.terrorIntensity(): number
	return killerProximity(findKiller(), 1)
end

------------------------------------------------------------------------
-- Щелчки кнопок интерфейса
------------------------------------------------------------------------

local hooked: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function hookButton(inst: Instance)
	-- Кнопку, перенесённую внутри PlayerGui, второй раз не подключаем (иначе щелчок двойной)
	if not inst:IsA("GuiButton") or hooked[inst] then
		return
	end
	-- Экранные кнопки управления (прыжок, действия) не щёлкают
	if inst:FindFirstAncestor("ContextActionGui") or inst:FindFirstAncestor("TouchGui") then
		return
	end
	hooked[inst] = true
	local button = inst :: GuiButton
	button.Activated:Connect(function()
		Audio.play("UiClick")
	end)
end

task.spawn(function()
	local gui = player:WaitForChild("PlayerGui", 30)
	if gui then
		for _, d in gui:GetDescendants() do
			hookButton(d)
		end
		gui.DescendantAdded:Connect(hookButton)
	end
end)

------------------------------------------------------------------------
-- Кадр
------------------------------------------------------------------------

local syncTimer = 0
local fireTimer = 0
local fires: { BasePart } = {}
local scannedMap: Instance? = nil
local scannedLobby: Instance? = nil
local crowTimer = 20
local thunderTimer = 45
local beatTimer = 0
local fatigue = 0
local duck = 0
local muffle = 0
local gateSeen: { [Instance]: { Progress: number, Changed: number } } = {}
local lastBeat: Sound? = nil

-- Костры в лобби и на карте (детали FireSource)
local function collectFires(container: Instance?)
	if not container then
		return
	end
	for _, d in container:GetDescendants() do
		if d.Name == "FireSource" and d:IsA("BasePart") then
			table.insert(fires, d)
		end
	end
end

local function updateMap(map: Instance, now: number)
	-- Генераторы гудят, пока их чинят и после починки
	local gens = map:FindFirstChild("Generators")
	if gens then
		for _, gen in gens:GetChildren() do
			local part = gen:IsA("Model") and (gen :: Model).PrimaryPart
			local p = gen:GetAttribute("Progress") or 0
			if part and p > 0 and near(part.Position, 70) then
				if gen:GetAttribute("Done") then
					want("GenLoop", part, 0.7, 1.1)
				else
					want("GenLoop", part, 0.35 + 0.65 * p, 0.92 + 0.16 * p)
				end
			end
		end
	end

	-- Люк воет ветром
	local hatch = map:FindFirstChild("Hatch")
	local hatchPart = hatch and hatch:IsA("Model") and (hatch :: Model).PrimaryPart
	if hatch and hatchPart and hatch:GetAttribute("Open") and near(hatchPart.Position, 55) then
		want("HatchWind", hatchPart, 1)
	end

	-- Сирена ворот, пока их открывают
	local gates = map:FindFirstChild("ExitGates")
	if gates then
		for _, gate in gates:GetChildren() do
			local p = gate:GetAttribute("Progress") or 0
			local seen = gateSeen[gate]
			if not seen or seen.Progress ~= p then
				gateSeen[gate] = { Progress = p, Changed = if seen then now else -math.huge }
			end
			local opening = now - gateSeen[gate].Changed < 1
			if opening and gate:GetAttribute("Powered") and not gate:GetAttribute("Open") then
				local siren = gate:FindFirstChild("Siren", true) or (gate:IsA("Model") and (gate :: Model).PrimaryPart)
				if siren and siren:IsA("BasePart") then
					want("GateSiren", siren, 1)
				end
			end
		end
	end
end

local function updateBreathing(dt: number, killer: Player?)
	-- Раненые и лежащие выжившие тяжело дышат (слышно и маньяку)
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("Role") == "Survivor" and p:GetAttribute("Status") == "Playing" then
			local hp = p:GetAttribute("Health") or 2
			local root = Util.getRoot(p)
			if hp < 2 and root and near(root.Position, 34) then
				want("BreathInjured", root, if hp == 0 then 1 else 0.75, if hp == 0 then 0.85 else 1)
			end
		end
	end

	-- Одышка после долгого бега
	local me = player:GetAttribute("Role") == "Survivor" and player:GetAttribute("Status") == "Playing"
	local running = me and player:GetAttribute("Running") == true
	fatigue = if running then math.min(fatigue + dt / 6, 1) else math.max(fatigue - dt / 5, 0)
	if me and (player:GetAttribute("Health") or 2) == 2 and fatigue > 0.3 then
		want("BreathExhausted", nil, (fatigue - 0.3) / 0.7 * (if running then 0.5 else 1))
	end

	-- Дыхание маньяка совсем рядом (кроме невидимого Призрака: радиус ужаса 0)
	local kroot = Util.getRoot(killer)
	if me and killer and kroot and (tonumber(killer:GetAttribute("TerrorRadius")) or 32) > 0 and near(kroot.Position, 26) then
		want("KillerBreath", kroot, 1)
	end
end

function Audio.update(dt: number)
	frame += 1
	local now = os.clock()
	local map = workspace:FindFirstChild("Map")
	local role = player:GetAttribute("Role")
	local inGame = role ~= nil and Util.isInGameStatus(player:GetAttribute("Status"))

	syncTimer -= dt
	if syncTimer <= 0 then
		syncTimer = 1
		syncLibrary()
	end

	-- Атмосфера
	want("Wind", nil, if map and role then 1 else 0.6)
	want("NightInsects", nil, 1)
	want("AmbientMusic", nil, if role then 0 else 1)
	-- Костры ищем при смене карты/лобби и изредка (части карты могут догружаться)
	local lobby = workspace:FindFirstChild("Lobby")
	fireTimer -= dt
	if fireTimer <= 0 or map ~= scannedMap or lobby ~= scannedLobby then
		if map ~= scannedMap then
			table.clear(gateSeen)
		end
		fireTimer = 15
		scannedMap, scannedLobby = map, lobby
		table.clear(fires)
		collectFires(lobby)
		collectFires(map)
	end
	for _, fire in fires do
		if fire.Parent and near(fire.Position, 50) then
			want("Campfire", fire, 1)
		end
	end
	thunderTimer -= dt
	if thunderTimer <= 0 then
		thunderTimer = 50 + math.random() * 70
		Audio.play("Thunder", nil, 0.5 + math.random() * 0.5)
	end
	if map and inGame then
		crowTimer -= dt
		if crowTimer <= 0 then
			crowTimer = 15 + math.random() * 25
			local a = math.random() * math.pi * 2
			local pos = listenerPosition() + Vector3.new(math.cos(a) * 60, 10, math.sin(a) * 60)
			Audio.play("Crow", pos, 0.5)
		end
	end

	-- Радиус ужаса: дальний гул -> сердце -> погоня (у Охотницы вместо гула и сердца — колыбельная)
	local killer = findKiller()
	local intensity = killerProximity(killer, 1)
	local chase = inGame and player:GetAttribute("Chase") == true
	duck = if chase then math.min(duck + dt * 1.5, 1) else math.max(duck - dt * 0.4, 0)
	local lullaby = killer and KillerDefs.get(killer:GetAttribute("KillerType")).Lullaby
	if lullaby then
		want("Lullaby", nil, killerProximity(killer, 1.8) ^ 0.8)
	elseif intensity > 0 then
		want("TerrorDrone", nil, intensity ^ 0.7 * (1 - 0.8 * duck), 0.9 + 0.2 * intensity)
	end
	if intensity > 0 and not lullaby then
		beatTimer -= dt
		if beatTimer <= 0 then
			beatTimer = 1.2 - 0.75 * intensity
			if lastBeat and lastBeat.Parent then
				fadeOut(lastBeat, 0.08)
			end
			lastBeat = Audio.play("Heartbeat", nil, 0.3 + 0.7 * intensity, 0.96 + 0.08 * intensity)
		end
	else
		beatTimer = 0
	end
	if chase then
		want("ChaseMusic", nil, 1)
	end

	if map and inGame then
		updateMap(map, now)
	end
	if inGame then
		updateBreathing(dt, killer)
	end

	-- Микс: в погоне и у маньяка атмосфера тише, из шкафчика всё звучит глухо
	Audio.Groups.Ambience.Volume = (Config.SoundGroupVolumes.Ambience or 1) * (1 - 0.6 * duck) * (1 - 0.35 * intensity)
	local hidden = inGame and player:GetAttribute("Hidden") == true
	muffle = if hidden then math.min(muffle + dt * 3, 1) else math.max(muffle - dt * 3, 0)
	for name, eq in groupEq do
		if MUFFLED[name] then
			eq.HighGain = baseHighGain[name] - 18 * muffle
		end
	end

	updateLoops(dt)
end

pumpJobs()

return Audio
