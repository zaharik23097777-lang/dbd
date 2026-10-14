-- Библиотека звуков: слоты игры, поиск настоящих звуков и встроенный синтез.
-- Порядок выбора звука для слота (Sounds.get):
--   1) Config.SoundOverrides[имя] — свой ID (строка или список вариантов);
--   2) звук из библиотеки Creator Store: сервер ищет его через AssetService:SearchAudioAsync
--      (src/server/Core/SoundLibrary.lua), клиент проверяет загрузку (Sounds.setLibrary);
--   3) синтез из звуков, встроенных в клиент Roblox (rbxasset://sounds/...): слои с разной
--      высотой тона, задержкой и эффектами. Он работает всегда, даже без сети.
-- Любой ID, который не загрузился, запоминается (Sounds.markFailed) и больше не используется.
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

-- Эффекты слоя. LowPass/HighPass — на сколько дБ глушить верха/низы.
export type Effects = {
	Distortion: number?,
	Echo: { number }?, -- { Delay, Feedback }
	LowPass: number?,
	HighPass: number?,
	Tremolo: { number }?, -- { Frequency, Depth, Duty }
	Reverb: { number }?, -- { DecayTime, WetLevel }
	Octave: number?, -- PitchShift
}

-- Один звук внутри слота
export type Layer = {
	Id: string,
	Volume: number,
	Speed: number,
	Delay: number?, -- задержка запуска, с
	Start: number?, -- TimePosition, с
	Duration: number?, -- обрезать (с коротким затуханием)
	Effects: Effects?,
}

-- Что искать в библиотеке Creator Store
export type Search = {
	Keywords: { string }, -- запросы по порядку, пока не наберём Count вариантов
	Music: boolean?, -- AudioSubType: Music (иначе SoundEffect)
	Min: number?, -- длительность, с
	Max: number?,
	Count: number?, -- сколько разных вариантов взять (шаги, крики)
	Avoid: { string }?, -- слова в названии, из-за которых звук не подходит
}

-- Мелодия из нот (синтез колыбельной): полутона от базовой высоты, false — пауза
export type Melody = { Layer: Layer, Step: number, Notes: { number | false } }

export type Def = {
	Name: string,
	Group: string, -- SoundGroup: SFX / Ambience / Music / Voice / UI
	Volume: number,
	Looped: boolean?,
	MaxDistance: number?, -- nil = 2D-звук (без позиции)
	MinDistance: number?,
	Priority: number?, -- 1 — можно вытеснить (шаги), 3 — важный (крик, проверка навыка)
	Pitch: number?, -- случайный разброс высоты, ±доля
	Jitter: number?, -- случайный разброс громкости, ±доля
	Duration: number?, -- предел длины одноразового звука (для любого источника)
	FadeIn: number?, -- петли: время нарастания и затухания, с
	FadeOut: number?,
	Variants: number?, -- синтез: число вариантов (ступени высоты), чтобы не повторяться
	Search: Search?,
	Synth: { Layer }?,
	Melody: Melody?,
}

export type Resolved = {
	Name: string,
	Def: Def,
	Source: string, -- "Override" | "Library" | "Synth"
	Variants: { { Layer } },
}

local function L(id: string, volume: number, speed: number, extra: { [string]: any }?): Layer
	local layer: { [string]: any } = { Id = id, Volume = volume, Speed = speed }
	if extra then
		for k, v in extra do
			if k == "Delay" or k == "Start" or k == "Duration" then
				layer[k] = v
			else
				layer.Effects = layer.Effects or {}
				layer.Effects[k] = v
			end
		end
	end
	return layer :: any
end

local STEP_AVOID = { "run", "walk", "loop", "sprint", "jump" } -- нужен один шаг, а не серия

local Sounds = {}

Sounds.LibraryFolder = "SoundLibrary" -- папка в ReplicatedStorage с найденными ID

-- Слоты по важности: в таком порядке идёт поиск и проверка загрузки
Sounds.List = {
	-- Радиус ужаса и погоня
	{
		-- Сердце звучит «в голове» выжившего: группа Music — сухо и не глушится в шкафчике.
		-- Короткие записи (до 1.5 с) — это один удар «тук-тук», а не серия со своим темпом.
		Name = "Heartbeat",
		Group = "Music",
		Volume = 1.3,
		Priority = 3,
		Duration = 1.2,
		Search = { Keywords = { "heartbeat", "heart beat" }, Min = 0.3, Max = 1.5 },
		Synth = { L(LAND, 1, 0.32, { LowPass = 20 }), L(LAND, 0.7, 0.29, { Delay = 0.16, LowPass = 20 }) },
	},
	{
		Name = "ChaseMusic",
		Group = "Music",
		Volume = 0.6,
		Looped = true,
		FadeIn = 0.6,
		FadeOut = 3,
		Search = { Keywords = { "horror chase", "chase horror", "intense horror" }, Music = true, Min = 30, Max = 180 },
		Synth = {
			L(FALL, 0.75, 0.22, { Distortion = 0.5, LowPass = 18 }),
			L(SWIM, 0.35, 0.5, { Tremolo = { 2.4, 0.9, 0.5 }, LowPass = 10 }),
			L(FALL, 0.3, 0.9, { Tremolo = { 4.8, 1, 0.3 }, LowPass = 24 }),
		},
	},
	{
		Name = "TerrorDrone",
		Group = "Music",
		Volume = 0.45,
		Looped = true,
		FadeIn = 1.5,
		FadeOut = 2,
		Search = { Keywords = { "horror drone", "dark drone", "tension drone" }, Min = 8, Max = 120 },
		Synth = { L(FALL, 1, 0.15, { LowPass = 25, Distortion = 0.25 }), L(SWIM, 0.5, 0.18, { LowPass = 20 }) },
	},
	{
		Name = "Lullaby",
		Group = "Music",
		Volume = 0.6,
		Looped = true,
		FadeIn = 1,
		FadeOut = 2,
		Search = { Keywords = { "creepy lullaby", "music box lullaby", "lullaby" }, Music = true, Min = 10, Max = 120 },
		-- Колыбельная Охотницы: напевающий голос с эхом
		Melody = {
			Layer = L(OOF, 0.7, 0.9, { Duration = 0.5, Echo = { 0.3, 0.45 }, LowPass = 8 }),
			Step = 0.42,
			Notes = { 0, 3, 7, 7, 5, 3, 2, 3, 5, 0, false, false, 0, 3, 7, 10, 8, 7, 5, 3, 2, 3, 0, false },
		},
	},

	-- Шаги: по материалу пола (Audio.footstep), 4 варианта без повторов подряд
	{
		Name = "Footstep",
		Group = "SFX",
		Volume = 0.55,
		MaxDistance = 55,
		MinDistance = 4,
		Priority = 1,
		Pitch = 0.06,
		Jitter = 0.15,
		Variants = 4,
		Search = { Keywords = { "footstep", "footsteps" }, Min = 0.1, Max = 1.2, Count = 4, Avoid = STEP_AVOID },
		Synth = { L(STEP, 0.7, 1, { Duration = 0.3 }) },
	},
	{
		Name = "FootstepDirt",
		Group = "SFX",
		Volume = 0.55,
		MaxDistance = 55,
		MinDistance = 4,
		Priority = 1,
		Pitch = 0.06,
		Jitter = 0.15,
		Variants = 4,
		Search = {
			Keywords = { "footstep dirt", "footstep gravel", "footstep grass" },
			Min = 0.1,
			Max = 1.2,
			Count = 4,
			Avoid = STEP_AVOID,
		},
		Synth = { L(STEP, 0.65, 0.82, { Duration = 0.3, LowPass = 10 }), L(SPLASH, 0.12, 2.6, { Duration = 0.12, LowPass = 6 }) },
	},
	{
		Name = "FootstepWood",
		Group = "SFX",
		Volume = 0.55,
		MaxDistance = 60,
		MinDistance = 4,
		Priority = 1,
		Pitch = 0.06,
		Jitter = 0.15,
		Variants = 4,
		Search = { Keywords = { "footstep wood", "wood floor step" }, Min = 0.1, Max = 1.2, Count = 4, Avoid = STEP_AVOID },
		Synth = { L(STEP, 0.65, 0.78, { Duration = 0.3 }), L(LAND, 0.3, 1.7, { Duration = 0.25 }) },
	},
	{
		Name = "FootstepMetal",
		Group = "SFX",
		Volume = 0.55,
		MaxDistance = 65,
		MinDistance = 4,
		Priority = 1,
		Pitch = 0.06,
		Jitter = 0.15,
		Variants = 4,
		Search = { Keywords = { "footstep metal", "metal step" }, Min = 0.1, Max = 1.2, Count = 4, Avoid = STEP_AVOID },
		Synth = {
			L(STEP, 0.6, 1.15, { Duration = 0.3 }),
			L(LAND, 0.3, 2.8, { Duration = 0.35, Echo = { 0.04, 0.35 } }),
		},
	},
	{
		Name = "FootstepStone",
		Group = "SFX",
		Volume = 0.55,
		MaxDistance = 55,
		MinDistance = 4,
		Priority = 1,
		Pitch = 0.06,
		Jitter = 0.15,
		Variants = 4,
		Search = { Keywords = { "footstep concrete", "footstep stone" }, Min = 0.1, Max = 1.2, Count = 4, Avoid = STEP_AVOID },
		Synth = { L(STEP, 0.7, 1.05, { Duration = 0.25, HighPass = 8 }), L(LAND, 0.15, 2.2, { Duration = 0.15 }) },
	},
	{
		-- Тяжёлый слой шага маньяка (поверх шага по материалу)
		Name = "KillerFootstep",
		Group = "SFX",
		Volume = 0.7,
		MaxDistance = 80,
		MinDistance = 6,
		Priority = 2,
		Pitch = 0.05,
		Jitter = 0.1,
		Variants = 3,
		Search = {
			Keywords = { "heavy footstep", "boot footstep", "giant footstep" },
			Min = 0.1,
			Max = 1.5,
			Count = 3,
			Avoid = STEP_AVOID,
		},
		Synth = { L(LAND, 0.9, 0.55, { LowPass = 14 }), L(STEP, 0.6, 0.6, { Duration = 0.35 }) },
	},

	-- Голоса
	{
		Name = "Scream",
		Group = "Voice",
		Volume = 1,
		MaxDistance = 250,
		MinDistance = 10,
		Priority = 3,
		Pitch = 0.04,
		Search = { Keywords = { "scream horror", "woman scream", "man scream" }, Min = 0.6, Max = 4, Count = 3 },
		Synth = {
			L(OOF, 1, 0.8, { Echo = { 0.12, 0.35 } }),
			L(OOF, 0.55, 0.72, { Delay = 0.06, Distortion = 0.25 }),
			L(OOF, 0.4, 0.95, { Delay = 0.18, Echo = { 0.2, 0.4 } }),
		},
	},
	{
		Name = "Pain",
		Group = "Voice",
		Volume = 1,
		MaxDistance = 120,
		MinDistance = 8,
		Priority = 3,
		Pitch = 0.06,
		Search = { Keywords = { "pain grunt", "hurt grunt", "male grunt" }, Max = 2, Count = 3 },
		Synth = { L(OOF, 1, 1.15) },
	},
	{
		Name = "BreathInjured",
		Group = "Voice",
		Volume = 0.6,
		Looped = true,
		MaxDistance = 30,
		MinDistance = 3,
		FadeIn = 0.8,
		FadeOut = 1.2,
		Search = { Keywords = { "heavy breathing", "breathing pain", "painful breathing" }, Min = 2, Max = 30 },
		Synth = { L(FALL, 0.6, 1.6, { LowPass = 16, Tremolo = { 0.55, 0.95, 0.45 } }) },
	},
	{
		Name = "BreathExhausted",
		Group = "Voice",
		Volume = 0.45,
		Looped = true,
		FadeIn = 0.6,
		FadeOut = 2,
		Search = { Keywords = { "panting", "out of breath", "heavy panting" }, Min = 2, Max = 30 },
		Synth = { L(FALL, 0.6, 1.9, { LowPass = 12, Tremolo = { 1.4, 0.95, 0.4 } }) },
	},
	{
		Name = "KillerBreath",
		Group = "Voice",
		Volume = 0.6,
		Looped = true,
		MaxDistance = 24,
		MinDistance = 4,
		FadeIn = 1,
		FadeOut = 1.5,
		Search = { Keywords = { "monster breathing", "creature breathing", "growl breathing" }, Min = 2, Max = 30 },
		Synth = { L(FALL, 0.8, 0.55, { Distortion = 0.3, LowPass = 20, Tremolo = { 0.35, 0.9, 0.5 } }) },
	},
	{
		Name = "Hum",
		Group = "Voice",
		Volume = 0.7,
		MaxDistance = 60,
		MinDistance = 6,
		Priority = 3,
		Search = { Keywords = { "woman humming", "creepy humming", "humming" }, Min = 0.8, Max = 6 },
		Synth = { L(JUMP, 0.85, 0.5, { Echo = { 0.3, 0.5 } }), L(JUMP, 0.5, 0.6, { Delay = 0.25, Echo = { 0.3, 0.5 } }) },
	},

	-- Маньяк и способности
	{
		Name = "Hit",
		Group = "SFX",
		Volume = 1,
		MaxDistance = 90,
		MinDistance = 8,
		Priority = 3,
		Pitch = 0.05,
		Search = { Keywords = { "knife stab", "flesh hit", "sword hit flesh" }, Max = 2, Count = 2 },
		Synth = { L(LAND, 1, 0.8, { Distortion = 0.6 }), L(SPLASH, 0.45, 1.4, { Duration = 0.25, Distortion = 0.3 }) },
	},
	{
		Name = "Swing",
		Group = "SFX",
		Volume = 0.9,
		MaxDistance = 60,
		MinDistance = 6,
		Priority = 2,
		Pitch = 0.06,
		Search = { Keywords = { "sword swing", "swing whoosh", "whoosh" }, Max = 1.2, Count = 3 },
		Synth = { L(FALL, 1, 3.2, { Duration = 0.25 }) },
	},
	{
		Name = "Throw",
		Group = "SFX",
		Volume = 1,
		MaxDistance = 120,
		MinDistance = 8,
		Priority = 2,
		Pitch = 0.05,
		Search = { Keywords = { "axe throw", "throw whoosh", "whoosh" }, Max = 1.5 },
		Synth = { L(FALL, 1, 2, { Duration = 0.4 }), L(FALL, 0.5, 2.6, { Delay = 0.08, Duration = 0.3 }) },
	},
	{
		Name = "Thud",
		Group = "SFX",
		Volume = 1,
		MaxDistance = 90,
		MinDistance = 6,
		Priority = 2,
		Pitch = 0.05,
		Search = { Keywords = { "axe hit wood", "axe chop", "wood impact" }, Max = 2 },
		Synth = { L(LAND, 1, 0.55), L(STEP, 0.5, 0.9, { Duration = 0.2 }) },
	},
	{
		Name = "TrapSnap",
		Group = "SFX",
		Volume = 1,
		MaxDistance = 160,
		MinDistance = 8,
		Priority = 3,
		Search = { Keywords = { "bear trap", "trap snap", "metal snap" }, Max = 2 },
		Synth = { L(LAND, 1, 2.8, { Distortion = 0.8 }), L(LAND, 0.7, 1.2, { Echo = { 0.05, 0.4 } }) },
	},
	{
		Name = "Bell",
		Group = "SFX",
		Volume = 1,
		MaxDistance = 200,
		MinDistance = 12,
		Priority = 3,
		Search = { Keywords = { "church bell", "bell toll", "bell ring" }, Min = 1, Max = 8 },
		Synth = { L(LAND, 1, 3, { Echo = { 0.25, 0.6 } }), L(LAND, 0.5, 1.5, { Echo = { 0.35, 0.6 } }) },
	},

	-- Крюки и Сущность
	{
		Name = "HookImpale",
		Group = "SFX",
		Volume = 1,
		MaxDistance = 120,
		MinDistance = 8,
		Priority = 3,
		Search = { Keywords = { "meat hook", "flesh stab", "impale" }, Max = 2.5 },
		Synth = {
			L(LAND, 0.9, 2.2, { Echo = { 0.06, 0.4 } }),
			L(SPLASH, 0.6, 0.7, { Distortion = 0.3, Duration = 0.5 }),
			L(LAND, 0.7, 0.5),
		},
	},
	{
		Name = "EntityDrone",
		Group = "SFX",
		Volume = 1,
		MaxDistance = 200,
		MinDistance = 15,
		Priority = 3,
		Search = { Keywords = { "horror riser", "dark whoosh", "demonic" }, Min = 1.5, Max = 8 },
		Synth = {
			L(FALL, 1, 0.15, { Duration = 3, Distortion = 0.8, Echo = { 0.4, 0.6 } }),
			L(SWIM, 0.4, 0.2, { Duration = 3, LowPass = 20 }),
		},
	},

	-- Генераторы и ворота
	{
		Name = "GenLoop",
		Group = "SFX",
		Volume = 0.55,
		Looped = true,
		MaxDistance = 60,
		MinDistance = 6,
		FadeIn = 0.5,
		FadeOut = 1,
		Search = { Keywords = { "generator running", "engine idle", "generator loop" }, Min = 2, Max = 60 },
		Synth = {
			L(SWIM, 0.7, 0.35, { Distortion = 0.5, LowPass = 14 }),
			L(FALL, 0.4, 0.5, { Tremolo = { 9, 0.7, 0.5 }, LowPass = 16 }),
		},
	},
	{
		Name = "GenDone",
		Group = "SFX",
		Volume = 1,
		Priority = 3,
		Search = { Keywords = { "power up", "machine power on", "generator start" }, Min = 0.8, Max = 6 },
		Synth = {
			L(LAND, 1, 0.3, { Echo = { 0.35, 0.5 }, Distortion = 0.3 }),
			L(FALL, 0.5, 0.8, { Duration = 1.2, LowPass = 8 }),
		},
	},
	{
		Name = "GenExplode",
		Group = "SFX",
		Volume = 1,
		MaxDistance = 300,
		MinDistance = 12,
		Priority = 3,
		Search = { Keywords = { "electric explosion", "short circuit", "spark explosion" }, Max = 4 },
		Synth = { L(SPLASH, 1, 0.45, { Distortion = 0.9 }), L(LAND, 0.8, 0.4, { Distortion = 0.5 }) },
	},
	{
		Name = "GatePowered",
		Group = "SFX",
		Volume = 0.9,
		Priority = 3,
		Search = { Keywords = { "siren alarm", "air raid siren", "alarm horn" }, Min = 2, Max = 12 },
		Synth = {
			L(FALL, 0.8, 0.6, { Duration = 2.5, Distortion = 0.6, Echo = { 0.3, 0.5 } }),
			L(SWIM, 0.5, 1.6, { Duration = 2.5, Distortion = 0.8, Tremolo = { 2, 1, 0.5 } }),
		},
	},
	{
		Name = "GateSiren",
		Group = "SFX",
		Volume = 0.7,
		Looped = true,
		MaxDistance = 160,
		MinDistance = 10,
		FadeIn = 0.3,
		FadeOut = 1,
		Search = { Keywords = { "alarm loop", "siren loop", "alarm bell" }, Min = 1, Max = 30 },
		Synth = { L(SWIM, 0.8, 1.6, { Distortion = 0.8, Tremolo = { 2, 1, 0.5 } }) },
	},
	{
		Name = "GateOpen",
		Group = "SFX",
		Volume = 1,
		MaxDistance = 300,
		MinDistance = 12,
		Priority = 3,
		Search = { Keywords = { "metal gate open", "heavy door open", "garage door" }, Min = 1, Max = 8 },
		Synth = { L(SWIM, 1, 0.25, { Duration = 2.5, Distortion = 0.7 }), L(LAND, 0.6, 0.35, { Delay = 2.2 }) },
	},

	-- Объекты карты
	{
		Name = "Clank",
		Group = "SFX",
		Volume = 1,
		MaxDistance = 100,
		MinDistance = 6,
		Priority = 2,
		Pitch = 0.05,
		Search = { Keywords = { "metal clank", "metal hit", "metal impact" }, Max = 2, Count = 2 },
		Synth = { L(LAND, 1, 2.2, { Echo = { 0.06, 0.4 } }) },
	},
	{
		Name = "PalletSlam",
		Group = "SFX",
		Volume = 1,
		MaxDistance = 140,
		MinDistance = 8,
		Priority = 3,
		Search = { Keywords = { "wood slam", "wooden impact", "wood crash" }, Max = 2.5 },
		Synth = { L(LAND, 1, 0.45, { Distortion = 0.4 }), L(STEP, 0.5, 0.6, { Duration = 0.25 }) },
	},
	{
		Name = "PalletBreak",
		Group = "SFX",
		Volume = 1,
		MaxDistance = 140,
		MinDistance = 8,
		Priority = 3,
		Search = { Keywords = { "wood break", "wood crack", "wood smash" }, Max = 3 },
		Synth = { L(SPLASH, 1, 1.6, { Distortion = 0.7 }), L(LAND, 0.6, 0.5) },
	},
	{
		Name = "Vault",
		Group = "SFX",
		Volume = 0.8,
		MaxDistance = 80,
		MinDistance = 6,
		Priority = 2,
		Pitch = 0.05,
		Search = { Keywords = { "jump land", "body fall", "vault" }, Max = 1.5 },
		Synth = { L(JUMP, 0.8, 0.9), L(LAND, 0.4, 0.8, { Delay = 0.3 }) },
	},
	{
		Name = "Rustle",
		Group = "SFX",
		Volume = 0.8,
		MaxDistance = 50,
		MinDistance = 4,
		Priority = 1,
		Pitch = 0.06,
		Search = { Keywords = { "cloth rustle", "clothes rustle", "fabric movement" }, Max = 2, Count = 2 },
		Synth = { L(GETUP, 1, 1) },
	},
	{
		Name = "LockerDoor",
		Group = "SFX",
		Volume = 0.9,
		MaxDistance = 80,
		MinDistance = 6,
		Priority = 2,
		Search = { Keywords = { "locker door", "metal door slam", "cabinet door" }, Max = 2 },
		Synth = { L(LAND, 1, 1.7, { Echo = { 0.05, 0.3 } }) },
	},
	{
		Name = "Chest",
		Group = "SFX",
		Volume = 0.9,
		MaxDistance = 60,
		MinDistance = 5,
		Priority = 2,
		Search = { Keywords = { "chest open", "wooden box open", "creak" }, Max = 3 },
		Synth = { L(GETUP, 1, 0.7), L(JUMP, 0.3, 0.4, { Delay = 0.1 }) },
	},
	{
		Name = "Click",
		Group = "SFX",
		Volume = 0.6,
		MaxDistance = 40,
		MinDistance = 3,
		Priority = 2,
		Search = { Keywords = { "flashlight click", "switch click", "click" }, Max = 0.6 },
		Synth = { L(STEP, 1, 3, { Duration = 0.12 }) },
	},

	-- Атмосфера
	{
		Name = "Wind",
		Group = "Ambience",
		Volume = 0.3,
		Looped = true,
		FadeIn = 3,
		FadeOut = 3,
		Search = { Keywords = { "wind howling", "wind ambience", "wind loop" }, Min = 10, Max = 120 },
		Synth = {
			L(FALL, 0.6, 0.3, { LowPass = 18 }),
			L(FALL, 0.35, 0.23, { Start = 0.7, LowPass = 22, Tremolo = { 0.15, 0.6, 0.5 } }),
		},
	},
	{
		Name = "NightInsects",
		Group = "Ambience",
		Volume = 0.25,
		Looped = true,
		FadeIn = 3,
		FadeOut = 3,
		Search = { Keywords = { "crickets night", "night insects", "crickets" }, Min = 10, Max = 120 },
		Synth = {
			L(STEP, 0.16, 4.2, { Tremolo = { 9, 1, 0.3 }, HighPass = 10 }),
			L(SWIM, 0.1, 3.4, { HighPass = 14, Tremolo = { 6, 0.8, 0.5 } }),
		},
	},
	{
		Name = "Campfire",
		Group = "Ambience",
		Volume = 0.7,
		Looped = true,
		MaxDistance = 40,
		MinDistance = 4,
		FadeIn = 1,
		FadeOut = 1,
		Search = { Keywords = { "campfire crackling", "fire crackling", "fireplace" }, Min = 5, Max = 120 },
		Synth = {
			L(FALL, 0.45, 0.6, { LowPass = 14 }),
			L(SWIM, 0.18, 2.4, { Distortion = 0.6, Tremolo = { 7, 0.7, 0.4 } }),
		},
	},
	{
		Name = "Crow",
		Group = "Ambience",
		Volume = 0.8,
		MaxDistance = 160,
		MinDistance = 10,
		Priority = 2,
		Pitch = 0.05,
		Search = { Keywords = { "crow caw", "crow", "raven" }, Max = 3, Count = 3 },
		Synth = { L(OOF, 1, 2.8, { Distortion = 0.9 }), L(OOF, 0.7, 2.6, { Delay = 0.3, Distortion = 0.9 }) },
	},
	{
		Name = "Flutter",
		Group = "Ambience",
		Volume = 0.7,
		MaxDistance = 80,
		MinDistance = 6,
		Priority = 1,
		Search = { Keywords = { "wings flapping", "bird flap", "bird flying away" }, Max = 3 },
		Synth = { L(FALL, 1, 4, { Duration = 0.6 }) },
	},
	{
		Name = "Thunder",
		Group = "Ambience",
		Volume = 0.7,
		Priority = 2,
		Search = { Keywords = { "distant thunder", "thunder rumble", "thunder" }, Min = 2, Max = 15, Count = 2 },
		Synth = {
			L(LAND, 0.9, 0.18, { Distortion = 0.5, LowPass = 20 }),
			L(FALL, 0.7, 0.12, { Duration = 4, LowPass = 24, Echo = { 0.4, 0.5 } }),
		},
	},
	{
		Name = "HatchWind",
		Group = "Ambience",
		Volume = 0.6,
		Looped = true,
		MaxDistance = 45,
		MinDistance = 5,
		FadeIn = 1,
		FadeOut = 1,
		Search = { Keywords = { "eerie wind", "wind tunnel", "wind whistle" }, Min = 3, Max = 120 },
		Synth = { L(FALL, 1, 0.5, { Echo = { 0.2, 0.4 } }) },
	},
	{
		-- Музыка лобби у костра (без синтеза: если не найдена — тишина и треск костра)
		Name = "AmbientMusic",
		Group = "Music",
		Volume = 0.35,
		Looped = true,
		FadeIn = 3,
		FadeOut = 3,
		Search = { Keywords = { "dark ambient", "eerie ambient", "horror ambience" }, Music = true, Min = 60, Max = 240 },
	},

	-- Интерфейс
	{
		Name = "SkillWarn",
		Group = "UI",
		Volume = 0.8,
		Priority = 3,
		Search = { Keywords = { "ding", "bell ding", "alert ding" }, Max = 1.5 },
		Synth = { L(LAND, 1, 3.5, { Echo = { 0.08, 0.2 } }) },
	},
	{
		Name = "SkillGood",
		Group = "UI",
		Volume = 0.8,
		Priority = 3,
		Search = { Keywords = { "success", "ui confirm", "correct" }, Max = 1 },
		Synth = { L(STEP, 1, 2, { Duration = 0.2 }) },
	},
	{
		Name = "UiClick",
		Group = "UI",
		Volume = 0.5,
		Priority = 2,
		Search = { Keywords = { "ui click", "button click", "click" }, Max = 0.5 },
		Synth = { L(STEP, 0.7, 2.6, { Duration = 0.1 }) },
	},
	{
		Name = "Notify",
		Group = "UI",
		Volume = 0.4,
		Priority = 2,
		Search = { Keywords = { "notification", "ui notification", "soft ding" }, Max = 1.5 },
		Synth = { L(STEP, 1, 1.5, { Duration = 0.25 }) },
	},
} :: { Def }

Sounds.Defs = {} :: { [string]: Def }
for _, def in Sounds.List do
	Sounds.Defs[def.Name] = def
end

------------------------------------------------------------------------
-- Найденные звуки и выбор источника
------------------------------------------------------------------------

Sounds.Library = {} :: { [string]: { string } } -- слот -> проверенные ID из библиотеки
Sounds.Failed = {} :: { [string]: boolean } -- ID, которые не загрузились

local cache: { [string]: Resolved | false } = {}

-- "rbxassetid://1,rbxassetid://2" <-> { ... } (так ID лежат в атрибутах папки SoundLibrary)
function Sounds.encodeIds(ids: { string }): string
	return table.concat(ids, ",")
end

-- Строка ("id1,id2"), число или список -> список ID; голое число становится rbxassetid://
function Sounds.parseIds(value: any): { string }
	local out = {}
	local function add(id: any)
		if type(id) == "number" then
			id = string.format("%d", id)
		end
		if type(id) == "string" then
			for token in id:gmatch("[^,%s]+") do
				table.insert(out, if token:match("^%d+$") then "rbxassetid://" .. token else token)
			end
		end
	end
	if type(value) == "table" then
		for _, id in value do
			add(id)
		end
	else
		add(value)
	end
	return out
end

function Sounds.setLibrary(name: string, ids: { string })
	Sounds.Library[name] = if #ids > 0 then ids else nil
	table.clear(cache)
end

function Sounds.markFailed(id: string)
	Sounds.Failed[id] = true
	table.clear(cache)
end

local function usable(ids: { string }): { string }
	local out = {}
	for _, id in ids do
		if not Sounds.Failed[id] then
			table.insert(out, id)
		end
	end
	return out
end

local function fromIds(def: Def, source: string, ids: { string }): Resolved
	local variants = {}
	for _, id in ids do
		table.insert(variants, { { Id = id, Volume = 1, Speed = 1 } :: Layer })
	end
	return { Name = def.Name, Def = def, Source = source, Variants = variants }
end

-- Синтез: Variants ступеней высоты вокруг исходной (каждая — отдельный вариант)
local function fromSynth(def: Def, layers: { Layer }): Resolved
	local count = def.Variants or 1
	local variants = {}
	for k = 1, count do
		local shift = 1 + (k - (count + 1) / 2) * 0.05
		local variant = {}
		for _, layer in layers do
			local copy = table.clone(layer)
			copy.Speed = layer.Speed * shift
			table.insert(variant, copy)
		end
		table.insert(variants, variant)
	end
	return { Name = def.Name, Def = def, Source = "Synth", Variants = variants }
end

local function resolve(def: Def): Resolved?
	local override = usable(Sounds.parseIds(Config.SoundOverrides[def.Name]))
	if #override > 0 then
		return fromIds(def, "Override", override)
	end
	local found = usable(Sounds.Library[def.Name] or {})
	if #found > 0 then
		return fromIds(def, "Library", found)
	end
	if def.Synth then
		return fromSynth(def, def.Synth)
	end
	if def.Melody then
		return fromSynth(def, { def.Melody.Layer })
	end
	return nil
end

-- Звук слота с учётом порядка выбора. nil — у слота нет ни одного источника.
function Sounds.get(name: string): Resolved?
	local hit = cache[name]
	if hit == nil then
		local def = Sounds.Defs[name]
		hit = def and resolve(def) or false
		cache[name] = hit
	end
	return hit or nil
end

return Sounds
