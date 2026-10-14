-- Шкафчик
-- Модель строится в начале координат: земля y = 0, «перед» модели смотрит в -Z.
-- Требования — Art/Contract.lua; подвижные части — Kit.movable (см. Map/PropFX.lua).
local Kit = require(script.Parent.Parent.Kit)

local P = Kit.Palette
local Mat = Kit.Mat
local A = Kit.A
local V = Vector3.new
local C = CFrame.new

local M = {}
local T = {}
M.Templates = T

------------------------------------------------------------------------
-- Старый стальной шкафчик (опора — пол в центре, дверь спереди -Z, петли слева по -X).
-- Внутри свободный объём под выжившего (точка Inside), перед дверью ~3 стада свободного места.
------------------------------------------------------------------------

local W, D = 3.2, 2.6 -- наружные ширина и глубина
local TOP = 7.2 -- верх стенок
local DOOR_Y0, DOOR_Y1 = 0.62, 6.83 -- проём двери по высоте
local DOOR_Z = -D / 2 + 0.03 -- центр двери чуть впереди кромок боковин
local HINGE_X = -1.42

local DECOR = { Decor = true }

-- Варианты: краска, материал корпуса, наклонная крыша, тряпка в двери, приоткрытая дверь, коробка сверху
type Style = {
	Paint: Color3,
	Body: Enum.Material,
	Door: Color3?, -- дверь от другого шкафчика (своя краска), иначе в цвет корпуса
	BottomVents: boolean,
	Padlock: boolean,
	SlopedTop: boolean,
	Ajar: number, -- угол, на который дверь приоткрыта в закрытом состоянии
	Rag: boolean,
	Box: boolean,
	Rust: number, -- сколько ржавых пятен-деталей
	Number: string,
}

local STYLES: { Style } = {
	{ Paint = Color3.fromRGB(72, 92, 90), Body = Mat.Metal, BottomVents = true, Padlock = true, SlopedTop = false, Ajar = 0, Rag = false, Box = true, Rust = 2, Number = "17" },
	{ Paint = Color3.fromRGB(84, 86, 66), Body = Mat.Metal, BottomVents = true, Padlock = false, SlopedTop = false, Ajar = 3, Rag = true, Box = false, Rust = 3, Number = "4" },
	{ Paint = Color3.fromRGB(96, 60, 46), Body = Mat.CorrodedMetal, BottomVents = false, Padlock = false, SlopedTop = true, Ajar = 0, Rag = false, Box = false, Rust = 3, Number = "31", Door = Color3.fromRGB(80, 88, 92) },
}

local function frame(parent: Instance, props: { [string]: any }): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in props do
		(f :: any)[k] = v
	end
	f.Parent = parent
	return f
end

local function fade(f: Frame, rotation: number, from: number, to: number)
	local g = Instance.new("UIGradient")
	g.Rotation = rotation
	g.Transparency = NumberSequence.new(from, to)
	g.Parent = f
end

-- Износ одной грани в одном SurfaceGui: грязь снизу, ржавые потёки и вмятины (тёмная тень с бликом снизу)
local function weathering(part: BasePart, face: Enum.NormalId, rng: Random, streaks: number, dents: number)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 1
	gui.MaxDistance = 90
	gui.Parent = part
	local grime = frame(gui, { Position = UDim2.fromScale(0, 0.62), Size = UDim2.fromScale(1, 0.38), BackgroundColor3 = Color3.fromRGB(32, 24, 18) })
	fade(grime, 90, 1, 0.3)
	for _ = 1, streaks do
		local streak = frame(gui, {
			Position = UDim2.fromScale(rng:NextNumber(0.05, 0.9), rng:NextNumber(0, 0.35)),
			Size = UDim2.fromScale(rng:NextNumber(0.015, 0.045), rng:NextNumber(0.15, 0.45)),
			BackgroundColor3 = Kit.jitter(P.Rust, 0.08, rng),
			BackgroundTransparency = rng:NextNumber(0.25, 0.5),
		})
		fade(streak, 90, 0, 1)
	end
	for _ = 1, dents do
		local x, y, s = rng:NextNumber(0.2, 0.8), rng:NextNumber(0.25, 0.75), rng:NextInteger(8, 16)
		local dent = frame(gui, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromOffset(s, s * 0.7),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.55,
		})
		fade(dent, 90, 0, 1)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = dent
		local glint = frame(dent, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.75),
			Size = UDim2.fromScale(0.8, 0.22),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.82,
		})
		local c2 = Instance.new("UICorner")
		c2.CornerRadius = UDim.new(0.5, 0)
		c2.Parent = glint
	end
	return gui
end

