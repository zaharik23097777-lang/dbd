-- Сборник шаблонов объектов карты. Каждый объект живёт в своём модуле Art/Props/<Имя>.lua,
-- который возвращает { Templates = { <Имя> = { Variants, Build(rng, variant) } }, ... }.
local Props = script.Parent.Props

local MapProps = {}
MapProps.Templates = {}

for _, name in { "Generator", "Hook", "Pallet", "Locker", "Totem", "Chest", "Hatch", "Trap", "Crow", "ExitGate" } do
	local mod = require(Props:FindFirstChild(name) :: ModuleScript)
	for templateName, def in mod.Templates do
		MapProps.Templates[templateName] = def
	end
end

-- Лапы Сущности вокруг висящего на крюке (hangPoint — мировой CFrame точки HangPoint)
MapProps.entityLegs = require(Props.Hook).entityLegs

return MapProps
