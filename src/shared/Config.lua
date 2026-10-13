-- Все настройки игры в одном месте. Меняй числа, чтобы настроить баланс.
local Config = {}

-- Лобби / раунд
Config.MinPlayers = 2 -- минимум игроков для старта (1 маньяк + 1 выживший)
Config.StudioMinPlayers = 1 -- в Studio можно тестировать одному (будешь выжившим)
Config.LobbyCountdown = 15 -- секунд отсчёта перед раундом
Config.ResultsTime = 10 -- секунд показа результатов
Config.MaxRoundTime = 15 * 60 -- жёсткий лимит раунда

-- Генераторы
Config.GeneratorCount = 7 -- сколько генераторов на карте
Config.GeneratorsRequired = 5 -- сколько нужно починить
Config.GeneratorRepairTime = 80 -- секунд на ремонт одним выжившим
Config.GeneratorKickRegression = 0.08 -- сколько прогресса теряет генератор при пинке маньяка
Config.GeneratorRegressPerSecond = 0.0025 -- регресс после пинка (доля в секунду)

-- Проверки навыка (skill check)
Config.SkillCheckChancePerSecond = 0.10
Config.SkillCheckDuration = 1.1 -- время пробега стрелки
Config.SkillCheckGreatBonus = 0.02
Config.SkillCheckFailPenalty = 0.10

-- Скорости (стандартная WalkSpeed в Roblox = 16)
Config.SurvivorWalkSpeed = 10
Config.SurvivorSprintSpeed = 16
Config.SurvivorCrawlSpeed = 2.5
Config.SurvivorHitBoostSpeed = 22 -- рывок после удара
Config.SurvivorHitBoostTime = 1.8
Config.KillerSpeed = 18.4 -- 115% от бега выжившего
Config.KillerCarrySpeed = 16.4
Config.KillerLungeSpeed = 26
Config.KillerLungeTime = 0.35

-- Атака маньяка
Config.AttackRange = 7
Config.AttackCooldownHit = 2.7 -- маньяк вытирает оружие после попадания
Config.AttackCooldownMiss = 1.5
Config.AttackSlowSpeed = 6

-- Действия (секунды)
Config.HealTime = 16
Config.UnhookTime = 1.2
Config.HookTime = 1.2
Config.PickupTime = 0
Config.BreakPalletTime = 2.6
Config.KickGeneratorTime = 1.8
Config.OpenGateTime = 18
Config.InteractRange = 7

-- Крюки
Config.HookStageTime = 60 -- секунд на каждой стадии крюка
Config.MaxHooks = 3 -- на 3-м крюке выживший сразу погибает
Config.WiggleTime = 16 -- сколько нужно вырываться из рук маньяка
Config.BleedOutTime = 240 -- сколько можно лежать на земле до смерти

-- Паллеты
Config.PalletStunTime = 2.2
Config.PalletStunRange = 7

-- Эндгейм
Config.EndGameCollapseTime = 120 -- после открытия ворот

-- Радиус ужаса (сердцебиение)
Config.TerrorRadius = 32
Config.HeartbeatSoundId = "" -- можно вставить "rbxassetid://<id>" звука сердцебиения
Config.ChaseMusicId = "" -- музыка погони (необязательно)

-- Вид маньяка от первого лица, как в оригинале
Config.KillerFirstPerson = true

-- Карта
Config.MapSize = 220
Config.LobbyPosition = Vector3.new(0, 400, 0)

return Config
