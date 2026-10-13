-- Постройки. Модули: Buildings (здания, внешняя стена), Dressing (оформление ячеек), Common (игровые помощники).
-- Правила геймплея для всех построек:
--   * ничего твёрдого дальше ±10.5 от центра ячейки 22x22;
--   * паллета — Common.pallet, окно — Common.windowSill, шкафчик — Common.locker;
--   * стены «петель» и зданий ≥ 7 в высоту (закрывают обзор), проходы ≥ 5 шириной;
--   * точки для системы: map.TrapSpots / CrowSpots / ChestSpots / TotemSpots (CFrame).
local Common = require(script.Common)
local Buildings = require(script.Buildings)
local Dressing = require(script.Dressing)

local Structures = {}
for _, mod in { Common, Buildings, Dressing } do
	for k, v in mod do
		Structures[k] = v
	end
end

return Structures
