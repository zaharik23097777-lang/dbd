-- Ворота выхода: бетонная проходная (пилоны с цоколем и оголовком, ригель с двутавром), большая рифлёная
-- откатная дверь на роликах (уезжает вбок за правый пилон, в карман снаружи стены), щиток с рычагом,
-- тремя лампами и лампой питания, сирена на левом пилоне, коридор наружу и зона побега.
-- Опора — центр проёма на линии стены (стена карты: |x| >= 8, z = -1..1, высота 16); -Z внутрь карты, +Z наружу.
-- Проём 12 стад (x = -6..6), закрытая дверь его перекрывает; зона побега — там же, где и раньше.
-- Требования — Art/Contract.lua; подвижные части — Kit.movable (см. Map/PropFX.lua).
-- Switch, EscapeZone — прямые потомки модели (их ищут FindFirstChild без рекурсии).
local Kit = require(script.Parent.Parent.Kit)

local P = Kit.Palette
local Mat = Kit.Mat
local A = Kit.A
local V = Vector3.new
local C = CFrame.new

local M = {}
local T = {}
M.Templates = T

local SOLID = { CanCollide = false, CanQuery = false, CanTouch = false }
local DECOR = { Decor = true }

local SLIDE = V(12.6, 0, 0) -- куда уезжает дверь при открытии
local DOOR_Z = 1.85 -- плоскость полотна двери (снаружи стены)
local PILLAR_X, PILLAR_Z = 7.8, -0.6 -- центры пилонов (x = 6..9.6, z = -2.4..1.2)
local PILLAR_SIZE = V(3.6, 18.5, 3.6) -- выше стены и ригеля: проходную видно издалека

type Look = {
	Pillar: Color3,
	PillarMat: Enum.Material,
	Door: Color3,
	DoorMat: Enum.Material,
	Wire: boolean, -- колючая проволока на ригеле
	Cables: boolean, -- провисшие кабели между пилонами
}

local LOOKS: { Look } = {
	{ Pillar = P.Concrete, PillarMat = Mat.Concrete, Door = Color3.fromRGB(62, 66, 68), DoorMat = Mat.DiamondPlate, Wire = true, Cables = false },
	{ Pillar = Color3.fromRGB(104, 62, 50), PillarMat = Mat.Brick, Door = Color3.fromRGB(96, 60, 42), DoorMat = Mat.CorrodedMetal, Wire = false, Cables = true },
}

------------------------------------------------------------------------
-- Проходная
------------------------------------------------------------------------

