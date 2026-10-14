-- Медвежий капкан
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
-- Медвежий капкан Траппера: лежит на земле. Две полукруглые челюсти с зубьями шарнирно
-- закреплены по оси X; взведён (CF0) — челюсти раскрыты и лежат плашмя кольцом вокруг тарелки,
-- сработал (CF1) — обе поднялись и сомкнулись зубьями над тарелкой. По бокам — листовые пружины,
-- от левой пружины цепь к колышку в земле.
------------------------------------------------------------------------

local R = 1.0 -- радиус челюстей
local PIVOT_Y = 0.1 -- высота оси шарниров
local JAW_W, JAW_T = 0.15, 0.08 -- высота и толщина полосы челюсти
local CLOSE = 86 -- угол смыкания: кромки челюстей сходятся над центром
local SPRING = 1.05 -- длина пружины от шарнира наружу

local DECOR = { Decor = true }
local IRON = Color3.fromRGB(58, 54, 50)
local STEEL = Color3.fromRGB(112, 108, 102)

-- Точка на дуге челюсти (side = -1 — передняя, +1 — задняя), theta 0..180
local function arcPoint(side: number, theta: number): Vector3
	local a = math.rad(theta)
	return V(R * math.cos(a), PIVOT_Y, side * R * math.sin(a))
end

T.Trap = {
	Variants = 1,
	Build = function(rng: Random)
		local m = Kit.model("BearTrap")
		m:SetAttribute("Kind", "Trap")
		local iron = Kit.jitter(IRON, 0.04, rng)
		local rust = Kit.jitter(P.Rust, 0.05, rng)

		-- Тарелка-спуск в центре (опора модели) и основание под ней
		local plate = Kit.vcyl(m, C(0, 0.09, 0), 0.05, 0.72, Kit.jitter(Color3.fromRGB(74, 66, 58), 0.04, rng), Mat.CorrodedMetal, { CanCollide = false, CanQuery = false, CanTouch = false })
		plate.Name = "Plate"
		Kit.setOrigin(m, plate)
		Kit.box(m, C(0, 0.03, 0), V(2 * R + 0.2, 0.05, 0.2), Kit.dark(iron, 0.15), Mat.CorrodedMetal, DECOR)
		-- собачка: планка поверх передней челюсти держит её до нажатия на тарелку
		Kit.bar(m, V(-0.1, 0.13, -R - 0.02), V(-0.06, 0.12, -0.3), 0.08, Kit.dark(iron, 0.05), Mat.Metal, DECOR, 0.03)

		-- Челюсти (группа TrapJaw)
		local hinge = C(0, PIVOT_Y, 0)
		local teeth = { [-1] = { 35, 75, 105, 145 }, [1] = { 18, 55, 90, 125, 162 } }
		for _, side in { -1, 1 } do
			local parts: { BasePart } = {}
			local pts = { 0, 60, 120, 180 }
			for i = 1, #pts - 1 do
				local seg = Kit.bar(m, arcPoint(side, pts[i]), arcPoint(side, pts[i + 1]), JAW_T, iron, Mat.CorrodedMetal, DECOR, JAW_W)
				if seg then
					table.insert(parts, seg)
				end
			end
			for _, theta in teeth[side] do
				-- зуб-клин на верхней кромке челюсти (острый, как у пилы), основание утоплено в полосу
				local h = 0.24
				local p = arcPoint(side, theta) + V(0, JAW_W / 2 + h / 2 - 0.04, 0)
				local tangent = arcPoint(side, theta + 1) - arcPoint(side, theta - 1)
				local cf = CFrame.lookAt(p, p + tangent * side)
				local color = rng:NextNumber() < 0.25 and STEEL:Lerp(P.DryBlood, 0.45) or Kit.jitter(STEEL, 0.05, rng)
				table.insert(parts, Kit.wedge(m, cf, V(0.05, h, 0.13), color, Mat.Metal, DECOR))
			end
			local sprung = Kit.aroundHinge(CFrame.identity, hinge, A(side < 0 and CLOSE or -CLOSE, 0, 0))
			for _, p in parts do
				Kit.movable(m, p, "TrapJaw", p.CFrame, sprung * p.CFrame)
			end
		end

		-- Листовые пружины: нижний лист на земле, верхний поднимается к ушку на концах челюстей
		for _, sx in { -1, 1 } do
			local near, far = sx * (R + 0.06), sx * (R + SPRING)
			Kit.box(m, C((near + far) / 2, 0.025, 0), V(SPRING, 0.04, 0.17), Kit.dark(iron, 0.05), Mat.CorrodedMetal, DECOR)
			Kit.bar(m, V(far, 0.05, 0), V(near + sx * 0.08, 0.2, 0), 0.17, iron, Mat.CorrodedMetal, DECOR, 0.04)
			Kit.cyl(m, C(far + sx * 0.02, 0.06, 0) * A(0, 90, 0), 0.17, 0.11, Kit.dark(iron, 0.1), Mat.CorrodedMetal, DECOR)
			-- ушко, охватывающее концы обеих челюстей
			Kit.cyl(m, C(near, PIVOT_Y + 0.07, 0), 0.1, 0.3, Kit.dark(rust, 0.3), Mat.CorrodedMetal, DECOR)
		end

		-- Цепь от левой пружины к колышку
		local anchor = V(-(R + SPRING) - 0.06, 0.05, 0)
		local stake = V(-(R + SPRING) - 0.55, 0.06, 0.5)
		Kit.chain(m, Kit.sag(anchor, stake, -0.02, 2), 0.3, Kit.dark(STEEL, 0.4))
		Kit.vcyl(m, C(stake.X, 0.0, stake.Z) * A(6, 0, -8), 0.3, 0.1, Kit.dark(iron, 0.2), Mat.CorrodedMetal, DECOR)
		Kit.vcyl(m, C(stake.X - 0.01, 0.16, stake.Z), 0.05, 0.18, Kit.dark(iron, 0.1), Mat.Metal, DECOR)

		m:SetAttribute("Armed", true)
		m:SetAttribute("Caught", 0)
		return m
	end,
}

return M
