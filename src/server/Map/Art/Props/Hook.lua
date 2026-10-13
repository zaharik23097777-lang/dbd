-- Крюк и лапы Сущности
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

local function base(name: string, kind: string): Model
	local m = Kit.model(name)
	m:SetAttribute("Kind", kind)
	return m
end

------------------------------------------------------------------------
-- Крюк
------------------------------------------------------------------------

T.Hook = {
	Variants = 2,
	Build = function(rng: Random)
		local m = base("Hook", "Hook")
		local red = Kit.jitter(Color3.fromRGB(95, 25, 20), 0.05, rng)
		local pole = Kit.box(m, C(0, 6, 0), V(0.9, 12, 0.9), red, Mat.CorrodedMetal)
		pole.Name = "Pole"
		Kit.setOrigin(m, pole)
		Kit.box(m, C(0, 0.4, 0) * A(0, 20, 0), V(2.6, 0.8, 2.6), Color3.fromRGB(70, 65, 60), Mat.Slate)
		Kit.box(m, C(0, 11.4, -2), V(0.7, 0.7, 4.4), red, Mat.CorrodedMetal)
		Kit.box(m, C(0, 10.3, -1) * A(-45, 0, 0), V(0.4, 0.4, 3), red, Mat.CorrodedMetal, { Decor = true })
		Kit.chain(m, { V(0, 11, -3.9), V(0, 9.4, -3.9) }, 0.4, Color3.fromRGB(80, 80, 80))
		Kit.arc(m, C(0, 8.6, -3.5) * A(0, 90, 0), 0.45, 180, 360, 5, 0.22, P.Steel, Mat.Metal, { Decor = true })
		Kit.vcyl(m, C(0, 0.03, -3.9), 0.05, 2.6, P.Blood, Mat.SmoothPlastic, { Decor = true })
		local hp = Kit.box(m, C(0.25, 7, -4.3), V(1, 1, 1), P.Black, Mat.SmoothPlastic, { Decor = true, Transparency = 1 })
		hp.Name = "HangPoint"
		m:SetAttribute("Occupant", 0)
		return m
	end,
}

-- Лапы Сущности вокруг висящего (hangPoint — мировой CFrame точки HangPoint)
function M.entityLegs(hangPoint: CFrame): Model
	local m = Kit.model("EntityLegs")
	for i = 1, 6 do
		local angle = (i / 6) * math.pi * 2
		local basePos = hangPoint.Position + V(math.cos(angle) * 3.5, 5, math.sin(angle) * 3.5)
		local look = CFrame.lookAt(basePos, hangPoint.Position + V(0, 1, 0))
		Kit.box(m, look * C(0, 0, -3.5), V(0.35, 0.35, 7), Color3.fromRGB(25, 10, 10), Mat.Slate, { Decor = true })
		Kit.box(m, look * C(0, 0, -7.4), V(0.2, 0.2, 1.4), Color3.fromRGB(200, 40, 20), Mat.Neon, { Decor = true })
	end
	return m
end

return M
