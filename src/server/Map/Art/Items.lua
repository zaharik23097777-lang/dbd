-- Предметы выживших в руке: аптечка, ящик с инструментами, фонарик.
-- ItemArt.held(item, arm) возвращает Model, приваренную к руке (Massless, без столкновений).
-- У фонарика внутри должен быть SpotLight с именем "Beam" (светит вдоль руки, Enabled = false).
-- Координаты деталей — в пространстве кисти: начало в центре низа руки, +Y — вверх по руке,
-- -Z — вперёд. Аптечку и ящик несут за ручку, как чемодан (узкой стороной к ноге, чтобы не
-- пересекаться с ней), фонарик зажат в кулаке и смотрит вдоль руки.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Kit = require(script.Parent.Kit)

local ItemArt = {}

local A = Kit.A
local P = Kit.Palette
local Mat = Enum.Material

local function finish(m: Model, arm: BasePart)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.Massless = true
			Kit.decor(d)
			Util.weld(arm, d)
		end
	end
end

-- Цилиндр вдоль руки (ось Y кисти); его грань Left смотрит из кулака наружу
local function along(m: Model, hand: CFrame, y: number, length: number, diameter: number, color: Color3, material: Enum.Material?, z: number?): BasePart
	return Kit.cyl(m, hand * CFrame.new(0, y, z or 0) * A(0, 0, 90), length, diameter, color, material)
end

-- Цилиндр между точками (в пространстве кисти)
local function rod(m: Model, hand: CFrame, a: Vector3, b: Vector3, diameter: number, color: Color3, material: Enum.Material?)
	Kit.rod(m, hand:PointToWorldSpace(a), hand:PointToWorldSpace(b), diameter, color, material)
end

-- Ручка-скоба сверху: две стойки и перекладина в кулаке
local function carryHandle(m: Model, hand: CFrame, top: number, span: number, color: Color3)
	for _, z in { -span / 2, span / 2 } do
		Kit.box(m, hand * CFrame.new(0, (top + 0.08) / 2, z), Vector3.new(0.08, 0.08 - top, 0.08), color, Mat.Metal)
	end
	Kit.cyl(m, hand * CFrame.new(0, 0.06, 0) * A(0, 90, 0), span + 0.08, 0.1, P.Rubber, Mat.Rubber)
end

------------------------------------------------------------------------
-- Аптечка: облупленный красный жестяной ящик, белая панель с крестом с обеих сторон,
-- скруглённая крышка, защёлки, торчащий из-под крышки бинт
------------------------------------------------------------------------

local function medkit(m: Model, hand: CFrame, rng: Random): BasePart
	local red = Kit.jitter(Color3.fromRGB(132, 34, 28), 0.03, rng)
	local body = Kit.box(m, hand * CFrame.new(0, -0.76, 0), Vector3.new(0.42, 0.56, 1.12), red, Mat.Metal)
	Kit.box(m, hand * CFrame.new(0, -0.43, 0), Vector3.new(0.44, 0.12, 1.14), Kit.dark(red, 0.15), Mat.Metal)
	Kit.box(m, hand * CFrame.new(0, -0.35, 0), Vector3.new(0.24, 0.05, 1.1), Kit.dark(red, 0.1), Mat.Metal)
	for _, s in { -1, 1 } do
		Kit.wedge(m, hand * CFrame.new(0.17 * s, -0.35, 0) * A(0, -90 * s, 0), Vector3.new(1.1, 0.05, 0.1), Kit.dark(red, 0.1), Mat.Metal)
	end
	-- Панель и крест проходят ящик насквозь: видны с обеих сторон одной деталью
	local white = Color3.fromRGB(206, 200, 184)
	Kit.box(m, hand * CFrame.new(0, -0.74, 0.02), Vector3.new(0.45, 0.4, 0.42), white, Mat.SmoothPlastic)
	local cross = Color3.fromRGB(150, 26, 24)
	Kit.box(m, hand * CFrame.new(0, -0.74, 0.02), Vector3.new(0.46, 0.28, 0.09), cross, Mat.SmoothPlastic)
	Kit.box(m, hand * CFrame.new(0, -0.74, 0.02), Vector3.new(0.46, 0.09, 0.28), cross, Mat.SmoothPlastic)
	for _, z in { -0.36, 0.36 } do
		Kit.box(m, hand * CFrame.new(0, -0.46, z), Vector3.new(0.46, 0.13, 0.08), P.Steel, Mat.Metal)
	end
	-- Бинт, зажатый крышкой, свисает по боку
	Kit.box(m, hand * CFrame.new(0.225, -0.62, 0.48) * A(0, 0, 6), Vector3.new(0.02, 0.38, 0.13), Color3.fromRGB(196, 190, 172), Mat.Fabric)
	carryHandle(m, hand, -0.32, 0.56, P.DarkSteel)
	return body
end

------------------------------------------------------------------------
-- Ящик с инструментами: мятый открытый лоток из синей облезлой жести с ручкой вдоль,
-- из него торчат отвёртка, гаечный ключ и молоток
------------------------------------------------------------------------

