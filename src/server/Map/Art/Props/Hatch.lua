-- Люк
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
-- Люк
------------------------------------------------------------------------

T.Hatch = {
	Variants = 1,
	Build = function(_rng: Random)
		local m = base("Hatch", "Hatch")
		local frame = Kit.box(m, C(0, 0.15, 0), V(4.4, 0.3, 4.4), P.Rust, Mat.CorrodedMetal, { CanCollide = false })
		frame.Name = "Frame"
		Kit.setOrigin(m, frame)
		Kit.box(m, C(0, 0.32, 0), V(3.6, 0.1, 3.6), P.Black, Mat.SmoothPlastic, { Decor = true })
		for _, x in { -0.9, 0.9 } do
			local closed = C(x, 0.42, 0)
			local hinge = C(x * 2, 0.42, 0)
			local sign = x > 0 and 1 or -1
			local door = Kit.box(m, closed, V(1.8, 0.15, 3.6), P.Steel, Mat.DiamondPlate, { Decor = true })
			Kit.movable(m, door, "HatchDoor", closed, Kit.aroundHinge(closed, hinge, A(0, 0, -100 * sign)))
		end
		local glow = Kit.pointLight(frame, Color3.fromRGB(180, 200, 255), 14, 2)
		glow.Name = "Glow"
		glow.Enabled = false
		m:SetAttribute("Open", false)
		m:SetAttribute("Closed", false)
		return m
	end,
}

return M
