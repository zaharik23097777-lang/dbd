-- Внешний вид маньяков: снаряжение из деталей, приваренное к частям тела R6.
-- KillerGear.dress(char, def) вызывается до масштабирования (char:ScaleTo), поэтому размеры заданы
-- в «родных» единицах R6: голова ~1.2, торс 2x2x1, руки и ноги 1x2x1, кисть — низ руки (y = -1).
-- Правила:
--   * детали — прямые потомки персонажа, приварены к своей части тела (процедурная анимация двигает
--     их вместе с ней), Massless, без столкновений и запросов, мелочь без тени;
--   * имена из CameraController.VIEWMODEL (оружие и снаряжение рук) остаются видны маньяку от первого
--     лица — прочему снаряжению эти имена давать нельзя;
--   * SurfaceGui только на оружии: рисунки не исчезают вместе с деталью (вид из головы, невидимость
--     Призрака), поэтому маски, одежда и всё у Призрака — только из деталей;
--   * родная голова скрыта (размер её меша у R6 непредсказуем) — голову целиком строит снаряжение;
--   * всё, что висит ниже пояса спереди и сзади, крепится к ногам: иначе ноги на бегу пронзают его.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Util = require(ReplicatedStorage.Shared.Util)
local Kit = require(script.Parent.Kit)

local KillerGear = {}

local A = Kit.A
local P = Kit.Palette
local Mat = Enum.Material

local LIMBS = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }

type Shape = "Block" | "Wedge" | "Ball" | "Cylinder"

type Gear = {
	char: Model,
	limbs: { [string]: BasePart },
	rng: Random,
}

local CLASS: { [Shape]: string } = { Block = "Part", Ball = "Part", Cylinder = "Part", Wedge = "WedgePart" }

------------------------------------------------------------------------
-- Детали снаряжения (координаты — в пространстве своей части тела)
------------------------------------------------------------------------

local function put(g: Gear, limb: string, name: string, shape: Shape, cf: CFrame, size: Vector3, color: Color3, material: Enum.Material?): BasePart
	local base = g.limbs[limb]
	local p = Kit.part(nil, {
		Name = name,
		Size = size,
		CFrame = base.CFrame * cf,
		Color = color,
		Material = material or Mat.SmoothPlastic,
		Anchored = false,
		Massless = true,
		Decor = true,
	}, CLASS[shape])
	if shape == "Ball" then
		(p :: any).Shape = Enum.PartType.Ball
	elseif shape == "Cylinder" then
		(p :: any).Shape = Enum.PartType.Cylinder
	end
	-- Крупные плоскости (фартук, плащ, клинок) отбрасывают тень, мелочь — нет
	local dims = { size.X, size.Y, size.Z }
	table.sort(dims)
	p.CastShadow = dims[2] >= 0.6
	Util.weld(base, p)
	p.Parent = g.char
	return p
end

local function tone(g: Gear, color: Color3, amount: number?): Color3
	return Kit.jitter(color, amount or 0.05, g.rng)
end

-- Цилиндр между точками a и b
local function rod(g: Gear, limb: string, name: string, a: Vector3, b: Vector3, diameter: number, color: Color3, material: Enum.Material?): BasePart
	local cf = CFrame.lookAt((a + b) / 2, b) * A(0, 90, 0)
	return put(g, limb, name, "Cylinder", cf, Vector3.new((b - a).Magnitude, diameter, diameter), color, material)
end

-- Вертикальный цилиндр (ось Y кадра cf)
local function disc(g: Gear, limb: string, name: string, cf: CFrame, height: number, diameter: number, color: Color3, material: Enum.Material?): BasePart
	return put(g, limb, name, "Cylinder", cf * A(0, 0, 90), Vector3.new(height, diameter, diameter), color, material)
end

-- Цилиндр вдоль оси Z кадра cf (рукояти оружия: от кисти вперёд)
local function shaft(g: Gear, limb: string, name: string, cf: CFrame, length: number, diameter: number, color: Color3, material: Enum.Material?): BasePart
	return put(g, limb, name, "Cylinder", cf * A(0, 90, 0), Vector3.new(length, diameter, diameter), color, material)
end

