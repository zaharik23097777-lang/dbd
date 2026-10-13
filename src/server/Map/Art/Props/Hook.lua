-- Крюк и лапы Сущности
-- Крюк: груда камней и костей, клёпаный ржавый столб с подкосами, консоль с гнутым концом и дугообразной
-- подпоркой, цепь и мясной крюк из сегментов дуги. Висящий (HangPoint) — спиной к столбу, остриё крюка
-- проходит сквозь его правое плечо. Крюк и консоль повёрнуты на ~10° вокруг столба, чтобы попасть в плечо.
-- Модель строится в начале координат: земля y = 0, «перед» модели смотрит в -Z.
-- Требования — Art/Contract.lua. HangPoint (прямой потомок модели) стоит ровно там же, что и раньше;
-- верх столба (y = 12 над опорой) — точка посадки ворона (MapBuilder).
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

local HANG_POINT = C(0.25, 7, -4.3) -- где висит выживший (корень персонажа)
local TOP = 12 -- верх колпака столба
local POLE = 0.84 -- сечение столба

-- Варианты: цвет металла и камней, кости, кровь, особая деталь
type Look = {
	Metal: Color3,
	Stone: Color3,
	Skull: boolean,
	Bones: number,
	ExtraBlood: boolean,
	BrokenChain: boolean, -- обрывок цепи свисает с консоли
	Stakes: boolean, -- заострённые колья в груде камней
}

local LOOKS: { Look } = {
	{ Metal = Color3.fromRGB(104, 50, 34), Stone = Color3.fromRGB(92, 90, 86), Skull = true, Bones = 2, ExtraBlood = false, BrokenChain = false, Stakes = false },
	{ Metal = Color3.fromRGB(58, 46, 42), Stone = Color3.fromRGB(70, 76, 66), Skull = false, Bones = 1, ExtraBlood = true, BrokenChain = true, Stakes = false },
	{ Metal = Color3.fromRGB(124, 72, 42), Stone = Color3.fromRGB(104, 98, 90), Skull = true, Bones = 1, ExtraBlood = false, BrokenChain = false, Stakes = true },
}

-- Столб: гильза в основании, хомуты, заклёпки, колпак, два подкоса назад
local function pole(m: Model, rng: Random, metal: Color3): BasePart
	local post = Kit.box(m, C(0, TOP / 2 - 0.15, 0), V(POLE, TOP - 0.3, POLE), metal, Mat.CorrodedMetal)
	post.Name = "Pole"
	Kit.rustStreaks(post, Enum.NormalId.Front, rng, 5, Kit.dark(metal, 0.45))
	Kit.rustStreaks(post, Enum.NormalId.Right, rng, 4, Kit.dark(metal, 0.45))
	local dark = Kit.dark(metal, 0.3)
	Kit.box(m, C(0, 0.6, 0), V(POLE + 0.36, 1.6, POLE + 0.36), dark, Mat.CorrodedMetal, SOLID)
	Kit.rivets(m, V(-0.32, 1.05, -0.62), V(0.32, 1.05, -0.62), 2, 0.17, dark)
	for _, y in { 2.6, 8.2 } do
		Kit.box(m, C(0, y, 0), V(POLE + 0.16, 0.32, POLE + 0.16), dark, Mat.CorrodedMetal, DECOR)
	end
	Kit.box(m, C(0, TOP - 0.15, 0), V(POLE + 0.3, 0.3, POLE + 0.3), dark, Mat.CorrodedMetal, SOLID)
	for _, sx in { -1, 1 } do
		local foot = V(sx * 1.45, 0.12, 1.95)
		Kit.bar(m, V(sx * 0.28, 4.3, 0.35), foot + V(0, 0.1, 0), 0.28, metal, Mat.CorrodedMetal, SOLID)
		Kit.box(m, C(foot) * A(0, sx * 25, 0), V(0.6, 0.14, 0.6), dark, Mat.Metal, DECOR)
	end
	return post
end