-- Пилоны с цоколем, оголовком, облупленной штукатуркой и арматурой; ригель над проёмом
local function gatehouse(m: Model, rng: Random, look: Look): BasePart
	local concrete = Kit.jitter(P.Concrete, 0.03, rng)
	local lintel = Kit.box(m, C(0, 14.7, -0.6), V(19.2, 3.4, 3.2), Kit.jitter(P.DarkConcrete, 0.03, rng), Mat.Concrete)
	lintel.Name = "Frame"
	Kit.box(m, C(0, 16.58, -0.6), V(19.6, 0.35, 3.6), concrete, Mat.Concrete, SOLID)
	Kit.rustStreaks(lintel, Enum.NormalId.Front, rng, 7, Kit.dark(P.DarkRust, 0.2))
	for _, sx in { -1, 1 } do
		local x = sx * PILLAR_X
		local pillar = Kit.box(m, C(x, PILLAR_SIZE.Y / 2, PILLAR_Z), PILLAR_SIZE, Kit.jitter(look.Pillar, 0.04, rng), look.PillarMat)
		Kit.grime(pillar, Enum.NormalId.Front, 0.75)
		Kit.rustStreaks(pillar, Enum.NormalId.Front, rng, 3, Kit.dark(P.DarkConcrete, 0.3))
		local plinth = Kit.box(m, C(sx * 7.9, 0.6, PILLAR_Z), V(3.8, 1.2, 4.0), Kit.dark(concrete, 0.18), Mat.Concrete, SOLID)
		Kit.hazardStripes(plinth, Enum.NormalId.Front, Kit.dark(P.Warning, 0.35), 4)
		Kit.box(m, C(x, PILLAR_SIZE.Y + 0.25, PILLAR_Z), V(4.0, 0.5, 4.0), concrete, Mat.Concrete, SOLID)
		Kit.box(m, C(x, PILLAR_SIZE.Y + 0.65, PILLAR_Z), V(3.0, 0.3, 3.0), Kit.dark(concrete, 0.08), Mat.Concrete, DECOR)
		Kit.box(m, C(x, 7, PILLAR_Z), V(3.8, 0.4, 3.8), concrete, Mat.Concrete, DECOR)
		-- Отвалившийся кусок облицовки: под ним старая кладка (на кирпичном пилоне — бетон)
		local patch = look.PillarMat == Mat.Brick and Mat.Concrete or Mat.Brick
		local patchColor = patch == Mat.Brick and Kit.jitter(P.Brick, 0.05, rng) or Kit.dark(concrete, 0.1)
		Kit.box(m, C(x + sx * rng:NextNumber(-0.4, 0.4), rng:NextNumber(4.5, 9), PILLAR_Z - 1.82) * A(0, 0, rng:NextNumber(-8, 8)), V(1.5, 2.2, 0.06), patchColor, patch, DECOR)
	end
	-- Арматура из обломанного угла правого пилона
	for i = 0, 1 do
		local base = V(PILLAR_X + 1.2 - i * 0.5, PILLAR_SIZE.Y + 0.4, -2.1 + i * 0.3)
		Kit.rod(m, base, base + V(0.3 + i * 0.2, 1.1 - i * 0.3, -0.25), 0.1, P.Rust, Mat.CorrodedMetal, DECOR)
	end
	-- Стальной двутавр над проёмом и трафаретная табличка
	local header = Kit.box(m, C(0, 12.6, -2.3), V(12.6, 0.8, 0.5), Kit.jitter(P.DarkSteel, 0.04, rng), Mat.Metal, SOLID)
	Kit.hazardStripes(header, Enum.NormalId.Front, Kit.dark(P.Warning, 0.3), 8)
	local sign = Kit.box(m, C(0, 14.9, -2.24) * A(0, 0, -2), V(4.2, 1.3, 0.08), Kit.jitter(Color3.fromRGB(120, 116, 100), 0.05, rng), Mat.Metal, DECOR)
	Kit.label(sign, Enum.NormalId.Front, "EXIT", Color3.fromRGB(70, 22, 18))
	-- Контрфорс у левого пилона со стороны карты (справа место занимает щиток)
	Kit.wedge(m, C(-10.4, 3.5, -2.5), V(1.6, 7, 3), Kit.jitter(P.DarkConcrete, 0.04, rng), Mat.Concrete)
	return lintel
end

------------------------------------------------------------------------
-- Откатная дверь
------------------------------------------------------------------------

-- Полотно с рёбрами, ригелями, раскосами, подвесами и роликами; всё — группа GateDoor
local function door(m: Model, rng: Random, look: Look)
	local function slide(part: BasePart?)
		if part then
			Kit.movable(m, part, "GateDoor", part.CFrame, part.CFrame + SLIDE)
		end
	end
	local color = Kit.jitter(look.Door, 0.04, rng)
	local plate = Kit.box(m, C(0, 6, DOOR_Z), V(12, 12, 0.3), color, look.DoorMat)
	plate.Name = "Door"
	Kit.rustStreaks(plate, Enum.NormalId.Front, rng, 9)
	Kit.grime(plate, Enum.NormalId.Front, 0.7)
	slide(plate)
	local ribZ = DOOR_Z - 0.275
	for i = -3, 3 do
		slide(Kit.box(m, C(i * 1.7, 6, ribZ), V(0.42, 11.4, 0.25), Kit.dark(color, 0.22), Mat.Metal, DECOR))
	end
	for _, y in { 0.6, 6, 11.4 } do
		local rail = Kit.box(m, C(0, y, ribZ - 0.225), V(12, 0.45, 0.2), Kit.dark(color, 0.32), Mat.Metal, DECOR)
		if y < 1 then
			Kit.hazardStripes(rail, Enum.NormalId.Front, Kit.dark(P.Warning, 0.25), 10)
		end
		slide(rail)
	end
	-- Раскосы в двух полях между ригелями
	for _, y in { 3.3, 8.7 } do
		slide(Kit.bar(m, V(-5.6, y - 2.4, ribZ - 0.25), V(5.6, y + 2.4, ribZ - 0.25), 0.3, Kit.dark(color, 0.28), Mat.Metal, DECOR, 0.16))
	end
	-- Ручка у переднего края, подвесы и ролики на рельсе
	slide(Kit.box(m, C(-5.4, 4.2, ribZ - 0.45), V(0.16, 1.6, 0.16), P.Iron, Mat.Metal, DECOR))
	for _, x in { -4, 4 } do
		slide(Kit.box(m, C(x, 12.9, DOOR_Z - 0.3), V(0.5, 1.9, 0.12), P.DarkSteel, Mat.Metal, DECOR))
		slide(Kit.cyl(m, C(x, 13.7, DOOR_Z) * A(0, 90, 0), 0.3, 0.5, P.Iron, Mat.Metal, DECOR))
	end
