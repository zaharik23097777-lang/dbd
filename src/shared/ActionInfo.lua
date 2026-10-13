-- Описание всех действий: кто может, какая кнопка, подпись, дальность.
-- Используется и сервером (проверки), и клиентом (подсказки).
local Config = require(script.Parent.Config)

local R = Config.InteractRange

return {
	-- Выжившие, кнопка E (держать)
	Repair = { Role = "Survivor", Key = "E", Range = R, Label = "Чинить генератор" },
	Heal = { Role = "Survivor", Key = "E", Range = R, Label = "Лечить" },
	Unhook = { Role = "Survivor", Key = "E", Range = R, Label = "Снять с крюка", Duration = Config.UnhookTime },
	OpenGate = { Role = "Survivor", Key = "E", Range = R, Label = "Открыть ворота" },
	Cleanse = { Role = "Survivor", Key = "E", Range = R, Label = "Очистить тотем" },
	OpenChest = { Role = "Survivor", Key = "E", Range = R, Label = "Открыть сундук", Duration = Config.ChestTime },
	JumpHatch = { Role = "Survivor", Key = "E", Range = 5, Label = "Прыгнуть в люк", Instant = true },
	EscapeTrap = { Role = "Survivor", Key = "E", Range = 3, Label = "Вырваться из капкана", Duration = 1.4 },
	FreeTrap = { Role = "Survivor", Key = "E", Range = R, Label = "Освободить из капкана", Duration = 3 },
	DisarmTrap = { Role = "Survivor", Key = "E", Range = 5, Label = "Обезвредить капкан", Duration = 2.5 },
	SelfHeal = { Role = "Survivor", Key = "Item", Range = 1000, Label = "Лечение аптечкой" },

	-- Выжившие, кнопка Пробел
	DropPallet = { Role = "Survivor", Key = "Space", Range = R, Label = "Опустить паллету", Instant = true },
	Vault = { Role = "Any", Key = "Space", Range = 4.5, Label = "Перелезть", Instant = true },
	EnterLocker = { Role = "Survivor", Key = "Space", Range = 4.5, Label = "Спрятаться в шкафчик", Instant = true },
	ExitLocker = { Role = "Survivor", Key = "Space", Range = 1000, Label = "Выйти из шкафчика", Instant = true },

	-- Маньяк, кнопка E
	Pickup = { Role = "Killer", Key = "E", Range = R, Label = "Поднять", Instant = true },
	Hook = { Role = "Killer", Key = "E", Range = R, Label = "Повесить на крюк", Duration = Config.HookTime },
	Break = { Role = "Killer", Key = "E", Range = R, Label = "Сломать паллету", Duration = Config.BreakPalletTime },
	Kick = { Role = "Killer", Key = "E", Range = R, Label = "Повредить генератор", Duration = Config.KickGeneratorTime },
	SearchLocker = { Role = "Killer", Key = "E", Range = 5, Label = "Обыскать шкафчик", Duration = Config.SearchLockerTime },
	CloseHatch = { Role = "Killer", Key = "E", Range = 5, Label = "Закрыть люк", Duration = Config.CloseHatchTime },
	PickupTrap = { Role = "Killer", Key = "E", Range = 5, Label = "Забрать капкан", Duration = 1.2 },
	ResetTrap = { Role = "Killer", Key = "E", Range = 5, Label = "Взвести капкан", Duration = 1.5 },
	SetTrap = { Role = "Killer", Key = "Power", Range = 1000, Label = "Ставим капкан", Duration = 2.2 },
}
