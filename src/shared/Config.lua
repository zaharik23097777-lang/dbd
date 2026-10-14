-- Все настройки игры в одном месте. Меняй числа, чтобы настроить баланс.
local Config = {}

-- Лобби / раунд
Config.MinPlayers = 2 -- минимум игроков для старта (1 маньяк + 1 выживший)
Config.StudioMinPlayers = 1 -- в Studio можно тестировать одному (будешь выжившим)
Config.LobbyCountdown = 15
Config.ResultsTime = 14
Config.MaxRoundTime = 20 * 60
Config.IntroTime = 3 -- затемнение в начале раунда

-- Генераторы
Config.GeneratorCount = 7
Config.GeneratorsRequired = 5
Config.GeneratorRepairTime = 80 -- секунд одному выжившему
Config.GeneratorKickRegression = 0.08
Config.GeneratorRegressPerSecond = 0.0025
Config.RuinRegressPerSecond = 0.004 -- Проклятие: Руина

-- Проверки навыка (skill check)
Config.SkillCheckChancePerSecond = 0.10
Config.SkillCheckDuration = 1.1 -- полный оборот стрелки
Config.SkillCheckGreatBonus = 0.02
Config.SkillCheckFailPenalty = 0.10

-- Скорости (стандартная WalkSpeed в Roblox = 16)
Config.SurvivorWalkSpeed = 10
Config.SurvivorSprintSpeed = 16
Config.SurvivorCrouchSpeed = 5
Config.SurvivorCrawlSpeed = 2.5
Config.SurvivorHitBoostSpeed = 22
Config.SurvivorHitBoostTime = 1.8
Config.KillerCarrySpeed = 16.4
Config.KillerLungeSpeed = 26
Config.KillerLungeTime = 0.35

-- Атака маньяка
Config.AttackRange = 7
Config.AttackCooldownHit = 2.7
Config.AttackCooldownMiss = 1.5
Config.AttackSlowSpeed = 6

-- Действия (секунды)
Config.HealTime = 16
Config.UnhookTime = 1.2
Config.HookTime = 1.2
Config.BreakPalletTime = 2.6
Config.KickGeneratorTime = 1.8
Config.OpenGateTime = 18
Config.CleanseTime = 12
Config.ChestTime = 5
Config.SearchLockerTime = 0.9
Config.CloseHatchTime = 1.5
Config.InteractRange = 7

-- Крюки
Config.HookStageTime = 60
Config.MaxHooks = 3
Config.WiggleTime = 16
Config.BleedOutTime = 240

-- Паллеты
Config.PalletStunTime = 2.2
Config.PalletStunRange = 7

-- Эндгейм и люк
Config.EndGameCollapseTime = 120

-- Предметы
Config.MedkitHealTime = 12 -- сколько лечиться аптечкой
Config.MedkitCharges = 24 -- секунд использования
Config.ToolboxCharges = 30
Config.ToolboxBonus = 0.5 -- +50% к скорости ремонта
Config.FlashlightCharges = 12
Config.FlashlightBlindTime = 0.9 -- сколько светить в лицо, чтобы ослепить
Config.FlashlightRange = 16
Config.FlashlightAngle = 14 -- градусов
Config.BlindDuration = 2.5
Config.ChestItemWeights = { Medkit = 40, Toolbox = 35, Flashlight = 25 }

-- Радиус ужаса и звук
-- Порядок выбора звука: SoundOverrides -> найденный в библиотеке Creator Store -> встроенный синтез.
Config.SoundOverrides = {
	-- Сюда можно вставить ID звуков из Toolbox (вкладка Audio): число, "rbxassetid://..." или список вариантов:
	-- Heartbeat = "rbxassetid://1234567",
	-- ChaseMusic = "rbxassetid://...",
	-- FootstepDirt = { "rbxassetid://...", "rbxassetid://..." },
	-- Имена всех слотов — в src/shared/Sounds.lua
}
Config.SoundLibraryEnabled = true -- искать настоящие звуки (AssetService:SearchAudioAsync) при старте сервера
Config.SoundSearchTimeLimit = 120 -- секунд на весь поиск, дальше — встроенные звуки
Config.SoundSearchWorkers = 2 -- сколько запросов поиска идёт одновременно
Config.SoundSearchRetries = 2 -- повторов при ошибке (с нарастающей паузой)
Config.SoundSearchInterval = 0.5 -- секунд между запросами поиска (на весь сервер), чтобы не упереться в лимит
Config.SoundLoadTimeout = 10 -- секунд на загрузку найденного звука на клиенте, иначе — встроенный
Config.MaxSounds = 36 -- одновременно звучащих одноразовых звуков на ПК
Config.MaxSoundsMobile = 18 -- то же на телефонах и планшетах
Config.SoundGroupVolumes = { Master = 1, SFX = 1, Ambience = 0.75, Music = 0.7, Voice = 1, UI = 0.8 }
Config.ChaseDistance = 26

-- Вид маньяка от первого лица, как в оригинале
Config.KillerFirstPerson = true

-- Карта
Config.MapSize = 220
Config.LobbyPosition = Vector3.new(0, 400, 0)

-- Очки крови
Config.ScoreCategoryCap = 8000
Config.SaveBloodpoints = true -- сохраняются в DataStore (работает в опубликованной игре)

return Config
