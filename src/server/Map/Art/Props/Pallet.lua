-- Паллета
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
-- Паллета (собирается в ОПУЩЕННОМ положении: хитбокс в начале координат, длинная сторона по X)
------------------------------------------------------------------------

T.Pallet = {
	Variants = 3,
	Build = function(rng: Random)
		local m = base("Pallet", "Pallet")
		local hitbox = Kit.box(m, CFrame.identity, V(5.6, 3, 1.2), P.Black, Mat.SmoothPlastic, { Transparency = 1, CanCollide = false })
		hitbox.Name = "Hitbox"
		Kit.setOrigin(m, hitbox)
		local wood = Kit.jitter(Color3.fromRGB(150, 112, 66), 0.06, rng)
		for i = 0, 3 do
			for _, z in { -0.45, 0.45 } do
				Kit.box(m, C(0, -1.15 + i * 0.77, z), V(5.6, 0.55, 0.2), Kit.jitter(wood, 0.08, rng), Mat.WoodPlanks, { Decor = true })
			end
		end
		for _, x in { -2.4, 0, 2.4 } do
			Kit.box(m, C(x, 0, 0), V(0.5, 3, 0.7), Kit.dark(wood, 0.25), Mat.Wood, { Decor = true })
		end
		m:SetAttribute("State", "Up")
		return m
	end,
}

return M
