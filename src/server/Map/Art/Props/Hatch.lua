-- Люк: бетонная (или каменная) плита вровень с землёй со скошенными краями, тёмный провал в стальной
-- окантовке и две решётчатые створки, открывающиеся вверх; вокруг — немного грязи и обломков.
-- Модель строится в начале координат: земля y = 0, «перед» модели смотрит в -Z.
-- Ничто не сталкивается: по люку ходят, в него прыгают (JumpHatch — по расстоянию до опоры).
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

local DECOR = { Decor = true }
local FLAT = { CanCollide = false, CanQuery = false, CanTouch = false } -- плита: без столкновений, но с тенью

local SLAB = 4.4 -- сторона плиты
local HOLE = 3.0 -- сторона провала
local TOP = 0.16 -- верх плиты над землёй

type Look = {
	Slab: Color3,
	SlabMat: Enum.Material,
	Door: Color3,
	DoorMat: Enum.Material,
	Moss: boolean,
}

local LOOKS: { Look } = {
	{ Slab = Color3.fromRGB(86, 84, 80), SlabMat = Mat.Concrete, Door = Color3.fromRGB(96, 58, 40), DoorMat = Mat.CorrodedMetal, Moss = false },
	{ Slab = Color3.fromRGB(84, 78, 70), SlabMat = Mat.Cobblestone, Door = Color3.fromRGB(52, 54, 56), DoorMat = Mat.Metal, Moss = true },
}

-- Плита со скошенными краями, провал, стальная окантовка
local function frame(m: Model, rng: Random, look: Look): BasePart
	local color = Kit.jitter(look.Slab, 0.04, rng)
	local slab = Kit.box(m, C(0, TOP / 2, 0), V(SLAB, TOP, SLAB), color, look.SlabMat, FLAT)
	slab.Name = "Frame"
	-- Скосы по периметру (клин смотрит наружу, высокая сторона у плиты)
	for i, yaw in { 0, -90, 180, 90 } do
		local cf = A(0, yaw, 0) * C(0, TOP / 2, -SLAB / 2 - 0.25)
		Kit.wedge(m, cf, V(SLAB + 0.5, TOP, 0.5), Kit.jitter(Kit.dark(color, 0.1), 0.04, rng), i % 2 == 0 and look.SlabMat or Mat.Ground, DECOR)
	end
	local void = Kit.box(m, C(0, TOP + 0.01, 0), V(HOLE, 0.02, HOLE), Color3.fromRGB(6, 6, 8), Mat.SmoothPlastic, DECOR)
	void.Name = "Pit"
	local glow = Kit.pointLight(void, Color3.fromRGB(180, 200, 255), 14, 2)
	glow.Name = "Glow"
	glow.Enabled = false
	local rim = Kit.jitter(P.DarkSteel, 0.04, rng)
	for _, yaw in { 0, 90 } do
		for _, s in { -1, 1 } do
			Kit.box(m, A(0, yaw, 0) * C(0, TOP + 0.05, s * (HOLE / 2 + 0.1)), V(HOLE + 0.4, 0.1, 0.2), rim, Mat.Metal, DECOR)
		end
	end
	return slab
end

-- Две решётчатые створки (группа HatchDoor) на петлях у внешних краёв провала
local function doors(m: Model, rng: Random, look: Look)
	local y = TOP + 0.16
	local half = HOLE / 2
	for _, sx in { -1, 1 } do
		local color = Kit.jitter(look.Door, 0.05, rng)
		local hinge = C(sx * half, y, 0)
		local opened = A(0, 0, -100 * sx)
		local function swing(part: BasePart)
			Kit.movable(m, part, "HatchDoor", part.CFrame, Kit.aroundHinge(part.CFrame, hinge, opened))
		end
		-- продольные полосы по краям створки
		for _, x in { 0.09, half - 0.09 } do
			swing(Kit.box(m, C(sx * x, y, 0), V(0.18, 0.14, HOLE), color, look.DoorMat, DECOR))
		end
		-- поперечные планки решётки
		for i = 0, 4 do
			local z = -half + 0.12 + i * (HOLE - 0.24) / 4
			swing(Kit.box(m, C(sx * half / 2, y, z), V(half - 0.1, 0.09, 0.16), Kit.dark(color, 0.1), look.DoorMat, DECOR))
		end
		if sx > 0 then
			-- скоба-ручка на правой створке
			swing(Kit.box(m, C(0.32, y + 0.12, 0), V(0.12, 0.12, 0.7), P.Iron, Mat.Metal, DECOR))
		end
	end
end

-- Холмик грязи у угла, два камня; на бетонном варианте — обломок доски, на каменном — пучок травы
local function debris(m: Model, rng: Random, look: Look)
	local dirt = Kit.jitter(Color3.fromRGB(70, 56, 42), 0.05, rng)
	local mound = C(1.9, 0.17, 2.6) * A(0, 200, 0)
	Kit.wedge(m, mound * C(0, 0, -0.3), V(1.5, 0.34, 0.6), dirt, Mat.Mud, DECOR)
	Kit.wedge(m, mound * C(0, 0, 0.3) * A(0, 180, 0), V(1.5, 0.34, 0.6), Kit.dark(dirt, 0.1), Mat.Mud, DECOR)
	local a = rng:NextNumber(0, math.pi * 2)
	for i = 0, 1 do
		local b = a + i * 2.4
		local s = rng:NextNumber(0.3, 0.55)
		Kit.box(m, C(math.cos(b) * 2.9, s * 0.3, math.sin(b) * 2.9) * A(rng:NextNumber(-20, 20), rng:NextNumber(0, 180), 0), V(s, s * 0.7, s * 0.9), Kit.jitter(P.DarkConcrete, 0.06, rng), Mat.Rock, DECOR)
	end
	if look.Moss then
		Kit.wedge(m, C(math.cos(a + 1.2) * 2.4, 0.15, math.sin(a + 1.2) * 2.4) * A(0, math.deg(a), 0), V(0.8, 0.3, 0.45), Kit.jitter(P.Grass, 0.06, rng), Mat.Grass, DECOR)
	else
		Kit.box(m, C(-2.6, 0.08, -1.2) * A(0, 28, 4), V(0.35, 0.12, 2.2), Kit.jitter(P.OldWood, 0.06, rng), Mat.WoodPlanks, DECOR)
	end
end

T.Hatch = {
	Variants = #LOOKS,
	Build = function(rng: Random, variant: number)
		local look = LOOKS[(variant - 1) % #LOOKS + 1]
		local m = Kit.model("Hatch")
		m:SetAttribute("Kind", "Hatch")
		local slab = frame(m, rng, look)
		Kit.setOrigin(m, slab)
		doors(m, rng, look)
		debris(m, rng, look)
		m:SetAttribute("Open", false)
		m:SetAttribute("Closed", false)
		return m
	end,
}

return M
