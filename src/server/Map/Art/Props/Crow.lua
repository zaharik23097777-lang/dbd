-- Ворона
-- Модель строится в начале координат: земля y = 0, «перед» модели смотрит в -Z.
-- Требования — Art/Contract.lua; подвижные части — Kit.movable (см. Map/PropFX.lua).
local Kit = require(script.Parent.Parent.Kit)

local Mat = Kit.Mat
local A = Kit.A
local V = Vector3.new
local C = CFrame.new

local M = {}
local T = {}
M.Templates = T

------------------------------------------------------------------------
-- Сидящая ворона (опора — лапы на насесте, клюв в -Z). Тело наклонено: грудь вверх-вперёд,
-- хвост вниз-назад; сложенные крылья перекрещиваются над хвостом. Всё — декор без столкновений.
------------------------------------------------------------------------

local DECOR = { Decor = true }
local FEATHER = Color3.fromRGB(22, 22, 26)
local GLOSS = Color3.fromRGB(28, 30, 40) -- синеватый отлив крыльев и хвоста
local BEAK = Color3.fromRGB(36, 34, 34)

T.Crow = {
	Variants = 1,
	Build = function(rng: Random)
		local m = Kit.model("Crow")
		m:SetAttribute("Kind", "Crow")
		local body = Kit.jitter(FEATHER, 0.03, rng)
		local gloss = Kit.jitter(GLOSS, 0.03, rng)

		-- Туловище: цилиндр по оси тела (опора модели), круглая грудь и толстая шея
		local trunk = Kit.rod(m, V(0, 0.46, -0.1), V(0, 0.36, 0.32), 0.42, body, Mat.Fabric, DECOR) :: BasePart
		trunk.Name = "Body"
		Kit.setOrigin(m, trunk)
		Kit.ball(m, C(0, 0.45, -0.12), 0.48, body, Mat.Fabric, DECOR)
		Kit.ball(m, C(0, 0.64, -0.24), 0.3, body, Mat.Fabric, DECOR)

		-- Голова, клюв (надклювье и подклювье), глаза
		local head = V(0, 0.78, -0.27)
		Kit.ball(m, C(head), 0.32, body, Mat.SmoothPlastic, DECOR)
		Kit.wedge(m, C(0, 0.775, -0.49) * A(-6, 0, 0), V(0.09, 0.08, 0.26), BEAK, Mat.SmoothPlastic, DECOR)
		Kit.wedge(m, C(0, 0.72, -0.46) * A(4, 0, 180), V(0.08, 0.04, 0.2), Kit.dark(BEAK, 0.2), Mat.SmoothPlastic, DECOR)
		for _, x in { -0.115, 0.115 } do
			Kit.ball(m, C(head + V(x, 0.03, -0.08)), 0.065, Color3.fromRGB(10, 8, 6), Mat.Glass, DECOR)
		end

		-- Сложенные крылья: перевёрнутый клин — прямой верх вдоль спины, низ сходится к кончику над хвостом
		for _, sx in { -1, 1 } do
			Kit.wedge(m, C(sx * 0.15, 0.5, 0.24) * A(12, sx * -4, 0) * A(180, 0, 0), V(0.09, 0.3, 0.86), gloss, Mat.SmoothPlastic, DECOR)
		end

		-- Хвост: два слоя перьев веером вниз-назад
		Kit.box(m, C(0, 0.3, 0.64) * A(24, 0, 0), V(0.24, 0.03, 0.5), gloss, Mat.SmoothPlastic, DECOR)
		Kit.box(m, C(0, 0.27, 0.68) * A(30, rng:NextNumber(-6, 6), 0), V(0.18, 0.03, 0.5), Kit.dark(gloss, 0.15), Mat.SmoothPlastic, DECOR)

		-- Короткие лапы, чуть вынесенные вперёд
		for _, x in { -0.08, 0.08 } do
			Kit.rod(m, V(x, 0, -0.07), V(x * 1.15, 0.26, -0.01), 0.045, BEAK, Mat.SmoothPlastic, DECOR)
		end

		return m
	end,
}

return M
