-- Звук: 3D-эффекты, синтезированное сердцебиение, погоня, генераторы, шаги, атмосфера.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Sounds = require(ReplicatedStorage.Shared.Sounds)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Util = require(ReplicatedStorage.Shared.Util)
local KillerDefs = require(ReplicatedStorage.Shared.KillerDefs)

local player = Players.LocalPlayer
local Audio = {}

SoundService.AmbientReverb = Enum.ReverbType.Forest

local function addEffects(sound: Sound, effects)
	if not effects then
		return
	end
	if effects.Distortion then
		local d = Instance.new("DistortionSoundEffect")
		d.Level = effects.Distortion
		d.Parent = sound
	end
	if effects.Echo then
		local e = Instance.new("EchoSoundEffect")
		e.Delay = effects.Echo[1]
		e.Feedback = effects.Echo[2]
		e.WetLevel = -6
		e.Parent = sound
	end
	if effects.LowPass then
		local eq = Instance.new("EqualizerSoundEffect")
		eq.HighGain = -30
		eq.MidGain = -8
		eq.LowGain = 4
		eq.Parent = sound
	end
end

-- Создаёт звук. where: BasePart / Model / Vector3 / nil (2D)
function Audio.create(name: string, where: any?): Sound?
	local def = Sounds.get(name)
	if not def then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = def.Id
	sound.Volume = def.Volume or 1
	sound.PlaybackSpeed = def.Speed or 1
	sound.Looped = def.Looped == true
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = def.MaxDistance or 100
	if not def.Custom then
		addEffects(sound, def.Effects)
	end
	local parent: Instance = SoundService
	if typeof(where) == "Instance" then
		if where:IsA("Model") then
			parent = where.PrimaryPart or where:FindFirstChildWhichIsA("BasePart") or SoundService
		elseif where:IsA("BasePart") or where:IsA("Attachment") then
			parent = where
		end
	elseif typeof(where) == "Vector3" then
		local att = Instance.new("Attachment")
		att.WorldPosition = where
		att.Parent = workspace.Terrain
		parent = att
		Debris:AddItem(att, 12)
	end
	sound.Parent = parent
	return sound
end

function Audio.play(name: string, where: any?, volumeScale: number?, speedScale: number?): Sound?
	local sound = Audio.create(name, where)
	if not sound then
		return nil
	end
	local def = Sounds.get(name)
	if volumeScale then
		sound.Volume *= volumeScale
	end
	if speedScale then
		sound.PlaybackSpeed *= speedScale
	end
	sound:Play()
	if not sound.Looped then
		if def and def.Duration then
			task.delay(def.Duration, function()
				if sound.Parent then
					local tw = TweenService:Create(sound, TweenInfo.new(0.15), { Volume = 0 })
					tw:Play()
					tw.Completed:Wait()
					sound:Destroy()
				end
			end)
		end
		sound.Ended:Connect(function()
			sound:Destroy()
		end)
		Debris:AddItem(sound, 15)
	end
	return sound
end

Remotes.Sfx.OnClientEvent:Connect(function(name, where)
	Audio.play(name, where)
end)

------------------------------------------------------------------------
-- Шаги (вызывает Animator в такт шагам)
------------------------------------------------------------------------

function Audio.footstep(char: Model, isKiller: boolean, speed: number, crouching: boolean)
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local vol = crouching and 0.25 or math.clamp(speed / 16, 0.35, 1.1)
	Audio.play(isKiller and "KillerFootstep" or "Footstep", root, vol, 0.92 + math.random() * 0.16)
end

------------------------------------------------------------------------
-- Фоновые звуки
------------------------------------------------------------------------

local wind = Audio.create("Wind", nil)
if wind then
	wind:Play()
end
local ambientMusic = Audio.create("AmbientMusic", nil)
if ambientMusic then
	ambientMusic:Play()
end

local heartbeatLoop = Audio.create("Heartbeat", nil) -- если задан свой звук
local lullabyLoop = Audio.create("Lullaby", nil)
local chaseMusic = Audio.create("ChaseMusic", nil)
local chaseDrone = Audio.create("ChaseDrone", nil)
for _, s in { heartbeatLoop, lullabyLoop, chaseMusic, chaseDrone } do
	if s then
		s.Volume = 0
		s:Play()
	end
