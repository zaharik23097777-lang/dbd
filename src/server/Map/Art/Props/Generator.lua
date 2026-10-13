-- Генератор (как в DBD): стальные салазки на опорах, двигатель с рёбрами охлаждения и двумя поршнями,
-- маховик с ремнём, динамо, топливный бак, выхлоп, щиток со шкалами и 4 лампами прогресса, лампа в клетке.
-- Модель строится в начале координат: земля y = 0, «перед» модели смотрит в -Z.
-- Сталкивается только невидимый корпус Body 4x3x3 (центр y = 2): его обходят и чинят со всех четырёх сторон,
-- поэтому всё видимое — без столкновений и почти не выступает за его габарит.
-- Требования — Art/Contract.lua; поршни (AnimatedPiston) качает клиент (client/Effects.lua) по своей оси X.
local Kit = require(script.Parent.Parent.Kit)

local P = Kit.Palette
local Mat = Kit.Mat
local A = Kit.A
local V = Vector3.new
local C = CFrame.new

local M = {}
local T = {}
M.Templates = T

-- Крупные видимые детали: не сталкиваются (это делает корпус), но отбрасывают тень
local SOLID = { CanCollide = false, CanQuery = false, CanTouch = false }
local DECOR = { Decor = true }

local LIGHT_OFF = Color3.fromRGB(45, 40, 30) -- как в PropFX

-- Варианты окраски и набора деталей (геймплей одинаковый)
type Look = {
	Paint: Color3, -- краска корпусов
	Tank: Color3, -- топливный бак
	Engine: Color3, -- чугун двигателя
	TwinExhaust: boolean,
	JerryCan: boolean,
	Damaged: boolean, -- погнутая клетка, сорванная крышка щитка, тряпка
}

local LOOKS: { Look } = {
	{ Paint = Color3.fromRGB(70, 84, 66), Tank = Color3.fromRGB(96, 40, 32), Engine = Color3.fromRGB(54, 56, 58), TwinExhaust = true, JerryCan = false, Damaged = false },
	{ Paint = Color3.fromRGB(104, 62, 50), Tank = Color3.fromRGB(66, 72, 58), Engine = Color3.fromRGB(48, 46, 46), TwinExhaust = false, JerryCan = true, Damaged = false },
	{ Paint = Color3.fromRGB(110, 98, 68), Tank = Color3.fromRGB(88, 54, 36), Engine = Color3.fromRGB(58, 56, 52), TwinExhaust = false, JerryCan = false, Damaged = true },
}

-- Цилиндр вдоль мировой оси Z (торец Right смотрит в -Z)
local function zcyl(m: Model, pos: Vector3, length: number, diameter: number, color: Color3, material: Enum.Material, extra: Kit.Props?): BasePart
	return Kit.cyl(m, C(pos) * A(0, 90, 0), length, diameter, color, material, extra)
end

-- Салазки: два полоза со скошенными концами на четырёх опорах, рифлёная палуба
local function skid(m: Model, rng: Random, look: Look)
	local frame = Kit.jitter(P.DarkRust, 0.04, rng)
	for _, z in { -1.2, 1.2 } do
		Kit.box(m, C(0, 0.36, z), V(3.8, 0.42, 0.36), frame, Mat.CorrodedMetal, SOLID)
		for _, sx in { -1, 1 } do
			-- клин: высокая сторона смотрит внутрь, скос — наружу
			Kit.wedge(m, C(sx * 2.06, 0.36, z) * A(0, -sx * 90, 0), V(0.36, 0.42, 0.32), frame, Mat.CorrodedMetal, DECOR)
			Kit.box(m, C(sx * 1.6, 0.075, z), V(0.62, 0.15, 0.62), Kit.dark(frame, 0.3), Mat.Metal, DECOR)
		end
	end
	Kit.box(m, C(0, 0.64, 0), V(4, 0.14, 2.9), Kit.jitter(Kit.dark(look.Paint, 0.35), 0.03, rng), Mat.DiamondPlate, SOLID)
