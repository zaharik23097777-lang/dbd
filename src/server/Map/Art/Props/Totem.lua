-- Тотемы (обычный и проклятый)
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
-- Тотем
------------------------------------------------------------------------

local function buildTotem(rng: Random, hex: boolean): Model
	local m = base(hex and "HexTotem" or "Totem", "Totem")
	local root = Kit.box(m, C(0, 0.3, 0) * A(0, 30, 0), V(2.4, 0.6, 2.4), Color3.fromRGB(60, 50, 40), Mat.Ground)
	root.Name = "Base"
	Kit.setOrigin(m, root)
	for _ = 1, 9 do
		Kit.cyl(
			m,
			C(rng:NextNumber(-0.8, 0.8), rng:NextNumber(0.6, 1.8), rng:NextNumber(-0.8, 0.8)) * A(rng:NextNumber(-60, 60), rng:NextNumber(0, 180), rng:NextNumber(-60, 60)),
			rng:NextNumber(0.8, 1.6),
			0.25,
			P.Bone,
			Mat.SmoothPlastic,
			{ Decor = true }
		)
	end
	Kit.box(m, C(0, 2, 0), V(0.3, 3.2, 0.3), P.DarkWood, Mat.Wood, { Decor = true })
	local skullCF = C(0, 3.5, 0)
	local fallen = C(0.6, 0.9, 0) * A(0, 0, 80)
	local skull = Kit.ball(m, skullCF, 1.1, P.Bone, Mat.SmoothPlastic, { Decor = true })
	skull.Name = "Skull"
	Kit.movable(m, skull, "Skull", skullCF, fallen)
	for _, x in { -0.22, 0.22 } do
		local off = C(x, 0.08, -0.43)
		local eye = Kit.ball(m, skullCF * off, 0.3, hex and Color3.fromRGB(255, 60, 20) or P.Black, hex and Mat.Neon or Mat.SmoothPlastic, { Decor = true })
		eye:SetAttribute("SkullEye", true)
		Kit.movable(m, eye, "Skull", skullCF * off, fallen * off)
	end
	for i = 1, 5 do
		local angle = i / 5 * math.pi * 2
		local h = rng:NextNumber(0.4, 0.9)
		local pos = V(math.cos(angle) * 1.4, 0.6 + h / 2, math.sin(angle) * 1.4)
		Kit.vcyl(m, C(pos), h, 0.25, P.Wax, Mat.SmoothPlastic, { Decor = true })
		if hex then
			local flame = Kit.box(m, C(pos + V(0, h / 2 + 0.12, 0)), V(0.12, 0.25, 0.12), P.Flame, Mat.Neon, { Decor = true })
			flame:SetAttribute("HexFlame", true)
			if i == 1 then
				Kit.pointLight(flame, Color3.fromRGB(255, 120, 50), 10, 2)
			end
		end
	end
	m:SetAttribute("Hex", hex)
	m:SetAttribute("Progress", 0)
	m:SetAttribute("Cleansed", false)
	return m
end

T.Totem = {
	Variants = 3,
	Build = function(rng: Random)
		return buildTotem(rng, false)
	end,
}
T.HexTotem = {
	Variants = 1,
	Build = function(rng: Random)
		return buildTotem(rng, true)
	end,
}

return M