-- Консоль, подпорка, цепь и крюк в плоскости, повёрнутой вокруг столба к правому плечу висящего.
-- Локальные координаты плоскости: -Z — от столба к висящему, y — высота от земли.
local function crane(m: Model, rng: Random, metal: Color3, look: Look)
	local hp = HANG_POINT.Position
	local reach = V(hp.X + 0.5, 0, hp.Z)
	local F = CFrame.lookAt(Vector3.zero, reach)
	local function at(z: number, y: number): Vector3
		return F:PointToWorldSpace(V(0, y, z))
	end
	local d = reach.Magnitude -- расстояние от столба до центра чаши крюка
	local dark = Kit.dark(metal, 0.3)
	local r, bowlY = 0.68, 8.1 -- радиус и высота центра чаши (чаша проходит сквозь плечо)
	local armY, bend = 11.25, 0.6
	local shankZ = -(d - r)
	local armEnd = shankZ + bend -- конец прямой части, дальше загиб вниз
	local face = -POLE / 2
	-- Консоль и накладка, которой она прикручена к столбу
	Kit.bar(m, at(0.1, armY), at(armEnd, armY), 0.56, metal, Mat.CorrodedMetal, SOLID, 0.6)
	Kit.box(m, F * C(0, armY, face - 0.07), V(1.0, 1.1, 0.14), dark, Mat.Metal, DECOR)
	-- Загиб на конце консоли (дуга вниз) и дугообразная подпорка между столбом и консолью
	Kit.arc(m, F * C(0, armY - bend, armEnd) * A(0, 90, 0), bend, 90, 0, 3, 0.56, metal, Mat.CorrodedMetal, DECOR)
	Kit.arc(m, F * C(0, armY - 0.28, face) * A(0, 90, 0), 2.4, -90, 0, 4, 0.3, dark, Mat.CorrodedMetal, DECOR)
	-- Цепь от загиба до ушка крюка
	local eyeY = 9.55
	Kit.chain(m, { at(shankZ, armY - bend - 0.1), at(shankZ, eyeY + 0.12) }, 0.42, P.DarkSteel)
	if look.BrokenChain then
		local from = at(-1.6, armY - 0.3)
		Kit.chain(m, { from, from + V(0.1, -1.3, 0) }, 0.42, Kit.dark(P.Rust, 0.2))
	end
	-- Крюк: ушко, стержень, чаша (низ в запёкшейся крови), остриё
	local steel = Kit.jitter(P.Steel, 0.04, rng)
	local bowlZ = shankZ - r
	Kit.cyl(m, C(at(shankZ, eyeY)) * F.Rotation, 0.12, 0.44, P.DarkSteel, Mat.Metal, DECOR)
	Kit.rod(m, at(shankZ, eyeY - 0.12), at(shankZ, bowlY), 0.26, steel, Mat.Metal, DECOR)
	local bowl = Kit.arc(m, F * C(0, bowlY, bowlZ) * A(0, 90, 0), r, 180, 360, 5, 0.26, steel, Mat.Metal, DECOR)
	for i = 2, 5 do
		bowl[i].Color = Kit.dark(P.Blood, 0.2 + i * 0.05)
	end
	local tipBase = at(bowlZ - r, bowlY)
	local tip = Kit.wedge(m, C(tipBase + V(0, 0.3, 0)) * F.Rotation, V(0.24, 0.62, 0.26), P.Blood, Mat.Metal, DECOR)
	tip.Name = "HookTip"
end

-- Груда камней у основания, кости, череп, (колья)
local function rubble(m: Model, rng: Random, look: Look)
	Kit.box(m, C(0, 0.14, 0.1) * A(0, 20, 0), V(2.6, 0.32, 2.4), Kit.jitter(look.Stone, 0.05, rng), Mat.Slate, SOLID)
	for i = 1, 4 do
		local a = math.rad(i * 90 + rng:NextNumber(-25, 25) + 45)
		local r = rng:NextNumber(1.2, 1.6)
		local s = V(rng:NextNumber(0.9, 1.5), rng:NextNumber(0.6, 1.0), rng:NextNumber(0.8, 1.2))
		Kit.box(m, C(math.cos(a) * r, s.Y * 0.3, math.sin(a) * r) * A(rng:NextNumber(-15, 15), rng:NextNumber(0, 180), rng:NextNumber(-15, 15)), s, Kit.jitter(look.Stone, 0.08, rng), Mat.Rock, SOLID)
	end
	local bone = Kit.jitter(P.OldBone, 0.05, rng)
	local spots = { { V(1.25, 0.1, -1.1), 30 }, { V(-1.1, 0.12, -1.35), -50 } }
	for i = 1, look.Bones do
		local pos, yaw = spots[i][1], spots[i][2]
		local cf = C(pos) * A(0, yaw, rng:NextNumber(-8, 8))
		Kit.cyl(m, cf, 1.0, 0.15, bone, Mat.SmoothPlastic, DECOR)
		Kit.ball(m, cf * C(0.52, 0.02, 0), 0.26, bone, Mat.SmoothPlastic, DECOR)
	end
	if look.Skull then
		local cf = C(-0.8, 0.3, -1.0) * A(-15, 35, 10)
		Kit.ball(m, cf, 0.6, bone, Mat.SmoothPlastic, DECOR)
		Kit.box(m, cf * C(0, -0.22, -0.18), V(0.34, 0.16, 0.28), Kit.dark(bone, 0.15), Mat.SmoothPlastic, DECOR)
	end
	if look.Stakes then
		for i, a in { 150, 215 } do
			local base = V(math.cos(math.rad(a)) * 1.5, 0, math.sin(math.rad(a)) * 1.5)
			local top = base + V(math.cos(math.rad(a)) * 0.5, 1.6 + i * 0.3, math.sin(math.rad(a)) * 0.5)
			Kit.bar(m, base, top, 0.22, Kit.jitter(P.DarkWood, 0.06, rng), Mat.Wood, DECOR)
		end
	end
end

