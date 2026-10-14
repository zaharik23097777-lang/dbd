-- Библиотека звуков.
-- По умолчанию используются звуки, встроенные в клиент Roblox (rbxasset://sounds/...),
-- их гарантированно слышно в любой игре. Изменяя высоту тона и эффекты, из них собраны
-- все звуки игры. Любой звук можно заменить своим ID через Config.SoundOverrides.
local Config = require(script.Parent.Config)

local F = "rbxasset://sounds/"
local STEP = F .. "action_footsteps_plastic.mp3"
local LAND = F .. "action_jump_land.mp3"
local JUMP = F .. "action_jump.mp3"
local FALL = F .. "action_falling.ogg"
local SWIM = F .. "action_swim.mp3"
local SPLASH = F .. "impact_water.mp3"
local GETUP = F .. "action_get_up.mp3"
local OOF = F .. "uuhhh.mp3"

-- Effects: Distortion (0..1), Echo {Delay, Feedback}, LowPass (true = глушим верха), Reverb
local Sounds = {}

Sounds.Defs = {
	Footstep = { Id = STEP, Volume = 0.35, Speed = 1, MaxDistance = 70 },
	KillerFootstep = { Id = STEP, Volume = 0.7, Speed = 0.65, MaxDistance = 90, Effects = { LowPass = true } },
	HeartThump = { Id = LAND, Volume = 1, Speed = 0.32, Effects = { LowPass = true } },
	Wind = { Id = FALL, Volume = 0.18, Speed = 0.3, Looped = true, Effects = { LowPass = true } },
	Whoosh = { Id = FALL, Volume = 0.8, Speed = 2.6, Duration = 0.3, MaxDistance = 60 },
	Swing = { Id = FALL, Volume = 0.9, Speed = 3.2, Duration = 0.25, MaxDistance = 60 },
	Hit = { Id = LAND, Volume = 1, Speed = 0.8, MaxDistance = 80, Effects = { Distortion = 0.6 } },
	Pain = { Id = OOF, Volume = 1, Speed = 1.15, MaxDistance = 120 },
	Scream = { Id = OOF, Volume = 1, Speed = 0.8, MaxDistance = 250, Effects = { Echo = { 0.12, 0.35 } } },
	Thud = { Id = LAND, Volume = 1, Speed = 0.55, MaxDistance = 90 },
	PalletSlam = { Id = LAND, Volume = 1, Speed = 0.45, MaxDistance = 140, Effects = { Distortion = 0.4 } },
	PalletBreak = { Id = SPLASH, Volume = 1, Speed = 1.6, MaxDistance = 140, Effects = { Distortion = 0.7 } },
	Vault = { Id = JUMP, Volume = 0.8, Speed = 0.9, MaxDistance = 80 },
	Rustle = { Id = GETUP, Volume = 0.8, Speed = 1, MaxDistance = 50 },
	LockerDoor = { Id = LAND, Volume = 0.9, Speed = 1.7, MaxDistance = 80, Effects = { Echo = { 0.05, 0.3 } } },
	GenLoop = { Id = SWIM, Volume = 0.3, Speed = 0.35, Looped = true, MaxDistance = 60, Effects = { Distortion = 0.5, LowPass = true } },
	GenExplode = { Id = SPLASH, Volume = 1, Speed = 0.45, MaxDistance = 300, Effects = { Distortion = 0.9 } },
	GenDone = { Id = LAND, Volume = 1, Speed = 0.3, Effects = { Echo = { 0.35, 0.5 }, Distortion = 0.3 } },
	Clank = { Id = LAND, Volume = 1, Speed = 2.2, MaxDistance = 100, Effects = { Echo = { 0.06, 0.4 } } },
	TrapSnap = { Id = LAND, Volume = 1, Speed = 2.8, MaxDistance = 160, Effects = { Distortion = 0.8 } },
	SkillWarn = { Id = LAND, Volume = 0.8, Speed = 3.5, Effects = { Echo = { 0.08, 0.2 } } },
	SkillGood = { Id = STEP, Volume = 0.8, Speed = 2 },
	Bell = { Id = LAND, Volume = 1, Speed = 3, MaxDistance = 200, Effects = { Echo = { 0.25, 0.6 } } },
	GatePowered = { Id = FALL, Volume = 0.8, Speed = 0.6, Duration = 2.5, Effects = { Distortion = 0.6, Echo = { 0.3, 0.5 } } },
	GateOpen = { Id = SWIM, Volume = 1, Speed = 0.25, Duration = 2.5, MaxDistance = 300, Effects = { Distortion = 0.7 } },
	EntityDrone = { Id = FALL, Volume = 1, Speed = 0.15, Duration = 3, Effects = { Distortion = 0.8, Echo = { 0.4, 0.6 } } },
	HatchWind = { Id = FALL, Volume = 0.5, Speed = 0.5, Looped = true, MaxDistance = 40, Effects = { Echo = { 0.2, 0.4 } } },
	Crow = { Id = OOF, Volume = 0.8, Speed = 2.8, MaxDistance = 150, Effects = { Distortion = 0.9 } },
	Flutter = { Id = FALL, Volume = 0.7, Speed = 4, Duration = 0.6, MaxDistance = 80 },
	Click = { Id = STEP, Volume = 0.6, Speed = 3, MaxDistance = 40 },
	Throw = { Id = FALL, Volume = 1, Speed = 2, Duration = 0.4, MaxDistance = 120 },
	Hum = { Id = JUMP, Volume = 0.6, Speed = 0.5, MaxDistance = 40, Effects = { Echo = { 0.3, 0.5 } } },
	Chest = { Id = GETUP, Volume = 0.9, Speed = 0.7, MaxDistance = 60 },
	Notify = { Id = STEP, Volume = 0.5, Speed = 1.5 },
	ChaseDrone = { Id = FALL, Volume = 0.45, Speed = 0.22, Looped = true, Effects = { Distortion = 0.5, LowPass = true } },

	-- Атмосфера ужаса
	AmbientDrone = { Id = FALL, Volume = 0.3, Speed = 0.12, Looped = true, Effects = { LowPass = true, Echo = { 0.5, 0.6 } } },
	Whisper = { Id = OOF, Volume = 0.45, Speed = 0.45, MaxDistance = 90, Effects = { Echo = { 0.18, 0.55 }, LowPass = true } },
	Creak = { Id = GETUP, Volume = 0.7, Speed = 0.35, MaxDistance = 90, Effects = { Echo = { 0.25, 0.4 } } },
	DistantScream = { Id = OOF, Volume = 0.6, Speed = 0.68, MaxDistance = 400, Effects = { Echo = { 0.35, 0.6 }, LowPass = true } },
	MetalScrape = { Id = FALL, Volume = 0.5, Speed = 1.8, Duration = 1.2, MaxDistance = 120, Effects = { Distortion = 0.9, Echo = { 0.2, 0.5 } } },
	Thunder = { Id = LAND, Volume = 1, Speed = 0.12, Effects = { Distortion = 0.6, Echo = { 0.45, 0.6 }, LowPass = true } },
	Stinger = { Id = LAND, Volume = 1, Speed = 0.5, Effects = { Distortion = 0.95, Echo = { 0.12, 0.5 } } },
	StingerScreech = { Id = FALL, Volume = 0.8, Speed = 3.6, Duration = 0.7, Effects = { Distortion = 0.9, Echo = { 0.08, 0.4 } } },
	TerrorStinger = { Id = FALL, Volume = 0.8, Speed = 0.25, Duration = 1.6, Effects = { Distortion = 0.7, LowPass = true } },
	ChasePulse = { Id = LAND, Volume = 0.7, Speed = 0.4, Effects = { Distortion = 0.5, LowPass = true } },
	FireCrackle = { Id = STEP, Volume = 0.3, Speed = 2.6, MaxDistance = 45 },
	KillerGrowl = { Id = OOF, Volume = 0.8, Speed = 0.33, MaxDistance = 60, Effects = { Echo = { 0.1, 0.3 }, LowPass = true } },
	Groan = { Id = OOF, Volume = 0.45, Speed = 1.05, MaxDistance = 45 },
	EntityWhisper = { Id = OOF, Volume = 0.9, Speed = 0.25, MaxDistance = 120, Effects = { Echo = { 0.3, 0.7 }, Distortion = 0.4 } },

	-- Слоты без звука по умолчанию: вставь свой ID в Config.SoundOverrides
	ChaseMusic = { Id = "", Volume = 0.6, Looped = true },
	Lullaby = { Id = "", Volume = 0.6, Looped = true },
	AmbientMusic = { Id = "", Volume = 0.25, Looped = true },
	Heartbeat = { Id = "", Volume = 1, Looped = true },
}

-- Возвращает определение звука с учётом переопределения из Config
function Sounds.get(name: string)
	local def = Sounds.Defs[name]
	if not def then
		return nil
	end
	local override = Config.SoundOverrides[name]
	if override and override ~= "" then
		return {
			Id = override,
			Volume = def.Volume,
			Speed = 1,
			Looped = def.Looped,
			MaxDistance = def.MaxDistance,
			Custom = true,
		}
	end
	if def.Id == "" then
		return nil
	end
	return def
end

return Sounds
