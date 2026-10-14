-- Сундук
-- Модель строится в начале координат: земля y = 0, «перед» модели смотрит в -Z.
-- Требования — Art/Contract.lua; подвижные части — Kit.movable (см. Map/PropFX.lua).
local Kit = require(script.Parent.Parent.Kit)

local Mat = Kit.Mat
local A = Kit.A
local V = Vector3.new
local C = CFrame.new

local M = {}
local T = {}
M.Templates = T

------------------------------------------------------------------------
-- Деревянный сундук: корпус на основании, оковка (полосы, углы, обод), замок, ручки по бокам.
-- Крышка (группа ChestLid) — полукруглая из досок с железными полосами, откидывается на петлях сзади.
------------------------------------------------------------------------

local W, D = 2.9, 1.9 -- корпус
local BASE_H = 0.16
local TOP = 1.55 -- верх корпуса = низ крышки
local ARCH_H = 0.5 -- высота свода крышки
local PLANKS = 4
local PLANK_T = 0.14
local BAND_X = 0.85 -- полосы оковки

local DECOR = { Decor = true }

type Style = {
	Wood: Color3,
	Iron: Color3, -- уголки, обод, ручки, накладка
	IronMat: Enum.Material,
	Band: Color3, -- полосы на корпусе и крышке: железо или кожаные ремни
	BandMat: Enum.Material,
	Lock: Color3,
	RopeHandles: boolean,
	MissingCorner: boolean,
	Ajar: number, -- крышка чуть приоткрыта в закрытом состоянии (градусы)
}

local STYLES: { Style } = {
	-- дуб, окованный чёрным железом, латунный замок
	{ Wood = Color3.fromRGB(92, 64, 44), Iron = Color3.fromRGB(46, 46, 48), IronMat = Mat.Metal, Band = Color3.fromRGB(46, 46, 48), BandMat = Mat.Metal, Lock = Color3.fromRGB(128, 106, 62), RopeHandles = false, MissingCorner = false, Ajar = 0 },
	-- серое выветренное дерево, всё в ржавчине, верёвочные ручки, крышка не закрывается до конца
	{ Wood = Color3.fromRGB(108, 98, 84), Iron = Color3.fromRGB(96, 58, 38), IronMat = Mat.CorrodedMetal, Band = Color3.fromRGB(100, 60, 40), BandMat = Mat.CorrodedMetal, Lock = Color3.fromRGB(90, 62, 44), RopeHandles = true, MissingCorner = true, Ajar = 4 },
	-- тёмный сундук с кожаными ремнями
	{ Wood = Color3.fromRGB(70, 48, 36), Iron = Color3.fromRGB(50, 50, 52), IronMat = Mat.Metal, Band = Color3.fromRGB(118, 82, 54), BandMat = Mat.Leather, Lock = Color3.fromRGB(78, 78, 80), RopeHandles = false, MissingCorner = false, Ajar = 0 },
}

-- Свод крышки: радиус и центр дуги (по хорде D и высоте ARCH_H)
local HALF = D / 2 + 0.02
local R = (HALF * HALF + ARCH_H * ARCH_H) / (2 * ARCH_H)
local CY = TOP + ARCH_H - R
local SPAN = math.deg(math.asin(HALF / R)) -- полуугол свода

-- Замочная скважина на передней грани накладки (SurfaceGui: кружок и щель)
local function keyhole(part: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 100
	gui.LightInfluence = 1
	gui.MaxDistance = 40
	gui.Parent = part
	for _, spec in { { 0.38, 0.22, 0.32 }, { 0.56, 0.1, 0.3 } } do
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5, spec[1])
		f.Size = UDim2.fromScale(spec[2] * 2, spec[3])
		f.BackgroundColor3 = Color3.fromRGB(14, 12, 10)
		f.BorderSizePixel = 0
		f.Parent = gui
		if spec[1] < 0.5 then
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.5, 0)
			corner.Parent = f
		end
	end
end

-- Деталь на своде под углом phi (градусы от вертикали, минус — к переду), на радиусе rad
local function onArch(x: number, phi: number, rad: number): CFrame
	local a = math.rad(phi)
	return C(x, CY + rad * math.cos(a), rad * math.sin(a)) * A(phi, 0, 0)
end