-- Кровь: неровная лужа под висящим (несколько пятен), мазок на столбе
local function blood(m: Model, rng: Random, look: Look)
	local hp = HANG_POINT.Position
	local function stain(x: number, z: number, size: number, color: Color3)
		Kit.cyl(m, C(hp.X + x, 0.02 + size * 0.004, hp.Z + z) * A(0, 0, 90), 0.04, size, color, Mat.SmoothPlastic, DECOR)
	end
	stain(0.45, 0.1, 1.9, P.DryBlood)
	stain(0.95, -0.55, 1.0, Kit.dark(P.Blood, 0.1))
	stain(-0.35, 0.75, 0.6, P.DryBlood)
	if look.ExtraBlood then
		stain(1.4, 0.9, 0.5, P.DryBlood)
	end
	Kit.box(m, C(0.05, 6.6, -POLE / 2 - 0.01) * A(0, 0, rng:NextNumber(-6, 6)), V(0.45, 1.7, 0.03), P.DryBlood, Mat.SmoothPlastic, DECOR)
end

T.Hook = {
	Variants = #LOOKS,
	Build = function(rng: Random, variant: number)
		local look = LOOKS[(variant - 1) % #LOOKS + 1]
		local m = Kit.model("Hook")
		m:SetAttribute("Kind", "Hook")
		local metal = Kit.jitter(look.Metal, 0.04, rng)
		local post = pole(m, rng, metal)
		Kit.setOrigin(m, post)
		crane(m, rng, metal, look)
		rubble(m, rng, look)
		blood(m, rng, look)
		local hp = Kit.box(m, HANG_POINT, V(1, 1, 1), P.Black, Mat.SmoothPlastic, { Decor = true, Transparency = 1 })
		hp.Name = "HangPoint"
		m:SetAttribute("Occupant", 0)
		return m
	end,
}

------------------------------------------------------------------------
-- Лапы Сущности
------------------------------------------------------------------------

-- Каждая лапа — ломаная из точек {радиус от висящего, высота над HangPoint}: из земли наружу и вверх,
-- выше головы загибается внутрь и вниз, короткий коготь (тёмно-красный, светится) бьёт в плечи и грудь.
-- Угол — от «вперёд» (-Z точки HangPoint); сзади (180°) стоит столб, туда лапы не ставим, спереди — просвет,
-- чтобы висящего было видно.
type Leg = { Angle: number, Points: { Vector2 } }

local LEGS: { Leg } = {
	{ Angle = -145, Points = { Vector2.new(2.4, -7.3), Vector2.new(4.3, -0.8), Vector2.new(3.8, 4.8), Vector2.new(1.3, 3.5), Vector2.new(0.5, 1.6) } },
	{ Angle = -82, Points = { Vector2.new(2.7, -7.3), Vector2.new(4.7, -1.4), Vector2.new(4.2, 4.2), Vector2.new(1.4, 3.1), Vector2.new(0.6, 1.0) } },
	{ Angle = -28, Points = { Vector2.new(2.5, -7.3), Vector2.new(4.1, -0.2), Vector2.new(3.5, 5.3), Vector2.new(1.2, 3.8), Vector2.new(0.55, 1.9) } },
	{ Angle = 38, Points = { Vector2.new(2.8, -7.3), Vector2.new(4.6, -1.0), Vector2.new(4.0, 4.6), Vector2.new(1.3, 3.3), Vector2.new(0.6, 1.3) } },
	{ Angle = 108, Points = { Vector2.new(2.5, -7.3), Vector2.new(4.4, -1.6), Vector2.new(4.1, 4.0), Vector2.new(1.4, 2.9), Vector2.new(0.5, 0.8) } },
}

local SEGMENT_WIDTH = { 0.46, 0.36, 0.26, 0.15 } -- сужение к когтю

-- Лапы Сущности вокруг висящего (hangPoint — мировой CFrame точки HangPoint). Только декор, 25 деталей.
function M.entityLegs(hangPoint: CFrame): Model
	local m = Kit.model("EntityLegs")
	local shell = Color3.fromRGB(22, 14, 16)
	local claw = Color3.fromRGB(120, 12, 10)
	for _, leg in LEGS do
		local a = math.rad(leg.Angle)
		local dir = V(math.sin(a), 0, -math.cos(a))
		local pts = {}
		for i, q in leg.Points do
			pts[i] = hangPoint:PointToWorldSpace(dir * q.X + V(0, q.Y, 0))
		end
		for i = 1, #pts - 1 do
			local last = i == #pts - 1
			local seg = Kit.bar(m, pts[i], pts[i + 1], SEGMENT_WIDTH[i], last and claw or Kit.jitter(shell, 0.04), last and Mat.Neon or Mat.Slate, DECOR)
			if seg then
				-- ромбовидное сечение — хитин выглядит острее
				seg.CFrame *= A(0, 0, 45)
			end
		end
		-- шип на верхнем изгибе смотрит вверх и наружу
		local knee = pts[3]
		local out = knee + dir * 0.7 + V(0, 1.1, 0)
		Kit.wedge(m, CFrame.lookAt((knee + out) / 2, out) * A(-90, 0, 0), V(0.2, 1.3, 0.3), shell, Mat.Slate, DECOR)
	end
	return m
end

return M