end

-- Рельс над проёмом (снаружи, на кронштейнах) и карман, куда уезжает дверь
local function track(m: Model, rng: Random)
	local steel = Kit.jitter(P.DarkSteel, 0.04, rng)
	Kit.box(m, C(7.1, 13.32, DOOR_Z), V(26.2, 0.25, 0.45), steel, Mat.Metal, SOLID)
	for _, x in { -3, 7.8, 17 } do
		Kit.box(m, C(x, 13.45, 1.4), V(0.35, 0.5, 0.9), Kit.dark(steel, 0.2), Mat.Metal, DECOR)
	end
	local sheet = Kit.jitter(Color3.fromRGB(84, 78, 70), 0.05, rng)
	Kit.box(m, C(13.3, 7, 2.55), V(14.6, 14, 0.3), sheet, Mat.CorrodedMetal)
	Kit.box(m, C(20.7, 7, 1.8), V(0.6, 14, 1.8), Kit.dark(sheet, 0.2), Mat.CorrodedMetal)
	Kit.box(m, C(13.6, 14.1, 1.8), V(14.4, 0.2, 1.9), Kit.dark(sheet, 0.1), Mat.CorrodedMetal, SOLID)
end

------------------------------------------------------------------------
-- Щиток, сирена
------------------------------------------------------------------------

-- Щиток на стене справа от проёма: рычаг (группа GateLever), 3 лампы GateLamp, лампа питания, кабель-канал
local function leverBox(m: Model, rng: Random)
	local body = Kit.jitter(Color3.fromRGB(66, 72, 68), 0.04, rng)
	local cabinet = Kit.box(m, C(10.6, 3.1, -1.5), V(1.9, 2.4, 1.0), body, Mat.Metal)
	Kit.rustStreaks(cabinet, Enum.NormalId.Front, rng, 4)
	Kit.box(m, C(10.6, 4.38, -1.58) * A(-12, 0, 0), V(2.1, 0.1, 1.3), Kit.dark(body, 0.2), Mat.Metal, DECOR)
	local switch = Kit.box(m, C(10.6, 2.85, -2.05), V(1.5, 1.4, 0.1), Color3.fromRGB(50, 50, 50), Mat.Metal, DECOR)
	switch.Name = "Switch"
	-- Рычаг: вверху — ожидание (CF0), внизу — ворота открыты (CF1)
	local pivot = C(10.6, 2.75, -2.3)
	Kit.cyl(m, pivot, 0.55, 0.36, P.Iron, Mat.Metal, DECOR)
	local up, down = pivot * A(-25, 0, 0), pivot * A(-155, 0, 0)
	local arm = Kit.box(m, up * C(0, 0.65, 0), V(0.18, 1.3, 0.18), P.DarkSteel, Mat.Metal, DECOR)
	arm.Name = "Lever"
	Kit.movable(m, arm, "GateLever", up * C(0, 0.65, 0), down * C(0, 0.65, 0))
	local grip = Kit.cyl(m, up * C(0, 1.3, 0), 0.5, 0.24, Kit.dark(P.Blood, 0.1), Mat.Rubber, DECOR)
	Kit.movable(m, grip, "GateLever", up * C(0, 1.3, 0), down * C(0, 1.3, 0))
	Kit.box(m, C(10.6, 3.92, -2.03), V(1.6, 0.5, 0.08), P.Black, Mat.Metal, DECOR)
	for i = 1, 3 do
		local lamp = Kit.cyl(m, C(10.1 + (i - 1) * 0.5, 3.92, -2.1) * A(0, 90, 0), 0.12, 0.32, Color3.fromRGB(40, 0, 0), Mat.Neon, DECOR)
		lamp.Name = "GateLamp" .. i
		lamp:SetAttribute("GateLamp", i)
	end
	local power = Kit.ball(m, C(11.2, 4.55, -1.45), 0.34, Color3.fromRGB(70, 60, 40), Mat.Glass, DECOR)
	power.Name = "PowerLight"
	power:SetAttribute("PowerLight", true)
	-- Кабель-канал вверх по боку пилона к ригелю и кабель в землю
	Kit.rod(m, V(9.72, 4.3, -1.6), V(9.72, 12.6, -1.6), 0.22, P.DarkSteel, Mat.Metal, DECOR)
	Kit.box(m, C(9.8, 12.6, -1.6), V(0.4, 0.65, 0.55), Kit.dark(body, 0.15), Mat.Metal, DECOR)
	Kit.rod(m, V(11.1, 1.9, -1.5), V(11.3, -0.1, -1.6), 0.16, P.Rubber, Mat.Rubber, DECOR)
	-- Тусклый фонарь в решётке на боку пилона над щитком: щиток видно в темноте
	local lamp = Kit.box(m, C(9.88, 6.0, -1.7), V(0.55, 0.5, 0.5), P.Iron, Mat.Metal, DECOR)
	local glass = Kit.box(m, C(10.18, 6.0, -1.7), V(0.08, 0.34, 0.34), Color3.fromRGB(200, 170, 110), Mat.Glass, DECOR)
	Kit.pointLight(glass, Color3.fromRGB(255, 190, 120), 12, 0.9)
	Kit.box(m, lamp.CFrame * C(0, 0.3, -0.05) * A(-15, 0, 0), V(0.7, 0.06, 0.65), Kit.dark(body, 0.25), Mat.Metal, DECOR)
