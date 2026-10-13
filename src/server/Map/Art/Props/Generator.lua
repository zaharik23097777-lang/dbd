-- Генератор
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
-- Генератор
------------------------------------------------------------------------

T.Generator = {
	Variants = 3,
	Build = function(rng: Random)
		local m = base("Generator", "Generator")
		local body = Kit.box(m, C(0, 2, 0), V(4, 3, 3), Kit.jitter(P.Paint, 0.05, rng), Mat.DiamondPlate)
		body.Name = "Body"
		Kit.setOrigin(m, body)
		Kit.box(m, C(0, 0.25, 0), V(4.6, 0.5, 3.4), P.Rust, Mat.CorrodedMetal)
		Kit.box(m, C(-0.5, 4.15, 0), V(2.6, 1.3, 2.2), P.DarkSteel, Mat.Metal)
		for i = 1, 2 do
			local piston = Kit.vcyl(m, C(-1.1 + (i - 1) * 1.1, 5.2, 0), 1.3, 0.55, P.Steel, Mat.Metal, { Decor = true })
			piston:SetAttribute("AnimatedPiston", true)
		end
		Kit.vcyl(m, C(1.4, 4.4, 1), 2.2, 0.35, P.Black, Mat.Metal, { Decor = true })
		Kit.box(m, C(0, 3.65, -1.55), V(2.4, 0.25, 0.4), P.Black, Mat.Metal, { Decor = true })
		for i = 1, 4 do
			local l = Kit.box(m, C(-0.9 + (i - 1) * 0.6, 3.65, -1.8), V(0.35, 0.35, 0.2), Color3.fromRGB(45, 40, 30), Mat.Glass, { Decor = true })
			l:SetAttribute("ProgressLight", i)
		end
		local bulb = Kit.ball(m, C(1.2, 5.3, -0.6), 1.1, Color3.fromRGB(60, 60, 50), Mat.Glass, { Decor = true })
		bulb:SetAttribute("Bulb", true)
		local light = Kit.pointLight(bulb, Color3.fromRGB(255, 230, 150), 28, 3, true)
		light.Enabled = false
		local fx = Instance.new("Attachment")
		fx.Name = "FX"
		fx.Position = V(0, 1.8, 0)
		fx.Parent = body
		m:SetAttribute("Progress", 0)
		m:SetAttribute("Done", false)
		m:SetAttribute("Regressing", false)
		return m
	end,
}

return M