end
local chaseLayer = chaseMusic or chaseDrone
local chaseMaxVolume = chaseLayer and (Sounds.get(chaseMusic and "ChaseMusic" or "ChaseDrone") :: any).Volume or 0

local beatTimer = 0
local crowTimer = 20
local genSounds = {} :: { [Instance]: Sound }
local hatchSound: Sound? = nil

local function findKiller(): Player?
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("Role") == "Killer" then
			return p
		end
	end
	return nil
end

-- Сила радиуса ужаса для локального выжившего (0..1)
function Audio.terrorIntensity(): number
	if player:GetAttribute("Role") ~= "Survivor" or not Util.isInGameStatus(player:GetAttribute("Status")) then
		return 0
	end
	local killer = findKiller()
	local kroot = Util.getRoot(killer)
	local myRoot = Util.getRoot(player)
	if not kroot or not myRoot then
		return 0
	end
	local tr = (killer :: Player):GetAttribute("TerrorRadius") or 32
	if tr <= 0 then
		return 0
	end
	return math.clamp(1 - Util.flatDist(kroot.Position, myRoot.Position) / tr, 0, 1)
end

local function updateGenerators(map: Instance?)
	local gens = map and map:FindFirstChild("Generators")
	local alive = {}
	if gens then
		for _, gen in gens:GetChildren() do
			local p = gen:GetAttribute("Progress") or 0
			if p > 0 and not gen:GetAttribute("Done") then
				alive[gen] = true
				local s = genSounds[gen]
				if not s then
					s = Audio.create("GenLoop", gen)
					if s then
						s:Play()
						genSounds[gen] = s
					end
				end
				if s then
					s.Volume = 0.1 + 0.45 * p
					s.PlaybackSpeed = 0.3 + 0.15 * p
				end
			end
		end
	end
	for gen, s in genSounds do
		if not alive[gen] then
			s:Destroy()
			genSounds[gen] = nil
		end
	end
end

function Audio.update(dt: number)
	local map = workspace:FindFirstChild("Map")
	local inMatch = player:GetAttribute("Role") ~= nil
	if wind then
		wind.Volume = map and 0.2 or 0.1
	end

	-- Сердцебиение / колыбельная
	local intensity = Audio.terrorIntensity()
	local killer = findKiller()
	local lullaby = killer and KillerDefs.get(killer:GetAttribute("KillerType")).Lullaby
	if lullaby and lullabyLoop then
		lullabyLoop.Volume = intensity
	elseif heartbeatLoop then
		heartbeatLoop.Volume = intensity
		heartbeatLoop.PlaybackSpeed = 0.9 + intensity * 0.5
	elseif intensity > 0 then
		beatTimer -= dt
		if beatTimer <= 0 then
			beatTimer = 1.25 - 0.8 * intensity
			local vol = 0.3 + 0.7 * intensity
			Audio.play("HeartThump", nil, vol)
			task.delay(0.17, function()
				Audio.play("HeartThump", nil, vol * 0.7, 0.9)
			end)
		end
	end

	-- Погоня
	if chaseLayer then
		local target = player:GetAttribute("Chase") and chaseMaxVolume or 0
		chaseLayer.Volume += (target - chaseLayer.Volume) * math.min(dt * 1.5, 1)
	end

	updateGenerators(map)

	-- Люк
	local hatch = map and map:FindFirstChild("Hatch")
	local hatchOpen = hatch and hatch:GetAttribute("Open")
	if hatchOpen and not hatchSound then
		hatchSound = Audio.create("HatchWind", hatch)
		if hatchSound then
			hatchSound:Play()
		end
	elseif not hatchOpen and hatchSound then
		hatchSound:Destroy()
		hatchSound = nil
	end

	-- Далёкие вороны для атмосферы
	if map and inMatch then
		crowTimer -= dt
		if crowTimer <= 0 then
			crowTimer = 15 + math.random() * 25
			local myRoot = Util.getRoot(player)
			if myRoot then
				local a = math.random() * math.pi * 2
				Audio.play("Crow", myRoot.Position + Vector3.new(math.cos(a) * 60, 10, math.sin(a) * 60), 0.5)
			end
		end
	end
end

return Audio
