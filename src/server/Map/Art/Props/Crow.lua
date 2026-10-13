-- Ворона
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
-- Ворона
------------------------------------------------------------------------

T.Crow = {
	Variants = 1,
	Build = function(_rng: Random)
		local m = base("Crow", "Crow")
		local black = Color3.fromRGB(15, 15, 18)
		local body = Kit.box(m, C(0, 0.35, 0), V(0.45, 0.45, 0.9), black, Mat.SmoothPlastic, { Decor = true })
		body.Name = "Body"
		Kit.setOrigin(m, body)
		Kit.ball(m, C(0, 0.65, -0.45), 0.38, black, Mat.SmoothPlastic, { Decor = true })
		Kit.box(m, C(0, 0.62, -0.72), V(0.1, 0.1, 0.3), Color3.fromRGB(60, 55, 40), Mat.SmoothPlastic, { Decor = true })
		for _, x in { -0.3, 0.3 } do
			Kit.box(m, C(x, 0.38, 0.05), V(0.12, 0.35, 0.75), black, Mat.SmoothPlastic, { Decor = true })
		end
		Kit.box(m, C(0, 0.4, 0.6) * A(15, 0, 0), V(0.3, 0.08, 0.45), black, Mat.SmoothPlastic, { Decor = true })
		return m
	end,
}

return M