-- Обмотка вокруг части тела: полоса чуть шире самой части, наклонённая на tiltX/tiltZ градусов
local function wrap(g: Gear, limb: string, name: string, y: number, height: number, tiltX: number, tiltZ: number, color: Color3, material: Enum.Material?, pad: number?): BasePart
	local s = g.limbs[limb].Size
	local e = pad or 0.07
	return put(g, limb, name, "Block", CFrame.new(0, y, 0) * A(tiltX, 0, tiltZ), Vector3.new(s.X + e, height, s.Z + e), color, material or Mat.Fabric)
end

-- Рваная полоса ткани: top — середина верхнего края, локальная Z кадра смотрит наружу от тела.
-- Клин сужается книзу в косой «язык»; mirror — остриё с другой стороны.
local function rag(g: Gear, limb: string, name: string, top: CFrame, width: number, length: number, color: Color3, mirror: boolean?): BasePart
	local cf = top * CFrame.new(0, -length / 2, 0) * A(0, mirror and -90 or 90, 180)
	return put(g, limb, name, "Wedge", cf, Vector3.new(0.05, length, width), color, Mat.Fabric)
end

-- Осколок металла, торчащий из тела: основание base (утоплено), направление dir
local function shard(g: Gear, limb: string, base: Vector3, dir: Vector3, length: number, width: number, color: Color3)
	local d = dir.Unit
	local cf = CFrame.lookAt(base + d * length / 2, base + d * length) * A(-90, 0, 0) * A(0, g.rng:NextNumber(-40, 40), 0)
	put(g, limb, "Shard", "Wedge", cf, Vector3.new(0.06, length, width), color, Mat.CorrodedMetal)
end

------------------------------------------------------------------------
-- Траппер: белая маска-оскал, кожаный фартук в крови, капкан и крюк на поясе,
-- железо в плечах и спине, огромный тесак
------------------------------------------------------------------------

local GEAR = {}