-- Жалюзи: тёмная подложка и ряд наклонных козырьков (клин: толстый низ — щель, верх сливается с дверью)
local function louvres(parts: { BasePart }, m: Model, door: CFrame, y: number, count: number, paint: Color3)
	local step = 0.16
	local h = count * step
	table.insert(parts, Kit.box(m, door * C(0, y, -0.045), V(1.74, h + 0.06, 0.01), Kit.dark(paint, 0.8), Mat.SmoothPlastic, DECOR))
	for i = 0, count - 1 do
		local ly = y - h / 2 + step * (i + 0.5)
		table.insert(parts, Kit.wedge(m, door * C(0, ly, -0.08), V(1.62, 0.11, 0.07), Kit.dark(paint, 0.05), Mat.Metal, DECOR))
	end
end

T.Locker = {
	Variants = 3,
	Build = function(rng: Random, variant: number)
		local s = STYLES[variant] or STYLES[1]
		local m = Kit.model("Locker")
		m:SetAttribute("Kind", "Locker")
		local paint = Kit.jitter(s.Paint, 0.04, rng)
		local dark = Kit.dark(paint, 0.35)
		local rust = Kit.jitter(P.Rust, 0.06, rng)

		-- Корпус (сталкивается)
		local back = Kit.box(m, C(0, (TOP + 0.3) / 2, D / 2 - 0.08), V(W, TOP - 0.3, 0.16), paint, s.Body)
		back.Name = "Back"
		Kit.setOrigin(m, back)
		local sides = {}
		for _, sx in { -1, 1 } do
			table.insert(sides, Kit.box(m, C(sx * (W / 2 - 0.08), (TOP + 0.3) / 2, 0), V(0.16, TOP - 0.3, D), paint, s.Body))
		end
		Kit.box(m, C(0, 0.17, 0.05), V(W - 0.2, 0.34, D - 0.2), Kit.dark(paint, 0.55), Mat.Metal)
		local cap = Kit.box(m, C(0, TOP + 0.07, 0), V(W + 0.12, 0.14, D + 0.12), Kit.dark(paint, 0.12), s.Body)
		if s.SlopedTop then
			-- наклонная крыша: высокая сторона сзади, скат к двери
			Kit.wedge(m, C(0, TOP + 0.14 + 0.35, 0), V(W + 0.12, 0.7, D + 0.12), Kit.dark(paint, 0.08), s.Body)
		end
		-- рамка проёма: перемычка сверху и цоколь снизу
		Kit.box(m, C(0, (DOOR_Y1 + TOP) / 2 + 0.01, -D / 2 + 0.05), V(W - 0.32, TOP - DOOR_Y1, 0.1), Kit.dark(paint, 0.1), s.Body, DECOR)
		Kit.box(m, C(0, (0.34 + DOOR_Y0) / 2, -D / 2 + 0.05), V(W - 0.32, DOOR_Y0 - 0.34, 0.1), Kit.dark(paint, 0.25), Mat.DiamondPlate, DECOR)
		-- полка для шапки внутри (выше головы спрятавшегося)
		Kit.box(m, C(0, 6.15, 0.5), V(W - 0.32, 0.06, 1.3), dark, Mat.Metal, DECOR)

		-- Дверь (группа LockerDoor, открывается наружу на петлях по -X)
		local doorH = DOOR_Y1 - DOOR_Y0
		local closed = C(0, (DOOR_Y0 + DOOR_Y1) / 2, DOOR_Z)
		local hinge = C(HINGE_X, closed.Y, DOOR_Z)
		local door: { BasePart } = {}
		local doorPaint = s.Door and Kit.jitter(s.Door, 0.04, rng) or paint
		local doorMat = s.Door and Mat.Metal or s.Body
		local panel = Kit.box(m, closed, V(W - 0.38, doorH, 0.08), Kit.jitter(doorPaint, 0.03, rng), doorMat)
		panel.Name = "Door"
		table.insert(door, panel)
		-- выдавленная филёнка в нижней половине двери: на уровне глаз спрятавшегося дверь остаётся
		-- чистой (камера изнутри смотрит сквозь полупрозрачную деталь Door, см. CameraController)
		table.insert(door, Kit.box(m, closed * C(-0.1, -1.35, -0.05), V(1.9, 1.8, 0.02), Kit.jitter(doorPaint, 0.04, rng), doorMat, DECOR))
		louvres(door, m, closed, doorH / 2 - 0.55, 5, doorPaint)
		if s.BottomVents then
			louvres(door, m, closed, -doorH / 2 + 0.42, 3, doorPaint)
		end
		-- ручка-защёлка и накладка
		table.insert(door, Kit.box(m, closed * C(1.08, 0, -0.06), V(0.26, 0.9, 0.04), P.DarkSteel, Mat.Metal, DECOR))
		table.insert(door, Kit.box(m, closed * C(1.08, 0.06, -0.13), V(0.1, 0.44, 0.12), P.Steel, Mat.Metal, DECOR))
		if s.Padlock then
			table.insert(door, Kit.box(m, closed * C(1.08, -0.42, -0.13), V(0.2, 0.24, 0.1), Color3.fromRGB(120, 104, 64), Mat.Metal, DECOR))
			table.insert(door, Kit.cyl(m, closed * C(1.08, -0.27, -0.13) * A(0, 90, 0), 0.03, 0.17, P.Steel, Mat.Metal, DECOR))
		end
		-- петли
		for _, hy in { -doorH / 2 + 0.6, 0, doorH / 2 - 0.6 } do
			table.insert(door, Kit.vcyl(m, closed * C(HINGE_X + 0.01, hy, -0.04), 0.42, 0.12, P.Iron, Mat.Metal, DECOR))
		end
		-- табличка с номером
		local plate = Kit.box(m, closed * C(0, doorH / 2 - 1.2, -0.05), V(0.5, 0.26, 0.02), Color3.fromRGB(150, 140, 112), Mat.Metal, DECOR)
		Kit.label(plate, Enum.NormalId.Front, s.Number, Color3.fromRGB(30, 28, 24), Enum.Font.Oswald)
		table.insert(door, plate)
		-- ржавчина ползёт от нижней кромки двери: широкое пятно и «язык» повыше (неровный край)
		local rx = rng:NextNumber(-0.6, 0.2)
		table.insert(door, Kit.box(m, closed * C(rx, -doorH / 2 + 0.3, -0.045) * A(0, 0, rng:NextNumber(-4, 4)), V(rng:NextNumber(1.0, 1.4), 0.45, 0.012), rust, Mat.CorrodedMetal, DECOR))
		table.insert(door, Kit.box(m, closed * C(rx + rng:NextNumber(-0.3, 0.3), -doorH / 2 + 0.62, -0.046) * A(0, 0, rng:NextNumber(15, 30)), V(0.42, 0.3, 0.012), Kit.dark(rust, 0.12), Mat.CorrodedMetal, DECOR))
		-- и на боковинах у пола
		for i = 2, s.Rust do
			local sx = i % 2 == 0 and 1 or -1
			local z, h = rng:NextNumber(-0.6, 0.4), rng:NextNumber(0.45, 0.8)
			Kit.box(m, C(sx * (W / 2 + 0.003), 0.3 + h / 2, z) * A(rng:NextNumber(-7, 7), 0, 0), V(0.012, h, rng:NextNumber(1.0, 1.6)), Kit.jitter(Kit.dark(rust, 0.15), 0.06, rng), Mat.CorrodedMetal, DECOR)
		end
		if s.Rag then
			-- тряпка, зажатая дверью
			table.insert(door, Kit.box(m, closed * C(1.33, -0.6, -0.07) * A(0, 0, -7), V(0.24, 1.2, 0.03), Color3.fromRGB(96, 46, 38), Mat.Fabric, DECOR))
		end
		local ajar = Kit.aroundHinge(closed, hinge, A(0, s.Ajar, 0))
		local open = Kit.aroundHinge(closed, hinge, A(0, 100, 0))
		for _, p in door do
			local rel = closed:ToObjectSpace(p.CFrame)
			Kit.movable(m, p, "LockerDoor", ajar * rel, open * rel)
		end

		if s.Box then
			-- картонная коробка на крыше с отогнутым клапаном
			local boxCF = C(0.45, TOP + 0.14 + 0.42, 0.25) * A(0, rng:NextNumber(8, 20), 0)
			Kit.box(m, boxCF, V(1.4, 0.84, 1.1), Color3.fromRGB(118, 96, 68), Mat.Cardboard, DECOR)
			Kit.box(m, boxCF * C(0, 0.42, -0.55) * A(-35, 0, 0) * C(0, 0, -0.25), V(1.36, 0.02, 0.5), Color3.fromRGB(104, 84, 60), Mat.Cardboard, DECOR)
		end

		-- износ поверх деталей (SurfaceGui, без лишних деталей)
		weathering(panel, Enum.NormalId.Front, rng, 4, 2)
		weathering(sides[1], Enum.NormalId.Left, rng, 3, 1)
		weathering(sides[2], Enum.NormalId.Right, rng, 3, 1)
		weathering(cap, Enum.NormalId.Front, rng, 2, 0)

		local inside = Kit.box(m, C(0, 3, 0.2), V(1, 1, 1), P.Black, Mat.SmoothPlastic, { Decor = true, Transparency = 1 })
		inside.Name = "Inside"
		m:SetAttribute("Occupant", 0)
		return m
	end,
}

return M
