-- Предметы выживших из сундуков.
local Config = require(script.Parent.Config)

return {
	Medkit = {
		Name = "Аптечка",
		Hint = "ПКМ/R (держать) — вылечить себя",
		Charges = Config.MedkitCharges,
		Color = Color3.fromRGB(200, 40, 40),
	},
	Toolbox = {
		Name = "Ящик с инструментами",
		Hint = "Ремонт генераторов на 50% быстрее",
		Charges = Config.ToolboxCharges,
		Color = Color3.fromRGB(60, 110, 200),
	},
	Flashlight = {
		Name = "Фонарик",
		Hint = "ПКМ/R (держать) — светить маньяку в лицо",
		Charges = Config.FlashlightCharges,
		Color = Color3.fromRGB(230, 220, 120),
	},
}