end

-- Двигатель: картер, блок с рёбрами, головка, две гильзы с поршнями
local function engine(m: Model, rng: Random, look: Look)
	local iron = Kit.jitter(look.Engine, 0.03, rng)
	local crank = Kit.box(m, C(-0.95, 1.35, 0.05), V(1.9, 1.28, 2.1), iron, Mat.Metal, SOLID)
	Kit.grime(crank, Enum.NormalId.Front, 0.7)
	Kit.box(m, C(-0.95, 2.4, 0.05), V(1.5, 0.82, 1.6), Kit.dark(iron, 0.15), Mat.Metal, SOLID)
	for i = 0, 2 do
		Kit.box(m, C(-0.95, 2.14 + i * 0.26, 0.05), V(1.8, 0.07, 1.9), Kit.jitter(P.DarkSteel, 0.04, rng), Mat.Metal, DECOR)
	end
	Kit.box(m, C(-0.95, 2.98, 0.05), V(1.7, 0.34, 1.75), Kit.jitter(look.Paint, 0.04, rng), Mat.Metal, SOLID)
	for i, x in { -1.35, -0.55 } do
		Kit.vcyl(m, C(x, 3.42, 0.05), 0.55, 0.62, P.DarkSteel, Mat.Metal, DECOR)
		local rod = Kit.vcyl(m, C(x, 3.95, 0.05), 1.0, 0.4, Kit.jitter(P.Steel, 0.05, rng), Mat.Metal, DECOR)
		rod.Name = "Piston" .. i
		rod:SetAttribute("AnimatedPiston", true)
	end
end

-- Маховик на левом торце, шкив вентилятора и ремень между ними
local function flywheel(m: Model, rng: Random)
	local iron = Kit.jitter(P.Iron, 0.04, rng)
	local c1, r1 = V(-2.05, 1.62, -0.25), 0.9
	local c2, r2 = V(-2.05, 3.0, 0.5), 0.3
	Kit.cyl(m, C(c1), 0.22, r1 * 2, iron, Mat.Metal, SOLID)
	Kit.cyl(m, C(c1 - V(0.06, 0, 0)), 0.42, 0.45, P.DarkSteel, Mat.Metal, DECOR)
	for _, a in { 25, -65 } do
		Kit.box(m, C(c1 - V(0.13, 0, 0)) * A(a, 0, 0), V(0.06, r1 * 1.8, 0.16), Kit.dark(iron, 0.3), Mat.Metal, DECOR)
	end
	Kit.cyl(m, C(c2), 0.2, r2 * 2, P.DarkSteel, Mat.Metal, DECOR)
	-- Ремень: две касательные (без учёта разницы радиусов — на глаз не видно)
	local dir = (c2 - c1).Unit
	local n = Vector3.new(1, 0, 0):Cross(dir).Unit
	for _, s in { 1, -1 } do
		Kit.bar(m, c1 + n * s * r1, c2 + n * s * r2, 0.2, P.Rubber, Mat.Rubber, DECOR, 0.07)
	end
end