function GEAR.Trapper(g: Gear, def)
	local rng = g.rng
	local bone = tone(g, P.Bone, 0.02)
	local leather = Color3.fromRGB(100, 70, 48)
	local strap = Color3.fromRGB(38, 29, 24)
	local cloth = Color3.fromRGB(96, 86, 70)
	local shirt = Kit.dark(def.ClothColor, 0.18)
	local hole = Color3.fromRGB(24, 12, 10)
	-- Грязная тёмная рубаха без рукавов: кожаный фартук на ней читается издалека
	g.limbs.Torso.Color = shirt

	-- Голова: тёмные волосы, ремень маски, маска с оскалом
	put(g, "Head", "Hair", "Ball", CFrame.new(0, 0.04, 0.1), Vector3.one * 1.18, Color3.fromRGB(40, 32, 28))
	disc(g, "Head", "MaskStrap", CFrame.new(0, 0.18, 0.1) * A(-6, 0, 0), 0.13, 1.24, strap, Mat.Leather)
	-- Лицевая пластина со скошенными боками: маска выпуклая и уходит к ушам
	put(g, "Head", "Mask", "Block", CFrame.new(0, 0.02, -0.46), Vector3.new(0.8, 1.06, 0.2), bone, Mat.Plaster)
	for _, s in { -1, 1 } do
		put(g, "Head", "Mask", "Wedge", CFrame.new(0.475 * s, 0.02, -0.46) * A(0, 0, -90 * s), Vector3.new(1.06, 0.15, 0.2), bone, Mat.Plaster)
	end
	put(g, "Head", "MaskBrow", "Wedge", CFrame.new(0, 0.64, -0.38), Vector3.new(0.8, 0.18, 0.36), bone, Mat.Plaster)
	local front = -0.56 -- передняя грань маски
	for _, s in { -1, 1 } do
		put(g, "Head", "MaskEye", "Block", CFrame.new(0.24 * s, 0.2, front - 0.005) * A(0, 0, 14 * s), Vector3.new(0.3, 0.14, 0.04), hole)
	end
	put(g, "Head", "MaskMouth", "Block", CFrame.new(0, -0.24, front - 0.005), Vector3.new(0.78, 0.3, 0.04), hole)
	-- Кривые зубы сверху и снизу (одного не хватает), между ними чернеет рот
	local teeth = { { -0.28, 1 }, { -0.08, 1 }, { 0.12, 1 }, { 0.3, 1 }, { -0.18, -1 } }
	for _, t in teeth do
		local h = rng:NextNumber(0.13, 0.2)
		local y = t[2] > 0 and -0.09 - h / 2 + 0.03 or -0.39 + h / 2 - 0.03
		local cf = CFrame.new(t[1] + rng:NextNumber(-0.03, 0.03), y, front - 0.02) * A(0, 0, rng:NextNumber(-12, 12))
		put(g, "Head", "MaskTooth", "Block", cf, Vector3.new(0.12, h, 0.05), tone(g, P.OldBone, 0.06))
	end
	-- Трещина через лоб к глазу
	put(g, "Head", "MaskCrack", "Block", CFrame.new(-0.1, 0.4, front - 0.006) * A(0, 0, -62), Vector3.new(0.38, 0.03, 0.03), hole)

	-- Сутулая спина
	put(g, "Torso", "Hump", "Wedge", CFrame.new(0, 0.5, 0.66) * A(180, 0, 0), Vector3.new(1.8, 1, 0.32), shirt, Mat.Fabric)
	-- Фартук: нагрудник и пояс на торсе, полы — на ногах (разрезной, как у кузнеца)
	put(g, "Torso", "ApronBib", "Block", CFrame.new(0, 0.45, -0.56), Vector3.new(1.4, 1.1, 0.1), leather, Mat.Leather)
	put(g, "Torso", "Apron", "Block", CFrame.new(0, -0.55, -0.57), Vector3.new(2.04, 0.95, 0.12), leather, Mat.Leather)
	put(g, "Torso", "ApronBlood", "Block", CFrame.new(0.3, -0.2, -0.64) * A(0, 0, -9), Vector3.new(0.26, 1.15, 0.02), P.DryBlood, Mat.Leather)
	for _, s in { -1, 1 } do
		local a = Vector3.new(0.6 * s, 1.0, -0.62)
		local b = Vector3.new(0.32 * s, 1.07, 0.3)
		put(g, "Torso", "ApronStrap", "Block", CFrame.lookAt((a + b) / 2, b), Vector3.new(0.1, 0.05, (b - a).Magnitude), strap, Mat.Leather)
	end
	put(g, "Torso", "Belt", "Block", CFrame.new(0, -0.82, 0.02), Vector3.new(2.08, 0.26, 1.08), strap, Mat.Leather)
	-- Капкан на левом бедре (сбоку — ноги его не задевают)
	local trap = CFrame.new(-1.14, -1.42, 0.1) * A(0, -32, 0)
	put(g, "Torso", "BeltTrap", "Cylinder", trap, Vector3.new(0.12, 0.94, 0.94), tone(g, P.DarkRust), Mat.CorrodedMetal)
	put(g, "Torso", "BeltTrap", "Block", trap * CFrame.new(-0.08, 0, 0) * A(16, 0, 0), Vector3.new(0.06, 0.14, 1.6), P.Iron, Mat.Metal)
	-- Мясной крюк на правом бедре
	rod(g, "Torso", "MeatHook", Vector3.new(1.07, -0.92, 0.2), Vector3.new(1.08, -1.5, 0.2), 0.07, P.Rust, Mat.CorrodedMetal)
	rod(g, "Torso", "MeatHook", Vector3.new(1.08, -1.47, 0.22), Vector3.new(1.08, -1.4, -0.12), 0.07, P.Rust, Mat.CorrodedMetal)
	-- Железо, вбитое в плечи и спину
	shard(g, "Torso", Vector3.new(0.7, 0.9, 0.05), Vector3.new(0.35, 0.85, 0.3), 0.95, 0.26, tone(g, P.Rust))
	shard(g, "Torso", Vector3.new(-0.62, 0.9, 0.18), Vector3.new(-0.3, 0.8, 0.5), 0.8, 0.22, tone(g, P.DarkRust))
	shard(g, "Torso", Vector3.new(-0.45, 0.55, 0.62), Vector3.new(-0.2, 0.35, 0.9), 0.62, 0.18, tone(g, P.Rust))

	-- Руки: обрывки рукавов, перчатка на правой, грязная обмотка на левой (кисти видны от первого лица)
	for _, arm in { "Left Arm", "Right Arm" } do
		wrap(g, arm, "Sleeve", 0.66, 0.68, 0, arm == "Left Arm" and -5 or 4, shirt, Mat.Fabric, 0.05)
	end
	put(g, "Right Arm", "Glove", "Block", CFrame.new(0, -0.74, 0), Vector3.new(1.06, 0.54, 1.06), Color3.fromRGB(44, 34, 28), Mat.Leather)
	wrap(g, "Left Arm", "Wrap", -0.58, 0.42, 0, 6, cloth)

	-- Ноги: полы фартука, обмотки-лохмотья, сапоги
	for _, leg in { "Left Leg", "Right Leg" } do
		local s = leg == "Left Leg" and -1 or 1
		put(g, leg, "ApronFlap", "Block", CFrame.new(0.01 * s, 0.24, -0.57) * A(4, 0, 0), Vector3.new(0.98, 1.4, 0.12), leather, Mat.Leather)
		wrap(g, leg, "LegRag", -0.3, 0.36, 4 * s, 7 * s, tone(g, cloth, 0.08))
		put(g, leg, "Boot", "Block", CFrame.new(0, -0.76, -0.07), Vector3.new(1.06, 0.5, 1.18), Color3.fromRGB(35, 28, 24), Mat.Leather)
	end

	-- Тесак: широкий клинок лезвием вниз, скошенное остриё.
	-- Хват: рукоять поперёк кулака, оружие чуть задрано и повёрнуто плашмя к камере от первого лица
	local grip = CFrame.new(0, -0.8, 0) * A(15, 0, -30)
	local arm = "Right Arm"
	shaft(g, arm, "Handle", grip * CFrame.new(0, 0, -0.12), 1.3, 0.22, tone(g, P.DarkWood), Mat.Wood)
	shaft(g, arm, "Handle", grip * CFrame.new(0, 0, 0.56), 0.1, 0.28, P.DarkSteel, Mat.Metal)
	put(g, arm, "Handle", "Block", grip * CFrame.new(0, -0.05, -0.83), Vector3.new(0.17, 0.34, 0.14), P.DarkSteel, Mat.Metal)
	local steel = Color3.fromRGB(104, 104, 102)
	local blade = put(g, arm, "Blade", "Block", grip * CFrame.new(0, -0.4, -1.95), Vector3.new(0.1, 1.05, 2.2), steel, Mat.Metal)
	put(g, arm, "Blade", "Wedge", grip * CFrame.new(0, -0.4, -3.3), Vector3.new(0.1, 1.05, 0.5), steel, Mat.Metal)
	put(g, arm, "Blade", "Block", grip * CFrame.new(0, 0.1, -1.95), Vector3.new(0.15, 0.1, 2.2), P.Iron, Mat.Metal)
	put(g, arm, "Blade", "Block", grip * CFrame.new(0, -0.86, -1.95), Vector3.new(0.104, 0.13, 2.2), Color3.fromRGB(160, 160, 156), Mat.Metal)
	put(g, arm, "Blade", "Cylinder", grip * CFrame.new(0, -0.12, -2.8), Vector3.new(0.108, 0.2, 0.2), hole)
	put(g, arm, "BladeBlood", "Block", grip * CFrame.new(0, -0.62, -2.55) * A(-8, 0, 0), Vector3.new(0.108, 0.5, 1.1), P.Blood)
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		Kit.rustStreaks(blade, face, rng, 5)
		Kit.rustStreaks(blade, face, rng, 3, P.DryBlood)
	end