end

-- Сирена на оголовке левого пилона: светит вдоль проёма внутрь карты, пока ворота открывают
local function siren(m: Model)
	local x, y, z = -PILLAR_X + 0.4, PILLAR_SIZE.Y + 0.8, PILLAR_Z - 0.7
	Kit.vcyl(m, C(x, y + 0.18, z), 0.36, 0.9, P.Iron, Mat.Metal, DECOR)
	local dome = Kit.ball(m, C(x, y + 0.48, z), 0.86, Color3.fromRGB(80, 10, 10), Mat.Glass, DECOR)
	dome.Name = "Siren"
	local light = Kit.spotLight(dome, Color3.fromRGB(255, 30, 20), 28, 60, 4, Enum.NormalId.Front)
	light.Name = "SirenLight"
	light.Enabled = false
	Kit.vcyl(m, C(x, y + 0.92, z), 0.12, 0.4, P.Iron, Mat.Metal, DECOR)
end

------------------------------------------------------------------------
-- Коридор наружу и зона побега
------------------------------------------------------------------------

local function corridor(m: Model, rng: Random)
	Kit.box(m, C(0, -0.5, 16.6), V(12, 1, 28.4), Kit.jitter(Color3.fromRGB(56, 48, 40), 0.04, rng), Mat.Ground)
	local wall = Kit.jitter(P.DarkConcrete, 0.04, rng)
	-- справа стена начинается за карманом двери
	for _, w in { { x = -6.75, z0 = 1.2 }, { x = 6.75, z0 = 2.7 } } do
		local len = 30.75 - w.z0
		Kit.box(m, C(w.x, 6.5, w.z0 + len / 2), V(1.5, 13, len), wall, Mat.Concrete)
		local inward = w.x < 0 and 1 or -1
		for _, z in { 11, 21 } do
			Kit.box(m, C(w.x + inward * 0.9, 6.5, z), V(0.3, 13, 0.9), Kit.dark(wall, 0.12), Mat.Concrete, SOLID)
		end
	end
	-- Обломки на полу коридора
	for i = 1, 3 do
		local s = V(rng:NextNumber(0.6, 1.3), rng:NextNumber(0.3, 0.6), rng:NextNumber(0.5, 1.1))
		Kit.box(m, C(rng:NextNumber(-4.5, 4.5), s.Y / 2 - 0.05, 4 + i * 4.5) * A(0, rng:NextNumber(0, 180), rng:NextNumber(-8, 8)), s, Kit.jitter(P.DarkConcrete, 0.08, rng), Mat.Concrete, DECOR)
	end
	local escape = Kit.box(m, C(0, 6, 24), V(12, 12, 10), Color3.new(1, 1, 1), Mat.ForceField, { Decor = true, Transparency = 0.6 })
	escape.Name = "EscapeZone"
	-- свет «в конце коридора»; радиус не дотягивается сквозь закрытую дверь внутрь карты
	Kit.pointLight(escape, Color3.fromRGB(235, 240, 255), 24, 2)
