-- Сундук
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
-- Сундук
------------------------------------------------------------------------

T.Chest = {
	Variants = 2,
	Build = function(rng: Random)
		local m = base("Chest", "Chest")
		local box = Kit.box(m, C(0, 0.8, 0), V(3, 1.6, 2), Kit.jitter(P.Wood, 0.06, rng), Mat.WoodPlanks)
		box.Name = "Box"
		Kit.setOrigin(m, box)
		local closed = C(0, 1.85, 0)
		local hinge = C(0, 2.1, 1.05)
		local lid = Kit.box(m, closed, V(3.1, 0.5, 2.1), P.DarkWood, Mat.WoodPlanks)
		lid.Name = "Lid"
		Kit.movable(m, lid, "ChestLid", closed, Kit.aroundHinge(closed, hinge, A(70, 0, 0)))
		for _, x in { -1, 1 } do
			Kit.box(m, C(x, 1.1, 0), V(0.25, 2.2, 2.15), P.Steel, Mat.Metal, { Decor = true })
		end
		Kit.box(m, C(0, 1.5, -1.08), V(0.4, 0.5, 0.15), Color3.fromRGB(180, 150, 60), Mat.Metal, { Decor = true })
		local glow = Kit.pointLight(box, Color3.fromRGB(255, 220, 140), 6, 1)
		glow.Name = "Glow"
		glow.Enabled = false
		m:SetAttribute("Opened", false)
		return m
	end,
}

return M