end

------------------------------------------------------------------------
-- Охотница: маска-заяц с длинными ушами и росписью, меховой капюшон и накидка,
-- слои меха и кожи, запасные топорики у бёдер, большой обмотанный топор
------------------------------------------------------------------------

-- Запасной топорик на бедре: top — центр обуха, рукоять вниз по -Y, лезвие вперёд по -Z
local function thighHatchet(g: Gear, leg: string, top: CFrame)
	rod(g, leg, "SpareHatchet", (top * CFrame.new(0, 0.1, 0)).Position, (top * CFrame.new(0, -1.05, 0.04)).Position, 0.12, tone(g, P.Wood), Mat.Wood)
	put(g, leg, "SpareHatchet", "Block", top * CFrame.new(0, -0.04, -0.2), Vector3.new(0.07, 0.34, 0.46), tone(g, P.DarkSteel), Mat.CorrodedMetal)
end

function GEAR.Huntress(g: Gear, def)
	local rng = g.rng
	local furDark = Color3.fromRGB(70, 55, 44)
	local furLight = Color3.fromRGB(132, 124, 112) -- седой волчий мех
	local hide = Color3.fromRGB(116, 74, 48)
	local leather = Color3.fromRGB(58, 40, 30)
	local white = tone(g, Color3.fromRGB(216, 208, 190), 0.02)
	local paint = Color3.fromRGB(122, 32, 26)

	-- Капюшон из меха и маска-заяц
	put(g, "Head", "Hood", "Ball", CFrame.new(0, 0.12, 0.12), Vector3.one * 1.34, furDark, Mat.Fabric)
	disc(g, "Head", "Hood", CFrame.new(0, -0.2, 0.13), 0.72, 1.34, furDark, Mat.Fabric)
	put(g, "Head", "Mask", "Block", CFrame.new(0, -0.02, -0.6), Vector3.new(1, 1.02, 0.16), white, Mat.Wood)
	put(g, "Head", "MaskSnout", "Wedge", CFrame.new(0, -0.27, -0.81), Vector3.new(0.44, 0.4, 0.26), Kit.dark(white, 0.06), Mat.Wood)
	for _, s in { -1, 1 } do
		put(g, "Head", "MaskEye", "Block", CFrame.new(0.22 * s, 0.14, -0.69) * A(0, 0, 45), Vector3.new(0.19, 0.19, 0.04), Color3.fromRGB(16, 12, 10))
		put(g, "Head", "MaskPaint", "Block", CFrame.new(0.23 * s, -0.12, -0.685) * A(0, 0, 6 * s), Vector3.new(0.07, 0.4, 0.03), paint)
		-- Уши: длинные плоские, чуть назад и в стороны, со скруглённым концом и тёмной внутренней стороной
		local base = CFrame.new(0.26 * s, 0.46, -0.52) * A(14, 0, -9 * s)
		put(g, "Head", "MaskEar", "Block", base * CFrame.new(0, 0.6, 0), Vector3.new(0.36, 1.2, 0.1), white, Mat.Wood)
		shaft(g, "Head", "MaskEar", base * CFrame.new(0, 1.2, 0), 0.1, 0.36, white, Mat.Wood)
		put(g, "Head", "MaskEar", "Block", base * CFrame.new(0, 0.66, -0.055), Vector3.new(0.17, 1.02, 0.02), Color3.fromRGB(128, 84, 72))
	end

	-- Меховая накидка на плечах, воротник, плащ до бёдер
	-- (спереди накидка не выше подбородка, чтобы не закрывать маску)
	put(g, "Torso", "Mantle", "Block", CFrame.new(0, 1.1, 0.1), Vector3.new(2.4, 0.4, 1.24), furLight, Mat.Fabric)
	for _, s in { -1, 1 } do
		put(g, "Torso", "Mantle", "Wedge", CFrame.new(1.625 * s, 1.1, 0.1) * A(0, -90 * s, 0), Vector3.new(1.24, 0.4, 0.85), furLight, Mat.Fabric)
	end
	put(g, "Torso", "Collar", "Block", CFrame.new(0, 1.45, 0.48) * A(15, 0, 0), Vector3.new(1.7, 0.55, 0.45), tone(g, furLight, 0.06), Mat.Fabric)
	local cape = CFrame.new(0, -0.15, 0.62) * A(-5, 0, 0)
	put(g, "Torso", "Cape", "Block", cape, Vector3.new(2.3, 2.3, 0.14), furDark, Mat.Fabric)
	rag(g, "Torso", "Cape", cape * CFrame.new(-0.62, -1.12, 0), 0.62, 0.5, furDark)
	rag(g, "Torso", "Cape", cape * CFrame.new(0.55, -1.12, 0), 0.7, 0.42, furDark, true)
	-- Кожаный корсаж, пояс с пряжкой, меховая юбка на бёдрах, сумка на поясе
	put(g, "Torso", "Bodice", "Block", CFrame.new(0, 0.12, -0.55), Vector3.new(1.8, 1.25, 0.1), leather, Mat.Leather)
	put(g, "Torso", "Belt", "Block", CFrame.new(0, -0.66, 0), Vector3.new(2.08, 0.28, 1.1), leather, Mat.Leather)
	put(g, "Torso", "Buckle", "Block", CFrame.new(-0.15, -0.66, -0.58), Vector3.new(0.3, 0.3, 0.08), P.OldBone)
	put(g, "Torso", "FurSkirt", "Block", CFrame.new(0, -1.0, 0), Vector3.new(2.12, 0.55, 1.16), furLight, Mat.Fabric)
	put(g, "Torso", "Pouch", "Block", CFrame.new(0.6, -0.84, -0.66), Vector3.new(0.36, 0.4, 0.24), hide, Mat.Leather)

	-- Руки: обмотки из меха и кожи
	for _, arm in { "Left Arm", "Right Arm" } do
		wrap(g, arm, "Bracer", -0.38, 0.72, 0, 0, tone(g, hide, 0.04), Mat.Leather)
	end

	-- Ноги: кожаная юбка с рваным краем (на бёдрах), меховые сапоги с ремешками, топорики
	for _, leg in { "Left Leg", "Right Leg" } do
		local s = leg == "Left Leg" and -1 or 1
		put(g, leg, "Skirt", "Block", CFrame.new(0.03 * s, 0.42, -0.01), Vector3.new(1.06, 1.15, 1.1), hide, Mat.Leather)
		rag(g, leg, "Skirt", CFrame.new(0.08 * s, -0.12, -0.56) * A(0, 180, 0), 0.62, 0.48, hide, s > 0)
		put(g, leg, "Boot", "Block", CFrame.new(0, -0.62, -0.04), Vector3.new(1.1, 0.8, 1.16), furDark, Mat.Fabric)
		wrap(g, leg, "BootCord", -0.4, 0.08, 0, 6 * s, leather, Mat.Leather, 0.14)
		-- Запасной топорик заткнут под меховую юбку снаружи бедра
		thighHatchet(g, leg, CFrame.new(0.63 * s, 0.6, 0.05 + 0.08 * s) * A(-16 - 8 * s, 0, 0))
	end

	-- Большой топор: длинная рукоять с обмотками, широкое бородатое лезвие вниз
	local grip = CFrame.new(0, -0.8, 0) * A(15, 0, -30)
	local arm = "Right Arm"
	shaft(g, arm, "Handle", grip * CFrame.new(0, 0, -0.85), 2.5, 0.2, tone(g, P.Wood), Mat.Wood)
	shaft(g, arm, "Handle", grip * CFrame.new(0, 0, -1.42), 0.5, 0.25, Color3.fromRGB(122, 106, 84), Mat.Fabric)
	shaft(g, arm, "Handle", grip * CFrame.new(0, 0, 0.32), 0.22, 0.25, leather, Mat.Leather)
	put(g, arm, "AxeHead", "Block", grip * CFrame.new(0, -0.02, -1.98), Vector3.new(0.24, 0.44, 0.46), P.Iron, Mat.Metal)
	local steel = tone(g, P.DarkSteel, 0.04)
	local head = put(g, arm, "AxeHead", "Block", grip * CFrame.new(0, -0.62, -1.98), Vector3.new(0.12, 0.8, 0.54), steel, Mat.Metal)
	put(g, arm, "AxeHead", "Wedge", grip * CFrame.new(0, -0.62, -2.47), Vector3.new(0.12, 0.8, 0.44), steel, Mat.Metal)
	put(g, arm, "AxeHead", "Wedge", grip * CFrame.new(0, -0.62, -1.53) * A(0, 180, 0), Vector3.new(0.12, 0.8, 0.36), steel, Mat.Metal)
	put(g, arm, "AxeHead", "Block", grip * CFrame.new(0, -0.96, -2.01), Vector3.new(0.13, 0.13, 1.36), Color3.fromRGB(150, 150, 146), Mat.Metal)
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		Kit.rustStreaks(head, face, rng, 4)
	end