local function toolbox(m: Model, hand: CFrame, rng: Random): BasePart
	local paint = Kit.jitter(Color3.fromRGB(90, 116, 126), 0.03, rng)
	local body = Kit.box(m, hand * CFrame.new(0, -0.98, 0), Vector3.new(0.6, 0.56, 1.4), paint, Mat.Metal)
	-- Борта лотка; правый помят (наклонён внутрь)
	Kit.box(m, hand * CFrame.new(-0.275, -0.58, 0), Vector3.new(0.05, 0.3, 1.4), Kit.dark(paint, 0.12), Mat.Metal)
	Kit.box(m, hand * CFrame.new(0.27, -0.58, 0.1) * A(0, 0, 6), Vector3.new(0.05, 0.3, 1.2), Kit.dark(paint, 0.12), Mat.Metal)
	for _, z in { -0.675, 0.675 } do
		Kit.box(m, hand * CFrame.new(0, -0.58, z), Vector3.new(0.6, 0.3, 0.05), Kit.dark(paint, 0.12), Mat.Metal)
	end
	-- Ржавая вмятина на боку и защёлки
	Kit.box(m, hand * CFrame.new(0.302, -1.02, -0.25) * A(4, 0, 0), Vector3.new(0.02, 0.26, 0.42), P.DarkRust, Mat.CorrodedMetal)
	for _, z in { -0.45, 0.45 } do
		Kit.box(m, hand * CFrame.new(0, -0.78, z), Vector3.new(0.62, 0.12, 0.1), P.Steel, Mat.Metal)
	end
	carryHandle(m, hand, -0.45, 1.2, P.DarkSteel)
	-- Отвёртка лежит наискось, жало торчит за торец
	rod(m, hand, Vector3.new(0.1, -0.6, 0.12), Vector3.new(0.12, -0.44, 0.52), 0.15, Color3.fromRGB(176, 120, 40), Mat.SmoothPlastic)
	rod(m, hand, Vector3.new(0.12, -0.44, 0.52), Vector3.new(0.14, -0.3, 0.98), 0.05, P.Steel, Mat.Metal)
	-- Гаечный ключ торчит вверх у переднего торца
	local chrome = Color3.fromRGB(150, 150, 146)
	rod(m, hand, Vector3.new(-0.12, -0.75, -0.5), Vector3.new(-0.16, -0.1, -0.64), 0.08, chrome, Mat.Metal)
	Kit.box(m, hand * CFrame.new(-0.16, -0.05, -0.65) * A(-10, 0, 0), Vector3.new(0.06, 0.14, 0.3), chrome, Mat.Metal)
	-- Молоток: рукоять из лотка, головка поперёк
	rod(m, hand, Vector3.new(0.12, -0.75, -0.25), Vector3.new(0.22, -0.2, -0.38), 0.09, P.Plank, Mat.Wood)
	Kit.box(m, hand * CFrame.new(0.22, -0.17, -0.38) * A(0, 0, 8), Vector3.new(0.14, 0.14, 0.42), P.Iron, Mat.Metal)
	return body
end

------------------------------------------------------------------------
-- Фонарик: тёмный корпус с резиновыми кольцами, кнопка, изолента, клипса,
-- широкая голова с хромированным ободом и стеклом. Луч светит из стекла вдоль руки.
------------------------------------------------------------------------

local function flashlight(m: Model, hand: CFrame, rng: Random): BasePart
	local z = -0.2 -- держим ближе к пальцам
	local metal = Kit.jitter(Color3.fromRGB(52, 54, 56), 0.03, rng)
	local body = along(m, hand, -0.15, 0.95, 0.28, metal, Mat.Metal, z)
	for _, y in { -0.08, -0.2, -0.32 } do
		along(m, hand, y, 0.06, 0.31, P.Rubber, Mat.Rubber, z)
	end
	Kit.box(m, hand * CFrame.new(0, -0.44, z - 0.15), Vector3.new(0.1, 0.13, 0.06), Color3.fromRGB(150, 70, 36), Mat.Rubber)
	along(m, hand, -0.6, 0.09, 0.295, Color3.fromRGB(112, 110, 102), Mat.Fabric, z)
	Kit.box(m, hand * CFrame.new(-0.15, -0.45, z), Vector3.new(0.04, 0.24, 0.07), P.Steel, Mat.Metal)
	along(m, hand, -0.68, 0.12, 0.35, metal, Mat.Metal, z)
	local head = along(m, hand, -0.89, 0.3, 0.44, Kit.dark(metal, 0.1), Mat.Metal, z)
	along(m, hand, -1.06, 0.06, 0.48, Color3.fromRGB(150, 150, 146), Mat.Metal, z)
	along(m, hand, -1.085, 0.02, 0.38, Color3.fromRGB(226, 224, 204), Mat.Glass, z).Transparency = 0.15
	local beam = Kit.spotLight(head, Color3.fromRGB(255, 250, 220), Config.FlashlightRange + 4, Config.FlashlightAngle * 2.5, 6, Enum.NormalId.Left, true)
	beam.Name = "Beam"
	beam.Enabled = false
	return body
end

local BUILD: { [string]: (Model, CFrame, Random) -> BasePart } = {
	Medkit = medkit,
	Toolbox = toolbox,
	Flashlight = flashlight,
}

-- Кисть руки R6 — низ детали "Right Arm"; локальная -Y руки = направление, куда указывает рука
function ItemArt.held(item: string, arm: BasePart): Model
	local m = Kit.model("HeldItem")
	local hand = arm.CFrame * CFrame.new(0, -arm.Size.Y / 2, 0)
	local build = BUILD[item] or BUILD.Medkit
	m.PrimaryPart = build(m, hand, Random.new(#item))
	finish(m, arm)
	return m
end

return ItemArt
