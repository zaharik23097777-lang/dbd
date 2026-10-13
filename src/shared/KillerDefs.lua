-- Маньяки: характеристики и способности.
local KillerDefs = {}

KillerDefs.Order = { "Trapper", "Huntress", "Wraith" }

KillerDefs.Trapper = {
	Id = "Trapper",
	Name = "Траппер",
	Description = "Ставит медвежьи капканы. Пойманный выживший ранен и не может уйти.",
	PowerName = "Медвежий капкан",
	PowerHint = "ПКМ/Q (держать) — поставить капкан",
	Speed = 18.4,
	TerrorRadius = 32,
	Scale = 1.15,
	BodyColor = Color3.fromRGB(92, 70, 58),
	ClothColor = Color3.fromRGB(55, 45, 40),
	TrapsOnMap = 4, -- разложены на карте в начале
	TrapsInHand = 1,
	MaxTrapsInHand = 2,
	TrapEscapeChance = 0.25,
}

KillerDefs.Huntress = {
	Id = "Huntress",
	Name = "Охотница",
	Description = "Метает топоры на расстояние. Пополняет запас в шкафчиках. Её выдаёт колыбельная.",
	PowerName = "Охотничьи топоры",
	PowerHint = "ПКМ/Q (держать и отпустить) — бросить топор",
	Speed = 17.6,
	TerrorRadius = 22,
	Lullaby = true,
	Scale = 1.25,
	BodyColor = Color3.fromRGB(150, 120, 100),
	ClothColor = Color3.fromRGB(95, 60, 40),
	MaxHatchets = 5,
	MinWindup = 0.45,
	FullWindup = 1.3,
	WindupSpeed = 9,
	ThrowSpeedMin = 70,
	ThrowSpeedMax = 120,
	Gravity = 40,
}

KillerDefs.Wraith = {
	Id = "Wraith",
	Name = "Призрак",
	Description = "Звонит в колокол и становится почти невидимым и быстрым, но не может бить.",
	PowerName = "Колокол Ваиль",
	PowerHint = "ПКМ/Q — невидимость вкл/выкл",
	Speed = 18.4,
	TerrorRadius = 32,
	Scale = 1.15,
	BodyColor = Color3.fromRGB(70, 70, 72),
	ClothColor = Color3.fromRGB(120, 110, 95),
	CloakTime = 1.5,
	UncloakTime = 1.0,
	CloakedSpeed = 24,
	UncloakBoostSpeed = 22,
	UncloakBoostTime = 1.5,
}

function KillerDefs.get(id: string?)
	return KillerDefs[id or "Trapper"] or KillerDefs.Trapper
end

return KillerDefs