end

------------------------------------------------------------------------
-- Призрак: тело в бинтах, чёрные лохмотья, дубина из позвоночника с черепом,
-- колокол в левой руке. Никаких SurfaceGui: при невидимости они бы остались висеть в воздухе.
------------------------------------------------------------------------

function GEAR.Wraith(g: Gear, def)
	local rng = g.rng
	local skin = Kit.dark(def.BodyColor, 0.4)
	local bandage = def.ClothColor
	local ragColor = Color3.fromRGB(30, 28, 27)
	local bone = P.OldBone
	local bronze = Color3.fromRGB(112, 90, 56)
	for _, name in { "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" } do
		g.limbs[name].Color = skin
	end
	local function bandageTone(): Color3
		return tone(g, rng:NextNumber() < 0.5 and bandage or Kit.dark(bandage, 0.2), 0.05)
	end

	-- Голова: обмотанный череп, светящиеся щели глаз, капюшон-тряпка и свисающие ленты
	put(g, "Head", "HeadWrap", "Ball", CFrame.new(0, 0.04, 0.05), Vector3.one * 1.12, Color3.fromRGB(36, 33, 31), Mat.Fabric)
	disc(g, "Head", "HeadBandage", CFrame.new(0, 0.3, 0.05) * A(-14, 0, 8), 0.16, 1.1, bandageTone())
	disc(g, "Head", "HeadBandage", CFrame.new(0, -0.22, 0.05) * A(10, 0, -12), 0.2, 1.12, bandageTone())
	for _, s in { -1, 1 } do
		put(g, "Head", "Eye", "Block", CFrame.new(0.21 * s, 0.07, -0.5) * A(0, 0, -10 * s), Vector3.new(0.22, 0.07, 0.05), Color3.fromRGB(240, 232, 205), Mat.Neon)
		rag(g, "Head", "HeadRag", CFrame.new(0.32 * s, -0.3, 0.62) * A(8, 0, 0), 0.32, 1.25, tone(g, ragColor, 0.08), s > 0)
	end
	put(g, "Head", "Hood", "Block", CFrame.new(0, -0.14, 0.55) * A(-14, 0, 0), Vector3.new(1.02, 0.85, 0.14), ragColor, Mat.Fabric)

	-- Бинты: полосы вокруг торса, рук и ног (на руках — видны от первого лица)
	for _, b in { { 0.64, 0.22, 4, 8 }, { 0.2, 0.18, -3, -10 }, { -0.26, 0.24, 5, 6 }, { -0.7, 0.18, -2, -5 } } do
		wrap(g, "Torso", "Bandage", b[1], b[2], b[3], b[4], bandageTone())
	end
	for _, arm in { "Left Arm", "Right Arm" } do
		for _, b in { { 0.5, 0.2, 6 }, { 0, 0.16, -9 }, { -0.48, 0.22, 7 } } do
			wrap(g, arm, "ArmWrap", b[1], b[2], 0, b[3], bandageTone())
		end
	end
	for _, leg in { "Left Leg", "Right Leg" } do
		for _, b in { { 0.35, 0.2, 7 }, { -0.42, 0.24, -6 } } do
			wrap(g, leg, "Bandage", b[1], b[2], 0, b[3], bandageTone())
		end
	end

	-- Лохмотья: ворот вокруг шеи, ленты со спины, по бокам пояса, на руках; спереди и сзади — на ногах
	put(g, "Torso", "Cowl", "Block", CFrame.new(0, 1.04, 0.06) * A(0, 0, 3), Vector3.new(1.36, 0.3, 1.16), ragColor, Mat.Fabric)
	for _, s in { -1, 1 } do
		rag(g, "Torso", "Rag", CFrame.new(0.55 * s, 0.95, 0.56) * A(-4, 0, 3 * s), 0.62, 2.05, tone(g, ragColor, 0.08), s < 0)
		rag(g, "Torso", "Rag", CFrame.new(1.03 * s, -0.92, 0.1) * A(0, 90 * s, 0), 0.6, 1.6 + rng:NextNumber(-0.15, 0.15), tone(g, ragColor, 0.08), s > 0)
	end
	for _, arm in { "Left Arm", "Right Arm" } do
		local s = arm == "Left Arm" and -1 or 1
		rag(g, arm, "ArmRag", CFrame.new(0.53 * s, -0.15, 0.05) * A(0, 90 * s, 0), 0.4, 1.05, tone(g, ragColor, 0.08), s > 0)
	end
	for _, leg in { "Left Leg", "Right Leg" } do
		local s = leg == "Left Leg" and -1 or 1
		rag(g, leg, "Rag", CFrame.new(0.06 * s, 0.98, -0.54) * A(0, 180, 0), 0.62, 1.3 + rng:NextNumber(0, 0.25), tone(g, ragColor, 0.08), s > 0)
		rag(g, leg, "Rag", CFrame.new(-0.05 * s, 0.98, 0.54), 0.66, 1.45 + rng:NextNumber(0, 0.25), tone(g, ragColor, 0.08), s < 0)
	end

	-- Дубина: позвоночник с позвонками, на конце череп (смотрит вперёд и вверх — виден и от первого лица)
	local grip = CFrame.new(0, -0.8, 0) * A(12, 0, -20)
	local arm = "Right Arm"
	shaft(g, arm, "Club", grip * CFrame.new(0, 0, -0.95), 2.35, 0.16, bone)
	for i, z in { -0.72, -1.14, -1.56 } do
		shaft(g, arm, "Club", grip * CFrame.new(0, 0, z) * A(0, 0, i * 40), 0.14, 0.3, tone(g, bone, 0.06))
	end
	local skull = grip * CFrame.new(0, 0.06, -2.36) * A(45, 0, 0)
	put(g, arm, "Skull", "Ball", skull * CFrame.new(0, 0.06, 0.04), Vector3.one * 0.64, P.Bone)
	put(g, arm, "Skull", "Block", skull * CFrame.new(0, -0.14, -0.14), Vector3.new(0.44, 0.34, 0.3), P.OldBone)
	for _, s in { -1, 1 } do
		put(g, arm, "Skull", "Block", skull * CFrame.new(0.12 * s, 0.02, -0.28), Vector3.new(0.14, 0.13, 0.06), Color3.fromRGB(22, 17, 14))
	end

	-- Колокол в левой руке: ось наклонена так, что при поднятой руке (поза Призрака) он висит отвесно
	local bell = CFrame.new(0, -0.82, -0.05) * A(-50, 0, 0)
	disc(g, "Left Arm", "Bell", bell * CFrame.new(0, -0.1, 0), 0.75, 0.15, P.DarkWood, Mat.Wood)
	put(g, "Left Arm", "Bell", "Ball", bell * CFrame.new(0, -0.52, 0), Vector3.one * 0.34, bronze, Mat.Metal)
	disc(g, "Left Arm", "Bell", bell * CFrame.new(0, -0.78, 0), 0.36, 0.6, bronze, Mat.Metal)
	disc(g, "Left Arm", "Bell", bell * CFrame.new(0, -1.08, 0), 0.32, 0.82, tone(g, bronze, 0.04), Mat.Metal)
	disc(g, "Left Arm", "Bell", bell * CFrame.new(0, -1.27, 0), 0.1, 0.94, Kit.dark(bronze, 0.25), Mat.CorrodedMetal)
	put(g, "Left Arm", "Bell", "Ball", bell * CFrame.new(0, -1.4, 0), Vector3.one * 0.2, P.Iron, Mat.Metal)
