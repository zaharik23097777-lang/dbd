-- Ворота выхода
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
-- Ворота выхода (опора — центр проёма на линии стены; -Z внутрь карты, +Z наружу)
------------------------------------------------------------------------

T.ExitGate = {
	Variants = 1,
	Build = function(_rng: Random)
		local m = base("ExitGate", "ExitGate")
		local frameTop = Kit.box(m, C(0, 14.75, 0), V(16, 2.5, 2.5), Color3.fromRGB(40, 40, 40), Mat.Metal)
		frameTop.Name = "Frame"
		Kit.setOrigin(m, frameTop)
		local metal = Color3.fromRGB(60, 60, 65)
		local closed = C(0, 6, 0)
		local open = C(0, 17.8, 0)
		local door = Kit.box(m, closed, V(12, 12, 1), metal, Mat.DiamondPlate)
		door.Name = "Door"
		Kit.movable(m, door, "GateDoor", closed, open)
		for i = -2, 2 do
			local off = C(i * 2.4, 0, 0)
			local rib = Kit.box(m, closed * off, V(0.4, 12, 1.3), Kit.dark(metal, 0.3), Mat.Metal, { Decor = true })
			Kit.movable(m, rib, "GateDoor", closed * off, open * off)
		end
		for _, x in { -7, 7 } do
			Kit.box(m, C(x, 8, 0), V(2, 16, 2.5), Color3.fromRGB(50, 48, 46), Mat.Concrete)
		end
		local switch = Kit.box(m, C(10, 2, -2.2), V(2.2, 4, 1.4), Color3.fromRGB(50, 50, 50), Mat.Metal)
		switch.Name = "Switch"
		local pivot = switch.CFrame * C(0, 0.6, -0.8)
		Kit.box(m, pivot, V(0.5, 0.5, 0.5), P.Black, Mat.Metal, { Decor = true })
		local lever = Kit.box(m, pivot, V(0.25, 1.6, 0.25), Color3.fromRGB(150, 30, 30), Mat.Metal, { Decor = true })
		lever.Name = "Lever"
		Kit.movable(m, lever, "GateLever", pivot * A(-35, 0, 0) * C(0, 0.7, 0), pivot * A(35, 0, 0) * C(0, 0.7, 0))
		for i = 1, 3 do
			local lamp = Kit.box(m, switch.CFrame * C(-0.6 + (i - 1) * 0.6, 1.5, -0.75), V(0.5, 0.5, 0.3), Color3.fromRGB(40, 0, 0), Mat.Neon, { Decor = true })
			lamp:SetAttribute("GateLamp", i)
		end
		local siren = Kit.ball(m, C(-7, 16.5, -1), 1, Color3.fromRGB(80, 10, 10), Mat.Glass, { Decor = true })
		siren.Name = "Siren"
		local sirenLight = Kit.spotLight(siren, Color3.fromRGB(255, 30, 20), 30, 60, 4, Enum.NormalId.Front)
		sirenLight.Name = "SirenLight"
		sirenLight.Enabled = false
		-- Коридор за воротами и зона побега
		Kit.box(m, C(0, -0.5, 15.75), V(12, 1, 30), Color3.fromRGB(50, 45, 40), Mat.Ground)
		for _, x in { -6.75, 6.75 } do
			Kit.box(m, C(x, 6, 15.75), V(1.5, 12, 30), P.Concrete, Mat.Concrete)
		end
		local escape = Kit.box(m, C(0, 6, 24), V(12, 12, 10), Color3.new(1, 1, 1), Mat.ForceField, { Decor = true, Transparency = 0.6 })
		escape.Name = "EscapeZone"
		Kit.pointLight(escape, Color3.new(1, 1, 1), 40, 2)
		m:SetAttribute("Powered", false)
		m:SetAttribute("Progress", 0)
		m:SetAttribute("Open", false)
		return m
	end,
}

return M