-- Динамо, щиток с лампами прогресса и шкалами, радиатор сзади
local function dynamo(m: Model, rng: Random, look: Look)
	local paint = Kit.jitter(look.Paint, 0.04, rng)
	Kit.cyl(m, C(1.0, 1.42, 0.35), 1.7, 1.4, paint, Mat.Metal, SOLID)
	Kit.cyl(m, C(1.9, 1.42, 0.35), 0.16, 1.15, P.DarkSteel, Mat.Metal, DECOR)
	local cabinet = Kit.box(m, C(1.0, 1.55, -0.95), V(1.8, 1.65, 0.9), paint, Mat.Metal, SOLID)
	Kit.rustStreaks(cabinet, Enum.NormalId.Front, rng, 6)
	Kit.box(m, C(1.0, 2.13, -1.44), V(1.72, 0.44, 0.1), P.Black, Mat.Metal, DECOR)
	Kit.box(m, C(1.0, 2.4, -1.55) * A(-12, 0, 0), V(1.8, 0.06, 0.34), Kit.dark(paint, 0.2), Mat.Metal, DECOR)
	for i = 1, 4 do
		local lamp = zcyl(m, V(0.4 + (i - 1) * 0.4, 2.13, -1.5), 0.12, 0.3, LIGHT_OFF, Mat.Glass, DECOR)
		lamp.Name = "ProgressLight" .. i
		lamp:SetAttribute("ProgressLight", i)
	end
	for i, x in { 0.55, 1.4 } do
		local g = zcyl(m, V(x, 1.42, -1.44), 0.1, 0.52, P.DarkSteel, Mat.Metal, DECOR)
		Kit.gauge(g, Enum.NormalId.Right, rng:NextNumber(0.1, 0.9) * i / 2)
	end
	Kit.box(m, C(0.97, 0.95, -1.44), V(0.2, 0.3, 0.1), Kit.jitter(P.Blood, 0.05, rng), Mat.Metal, DECOR)
	-- Лючок обслуживания на боковой стенке щитка
	Kit.box(m, C(1.93, 1.5, -0.95), V(0.05, 1.15, 0.62), Kit.jitter(Kit.dark(paint, 0.12), 0.04, rng), Mat.Metal, DECOR)
	local radiator = Kit.box(m, C(1.0, 1.5, 1.27), V(1.5, 1.4, 0.25), Kit.dark(paint, 0.25), Mat.Metal, SOLID)
	Kit.grime(radiator, Enum.NormalId.Back, 0.6)
	for i = 0, 2 do
		Kit.box(m, C(1.0, 1.1 + i * 0.4, 1.42), V(1.42, 0.09, 0.06), P.Iron, Mat.Metal, DECOR)
	end
end

-- Топливный бак на ложементе: два хомута и крышка горловины
local function tank(m: Model, rng: Random, look: Look)
	local color = Kit.jitter(look.Tank, 0.05, rng)
	Kit.cyl(m, C(1.0, 2.86, 0.3), 1.8, 1.05, color, Mat.CorrodedMetal, SOLID)
	Kit.box(m, C(1.0, 2.25, 0.45), V(1.5, 0.25, 0.8), P.DarkSteel, Mat.Metal, DECOR)
	for _, x in { 0.45, 1.55 } do
		Kit.cyl(m, C(x, 2.86, 0.3), 0.08, 1.11, P.Iron, Mat.CorrodedMetal, DECOR)
	end
	Kit.vcyl(m, C(1.45, 3.43, 0.3), 0.18, 0.3, P.DarkSteel, Mat.Metal, DECOR)
end

-- Выхлоп: колено из блока, вертикальная труба, (глушитель), наклонный срез сверху
local function exhaust(m: Model, x: number, height: number, muffler: boolean)
	local rust = P.Rust
	Kit.rod(m, V(x, 2.4, 1.0), V(x, 2.4, 1.38), 0.26, rust, Mat.CorrodedMetal, DECOR)
	Kit.rod(m, V(x, 2.3, 1.38), V(x, height, 1.38), 0.24, rust, Mat.CorrodedMetal, DECOR)
	if muffler then
		Kit.vcyl(m, C(x, 3.3, 1.38), 0.9, 0.42, Kit.dark(rust, 0.35), Mat.CorrodedMetal, DECOR)
	end
	Kit.box(m, C(x, height + 0.06, 1.38) * A(30, 0, 0), V(0.32, 0.04, 0.36), P.Iron, Mat.Metal, DECOR)
end