end

------------------------------------------------------------------------

function KillerGear.dress(char: Model, def)
	for _, d in char:GetDescendants() do
		if d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") or d:IsA("Accessory") or d:IsA("BodyColors") then
			d:Destroy()
		end
	end
	local head = char:FindFirstChild("Head") :: BasePart?
	if head then
		for _, d in head:GetChildren() do
			if d:IsA("Decal") then
				d:Destroy()
			end
		end
	end
	local limbs: { [string]: BasePart } = {}
	local found = 0
	for _, name in LIMBS do
		local p = char:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			limbs[name] = p
			found += 1
			p.Color = (name == "Torso" or name == "Left Leg" or name == "Right Leg") and def.ClothColor or def.BodyColor
		end
	end
	local builder = GEAR[def.Id]
	if builder and found == #LIMBS then
		-- Голову целиком заменяет снаряжение
		limbs.Head.Transparency = 1
		-- Постоянное зерно на маньяка: внешний вид одинаков в каждом матче
		local seed = 0
		for i = 1, #def.Id do
			seed += string.byte(def.Id, i) * i
		end
		builder({ char = char, limbs = limbs, rng = Random.new(seed) }, def)
	end
	-- Красное пятно перед маньяком (видят выжившие)
	if head then
		local stain = Instance.new("SpotLight")
		stain.Name = "RedStain"
		stain.Color = Color3.fromRGB(255, 20, 20)
		stain.Range = 24
		stain.Angle = 35
		stain.Brightness = 4
		stain.Face = Enum.NormalId.Front
		stain.Parent = head
	end
end

return KillerGear