end

------------------------------------------------------------------------
-- Мелочи: колючая проволока, кабели, обломки у пилонов
------------------------------------------------------------------------

local function dressing(m: Model, rng: Random, look: Look)
	if look.Wire then
		local posts = {}
		for i, x in { -9.2, -3, 3.2, 9.2 } do
			local base = V(x, 16.7, -0.6 + (i % 2) * 0.3)
			local top = base + V(0, 1.4, -0.35)
			Kit.rod(m, base, top, 0.12, P.Iron, Mat.Metal, DECOR)
			table.insert(posts, top)
		end
		for i = 1, #posts - 1 do
			Kit.cable(m, Kit.sag(posts[i] - V(0, 0.15, 0), posts[i + 1] - V(0, 0.15, 0), 0.35, 2), 0.06, P.DarkSteel, Mat.Metal, DECOR)
			Kit.cable(m, Kit.sag(posts[i] - V(0, 0.75, 0), posts[i + 1] - V(0, 0.75, 0), 0.25, 1), 0.06, P.DarkSteel, Mat.Metal, DECOR)
		end
	end
	if look.Cables then
		Kit.cable(m, Kit.sag(V(-6.2, 11.4, -2.45), V(6.2, 11.6, -2.45), 1.8, 4), 0.14, P.Rubber, Mat.Rubber, DECOR)
		Kit.cable(m, Kit.sag(V(-6.2, 12.2, -2.5), V(4.0, 12.1, -2.5), 1.1, 3), 0.1, P.Black, Mat.Rubber, DECOR)
	end
	-- Ржавая бочка рядом со щитком
	local drum = C(12.7, 1.35, -2.3)
	local rust = Kit.jitter(Color3.fromRGB(92, 52, 36), 0.05, rng)
	Kit.vcyl(m, drum, 2.7, 1.8, rust, Mat.CorrodedMetal)
	for _, dy in { -0.45, 0.45 } do
		Kit.vcyl(m, drum * C(0, dy, 0), 0.1, 1.86, Kit.dark(rust, 0.25), Mat.CorrodedMetal, DECOR)
	end
	for i = 1, 4 do
		local sx = i <= 2 and -1 or 1
		local s = V(rng:NextNumber(0.5, 1.1), rng:NextNumber(0.3, 0.7), rng:NextNumber(0.5, 0.9))
		local pos = V(sx * rng:NextNumber(5.4, 10.5), s.Y * 0.35, rng:NextNumber(-3.6, -2.8))
		if math.abs(pos.X) < 6 then
			pos = V(sx * 6.4, pos.Y, -3.0)
		end
		Kit.box(m, C(pos) * A(rng:NextNumber(-12, 12), rng:NextNumber(0, 180), rng:NextNumber(-12, 12)), s, Kit.jitter(P.Concrete, 0.08, rng), Mat.Concrete, DECOR)
	end
end

T.ExitGate = {
	Variants = #LOOKS,
	Build = function(rng: Random, variant: number)
		local look = LOOKS[(variant - 1) % #LOOKS + 1]
		local m = Kit.model("ExitGate")
		m:SetAttribute("Kind", "ExitGate")
		local frame = gatehouse(m, rng, look)
		Kit.setOrigin(m, frame)
		door(m, rng, look)
		track(m, rng)
		leverBox(m, rng)
		siren(m)
		corridor(m, rng)
		dressing(m, rng, look)
		m:SetAttribute("Powered", false)
		m:SetAttribute("Progress", 0)
		m:SetAttribute("Open", false)
		return m
	end,
}

return M