-- Лампа в проволочной клетке на стойке (горит, когда генератор починен)
local function bulb(m: Model, look: Look)
	local base = V(0.15, 3.75, -0.55)
	Kit.rod(m, V(base.X, 2.37, base.Z), base, 0.14, P.DarkSteel, Mat.Metal, DECOR)
	Kit.vcyl(m, C(base), 0.1, 0.78, P.Iron, Mat.Metal, DECOR)
	local b = Kit.ball(m, C(base + V(0, 0.15, 0)), 0.42, Color3.fromRGB(60, 60, 50), Mat.Glass, DECOR)
	b.Name = "Bulb"
	b:SetAttribute("Bulb", true)
	local light = Kit.pointLight(b, Color3.fromRGB(255, 226, 150), 18, 2.2)
	light.Enabled = false
	local tilt = look.Damaged and A(0, 0, 14) or CFrame.identity
	Kit.arc(m, C(base) * tilt, 0.37, 0, 180, 3, 0.05, P.Iron, Mat.Metal, DECOR)
	if not look.Damaged then
		Kit.arc(m, C(base) * A(0, 90, 0), 0.37, 0, 180, 3, 0.05, P.Iron, Mat.Metal, DECOR)
	end
end

-- Провисающие кабели между щитком, двигателем и стойкой лампы
local function cables(m: Model)
	Kit.cable(m, Kit.sag(V(0.12, 2.25, -1.25), V(-0.85, 2.95, -0.86), 0.35, 3), 0.1, P.Rubber, Mat.Rubber, DECOR)
	Kit.cable(m, Kit.sag(V(0.15, 3.5, -0.55), V(1.8, 2.3, -1.38), 0.45, 3), 0.08, P.Black, Mat.Rubber, DECOR)
end

-- Канистра у полоза (вариант)
local function jerryCan(m: Model, rng: Random)
	local cf = C(2.25, 0.55, 0.55) * A(0, -12, 0)
	Kit.box(m, cf, V(0.42, 1.1, 0.8), Kit.jitter(Color3.fromRGB(86, 42, 34), 0.05, rng), Mat.Metal, DECOR)
	Kit.box(m, cf * C(0, 0.62, 0.12), V(0.14, 0.14, 0.4), P.DarkSteel, Mat.Metal, DECOR)
end

-- Повреждения (вариант): оторванная крышка щитка у полоза и промасленная тряпка на баке
local function damage(m: Model, rng: Random, look: Look)
	Kit.box(m, C(1.3, 0.2, -1.75) * A(-70, 18, 0), V(1.0, 0.07, 0.8), Kit.jitter(look.Paint, 0.06, rng), Mat.Metal, DECOR)
	Kit.box(m, C(0.75, 3.38, 0.25) * A(0, 0, -6), V(0.8, 0.06, 1.0), Kit.jitter(P.Fabric, 0.06, rng), Mat.Fabric, DECOR)
	Kit.box(m, C(0.4, 3.02, -0.27) * A(-72, 0, -4), V(0.75, 0.05, 0.6), Kit.jitter(P.Fabric, 0.06, rng), Mat.Fabric, DECOR)
end

T.Generator = {
	Variants = #LOOKS,
	Build = function(rng: Random, variant: number)
		local look = LOOKS[(variant - 1) % #LOOKS + 1]
		local m = Kit.model("Generator")
		m:SetAttribute("Kind", "Generator")
		-- Невидимый корпус: столкновения, звук, точка искр
		local body = Kit.box(m, C(0, 2, 0), V(4, 3, 3), P.DarkSteel, Mat.SmoothPlastic, { Transparency = 1, CastShadow = false })
		body.Name = "Body"
		Kit.setOrigin(m, body)
		local fx = Instance.new("Attachment")
		fx.Name = "FX"
		fx.Position = V(-0.95, 1.4, 0.05)
		fx.Parent = body

		skid(m, rng, look)
		engine(m, rng, look)
		flywheel(m, rng)
		dynamo(m, rng, look)
		tank(m, rng, look)
		exhaust(m, -1.35, 4.9, true)
		if look.TwinExhaust then
			exhaust(m, -0.55, 4.5, false)
		end
		bulb(m, look)
		cables(m)
		if look.JerryCan then
			jerryCan(m, rng)
		end
		if look.Damaged then
			damage(m, rng, look)
		end

		m:SetAttribute("Progress", 0)
		m:SetAttribute("Done", false)
		m:SetAttribute("Regressing", false)
		return m
	end,
}

return M
