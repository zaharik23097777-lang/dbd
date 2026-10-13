-- Общие игровые помощники для построек (НЕ художественные — их не меняем):
-- паллета и шкафчик из шаблонов, подоконник окна с правильной высотой.
local Templates = require(script.Parent.Parent.Templates)

local Common = {}

-- Паллета: upCF — положение хитбокса в поднятом состоянии, dropCF — опущенная паллета поперёк проёма
-- (хитбокс 5.6x3x1.2, длинная сторона по локальной X, проход — вдоль локальной Z).
function Common.pallet(map, rng: Random, upCF: CFrame, dropCF: CFrame): Model
	local pallet = Templates.spawn("Pallet", upCF, map.Pallets, rng)
	pallet:SetAttribute("DropCFrame", dropCF)
	return pallet
end

-- Шкафчик: cf — пол, дверь смотрит в -Z (перед дверью нужно ~3 стада свободного места)
function Common.locker(map, rng: Random, cf: CFrame): Model
	return Templates.spawn("Locker", cf, map.Lockers, rng)
end

-- Подоконник окна, через который перелезают вдоль локальной Z.
-- cf — центр проёма на уровне земли (y = 0), width — ширина проёма, thick — толщина стены.
-- Возвращает деталь подоконника (Kind = "Window", высота ровно 3).
function Common.windowSill(map, cf: CFrame, width: number, thick: number, color: Color3?, material: Enum.Material?): BasePart
	local sill = Instance.new("Part")
	sill.Name = "Window"
	sill.Anchored = true
	sill.TopSurface = Enum.SurfaceType.Smooth
	sill.BottomSurface = Enum.SurfaceType.Smooth
	sill.Size = Vector3.new(width, 3, thick)
	sill.CFrame = cf * CFrame.new(0, 1.5, 0)
	sill.Color = color or Color3.fromRGB(75, 60, 45)
	sill.Material = material or Enum.Material.Wood
	sill:SetAttribute("Kind", "Window")
	sill.Parent = map.Windows
	return sill
end

return Common
