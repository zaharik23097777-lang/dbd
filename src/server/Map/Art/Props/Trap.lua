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

local function base(name: string, kind: string): Model
	local m = Kit.model(name)
	m:SetAttribute("Kind", kind)
	return m
end

------------------------------------------------------------------------
-- Медвежий капкан (CF0 — раскрыт/взведён, CF1 — захлопнут)
------------------------------------------------------------------------

T.Trap = {
	Variants = 1,
	Build = function(_rng: Random)
		local m = base("BearTrap", "Trap")
		local plate = Kit.vcyl(m, C(0, 0.08, 0), 0.15, 1.2, Color3.fromRGB(70, 65, 60), Mat.CorrodedMetal, { CanCollide = false })
		plate.Name = "Plate"
		Kit.setOrigin(m, plate)
		for i = 1, 2 do
			local side = i == 1 and -1 or 1
			local armed = C(0, 0.12, side * 0.85)
			local sprung = C(0, 0.55, side * 0.18) * A(side * 75, 0, 0)
			local jaw = Kit.box(m, armed, V(2.2, 0.12, 0.7), Color3.fromRGB(110, 105, 100), Mat.Metal, { Decor = true })
			Kit.movable(m, jaw, "TrapJaw", armed, sprung)
			for t = -2, 2 do
				local off = C(t * 0.45, 0.2, -side * 0.3)
				local tooth = Kit.box(m, armed * off, V(0.14, 0.4, 0.14), Color3.fromRGB(150, 145, 140), Mat.Metal, { Decor = true })
				Kit.movable(m, tooth, "TrapJaw", armed * off, sprung * off)
			end
		end
		Kit.box(m, C(0, 0.06, 1.4), V(0.12, 0.12, 2), P.Black, Mat.Metal, { Decor = true })
		m:SetAttribute("Armed", true)
		m:SetAttribute("Caught", 0)
		return m
	end,
}

return M
