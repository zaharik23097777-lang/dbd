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

local function base(name: string, kind: string): Model
	local m = Kit.model(name)
	m:SetAttribute("Kind", kind)
	return m
end

------------------------------------------------------------------------
-- Шкафчик (опора — пол в центре, дверь спереди -Z)
------------------------------------------------------------------------

T.Locker = {
	Variants = 2,
	Build = function(rng: Random)
		local m = base("Locker", "Locker")
		local metal = Kit.jitter(Color3.fromRGB(70, 85, 80), 0.05, rng)
		local back = Kit.box(m, C(0, 3.6, 1.2), V(3, 7.2, 0.2), metal, Mat.CorrodedMetal)
		back.Name = "Back"
		Kit.setOrigin(m, back)
		for _, x in { -1.5, 1.5 } do
			Kit.box(m, C(x, 3.6, 0), V(0.2, 7.2, 2.6), metal, Mat.CorrodedMetal)
		end
		Kit.box(m, C(0, 7.3, 0), V(3.2, 0.2, 2.6), metal, Mat.CorrodedMetal)
		Kit.box(m, C(0, 0.1, 0), V(3, 0.2, 2.6), metal, Mat.CorrodedMetal)
		local closed = C(0, 3.6, -1.3)
		local hinge = C(-1.4, 3.6, -1.3)
		local open = Kit.aroundHinge(closed, hinge, A(0, -100, 0))
		local door = Kit.box(m, closed, V(2.8, 7, 0.15), metal:Lerp(Color3.new(1, 1, 1), 0.08), Mat.CorrodedMetal)
		door.Name = "Door"
		Kit.movable(m, door, "LockerDoor", closed, open)
		for i = 1, 4 do
			local off = C(0, 2.6 - i * 0.3, -0.1)
			local slit = Kit.box(m, closed * off, V(1.6, 0.12, 0.05), P.Black, Mat.SmoothPlastic, { Decor = true })
			Kit.movable(m, slit, "LockerDoor", closed * off, open * off)
		end
		local inside = Kit.box(m, C(0, 3, 0.2), V(1, 1, 1), P.Black, Mat.SmoothPlastic, { Decor = true, Transparency = 1 })
		inside.Name = "Inside"
		m:SetAttribute("Occupant", 0)
		return m
	end,
}

return M
