-- Оформление ячеек: петли с паллетой/окном, укрытие у генератора, шкафчики (DressingLoops) и
-- свалка, бочки, сено, надгробия, забор, фонарь (DressingProps).
-- Функции получают map, cf (центр ячейки 22x22, -Z = «перед») и rng.
local Loops = require(script.Parent.DressingLoops)
local Props = require(script.Parent.DressingProps)

local Dressing = {}
for _, mod in { Loops, Props } do
	for k, v in mod do
		Dressing[k] = v
	end
end

return Dressing