T.Chest = {
	Variants = 3,
	Build = function(rng: Random, variant: number)
		local s = STYLES[variant] or STYLES[1]
		local m = Kit.model("Chest")
		m:SetAttribute("Kind", "Chest")
		local wood = Kit.jitter(s.Wood, 0.04, rng)
		local iron = Kit.jitter(s.Iron, 0.04, rng)

		-- Корпус
		local box = Kit.box(m, C(0, (BASE_H + TOP) / 2, 0), V(W, TOP - BASE_H, D), wood, Mat.WoodPlanks)
		box.Name = "Box"
		Kit.setOrigin(m, box)
		Kit.box(m, C(0, BASE_H / 2, 0), V(W + 0.08, BASE_H, D + 0.08), Kit.dark(wood, 0.35), Mat.Wood)
		-- оковка: две вертикальные полосы, обод под крышкой, уголки
		local band = Kit.jitter(s.Band, 0.04, rng)
		for _, x in { -BAND_X, BAND_X } do
			Kit.box(m, C(x, (BASE_H + TOP) / 2, 0), V(0.2, TOP - BASE_H + 0.02, D + 0.04), band, s.BandMat, DECOR)
		end
		Kit.box(m, C(0, TOP - 0.08, 0), V(W + 0.04, 0.14, D + 0.04), Kit.dark(iron, 0.1), s.IronMat, DECOR)
		for i, c in { V(-1, 0, -1), V(1, 0, -1), V(-1, 0, 1), V(1, 0, 1) } do
			if not (s.MissingCorner and i == 2) then
				Kit.box(m, C(c.X * (W / 2 - 0.06), (BASE_H + TOP) / 2, c.Z * (D / 2 - 0.06)), V(0.2, TOP - BASE_H + 0.03, 0.2), Kit.dark(iron, 0.05), s.IronMat, DECOR)
			end
		end
		-- замок с замочной скважиной
		local lock = Kit.box(m, C(0, TOP - 0.3, -D / 2 - 0.03), V(0.36, 0.44, 0.05), Kit.jitter(s.Lock, 0.05, rng), Mat.Metal, DECOR)
		keyhole(lock)
		-- ручки по бокам: железные скобы или верёвочные петли
		for _, sx in { -1, 1 } do
			local cf = C(sx * (W / 2 + 0.07), TOP - 0.55, 0)
			if s.RopeHandles then
				Kit.box(m, cf * C(0, -0.08, 0) * A(0, 0, sx * 12), V(0.06, 0.1, 0.62), Color3.fromRGB(128, 110, 80), Mat.Fabric, DECOR)
			else
				Kit.box(m, cf, V(0.07, 0.08, 0.6), Kit.dark(iron, 0.1), Mat.Metal, DECOR)
			end
		end
		-- грязь снизу по стенкам
		Kit.grime(box, Enum.NormalId.Front, 0.55)
		Kit.grime(box, Enum.NormalId.Back, 0.55)
		-- тёмное нутро (видно, когда крышка открыта), в нём свет Glow
		local cavity = Kit.box(m, C(0, TOP + 0.006, 0), V(W - 0.3, 0.012, D - 0.3), Color3.fromRGB(24, 18, 14), Mat.SmoothPlastic, DECOR)
		local glow = Kit.pointLight(cavity, Color3.fromRGB(255, 214, 140), 7, 1.4)
		glow.Name = "Glow"
		glow.Enabled = false

		-- Крышка (группа ChestLid): сердцевина из двух клиньев, доски по своду, полосы поверх досок, накладка замка
		local lid: { BasePart } = {}
		local apex = CY + (R - PLANK_T) * math.cos(math.rad(SPAN / PLANKS)) - 0.05
		for _, side in { -1, 1 } do
			local core = C(0, (TOP + apex) / 2, side * D / 4) * A(0, side < 0 and 0 or 180, 0)
			-- сердцевина отбрасывает тень за всю крышку (без столкновений)
			table.insert(lid, Kit.wedge(m, core, V(W + 0.02, apex - TOP, D / 2), Kit.dark(wood, 0.3), Mat.Wood, { CanCollide = false, CanQuery = false, CanTouch = false }))
		end
		local step = 2 * SPAN / PLANKS
		local width = 2 * R * math.sin(math.rad(step / 2)) + 0.03
		for i = 0, PLANKS - 1 do
			local phi = -SPAN + step * (i + 0.5)
			table.insert(lid, Kit.box(m, onArch(rng:NextNumber(-0.02, 0.02), phi, R - PLANK_T / 2), V(W + 0.02, PLANK_T, width), Kit.jitter(wood, 0.07, rng), Mat.Wood, DECOR))
			for _, x in { -BAND_X, BAND_X } do
				table.insert(lid, Kit.box(m, onArch(x, phi, R + 0.02), V(0.2, 0.05, width + 0.01), band, s.BandMat, DECOR))
			end
		end
		-- накладка (пробой) свисает с крышки на замок
		table.insert(lid, Kit.box(m, C(0, TOP - 0.05, -D / 2 - 0.06), V(0.16, 0.32, 0.04), Kit.dark(iron, 0.15), Mat.Metal, DECOR))

		local hinge = C(0, TOP, D / 2)
		local closed = CFrame.identity
		local shut = Kit.aroundHinge(closed, hinge, A(s.Ajar, 0, 0))
		local open = Kit.aroundHinge(closed, hinge, A(100, 0, 0))
		for _, p in lid do
			Kit.movable(m, p, "ChestLid", shut * p.CFrame, open * p.CFrame)
		end

		m:SetAttribute("Opened", false)
		return m
	end,
}

return M
