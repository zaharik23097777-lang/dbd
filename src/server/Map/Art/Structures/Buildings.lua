-- Здания: хижина маньяка (центр карты), дом из двух комнат, внешняя стена карты.
-- Функции получают map (папки и списки точек из MapBuilder), cf (центр ячейки 22x22, -Z = «перед») и rng.
-- Построение — в BuildingShack / BuildingHouse / BuildingPerimeter, общие помощники стен — BuildingWalls.
local Buildings = {}

Buildings.shack = require(script.Parent.BuildingShack)
Buildings.house = require(script.Parent.BuildingHouse)
Buildings.outerWalls = require(script.Parent.BuildingPerimeter)

return Buildings
