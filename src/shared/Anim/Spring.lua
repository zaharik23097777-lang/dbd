-- Пружины для процедурной анимации: суставы догоняют позу «живо» — с инерцией,
-- лёгким перелётом и успокоением, а не экспоненциальным подтягиванием.
--
-- Модель — затухающий осциллятор второго порядка с подачей скорости цели:
--   x'' = ω²·(цель − x) + 2ζω·(r·цель' − x')
--   Freq (Гц)   — собственная частота ω/2π: чем больше, тем быстрее сустав догоняет позу;
--   Damping (ζ) — 1 = без перелёта (критическое), 0.5..0.8 = лёгкий перелёт и «оттяжка»;
--                 значения больше 1 обрезаются до 1;
--   Response(r) — 0..1, какая доля скорости цели передаётся сразу. 1 — плавно движущаяся цель
--                 (цикл шага) отслеживается почти без отставания, пружина сглаживает только рывки
--                 и смену поз; меньше 1 — сустав «тянется» за целью (захлёст рук).
-- Шаг решается аналитически (точное решение при линейно движущейся за кадр цели),
-- поэтому устойчив при любом dt: и 1/240, и 1/10 (дальние персонажи обновляются редко).
-- Если цель за кадр прыгнула (смена позы, а не плавное движение), скорость цели не подаётся —
-- сустав переходит в новую позу с естественным перелётом.
--
-- Повороты хранятся как CFrame (чистый поворот), ошибка и скорости — как вектор поворота
-- (ось × угол, рад) в пространстве родителя сустава.
--
-- Использование:
--   local s = Spring.rot(Spring.R6.Neck)       -- или Spring.vec(...) для смещения
--   local cf = Spring.stepRot(s, targetCFrame, dt) -- каждый кадр; первый вызов ставит сразу в цель
--   Spring.stepRot(s, target, dt, 1.8)         -- 4-й аргумент: множитель частоты (резкие удары)
local Rig = require(script.Parent.Rig)

local Spring = {}

export type Tuning = {
	Freq: number,
	Damping: number,
	Response: number?,
}

export type Rot = {
	Tuning: Tuning,
	Value: CFrame,
	Velocity: Vector3,
	Target: CFrame?,
}

export type Vec = {
	Tuning: Tuning,
	Value: Vector3,
	Velocity: Vector3,
	Target: Vector3?,
}

local ZERO = Vector3.zero
local TAU = math.pi * 2
local exp, cos, sin, sqrt = math.exp, math.cos, math.sin, math.sqrt

-- Цель «прыгнула», а не движется: больше этого угла за один шаг или этой угловой скорости
local JUMP_ANGLE = 0.6 -- рад
local JUMP_SPEED = 30 -- рад/с
-- То же для смещения корпуса (стады за шаг и стад/с)
local JUMP_DIST = 0.6
local JUMP_VEL = 25

-- Коэффициенты точного решения x(dt), v(dt) = (xx·x0 + xv·v0, vx·x0 + vv·v0)
local function coefficients(omega: number, zeta: number, dt: number): (number, number, number, number)
	if zeta >= 0.9999 then
		local e = exp(-omega * dt)
		local wt = omega * dt
		return e * (1 + wt), e * dt, -e * omega * omega * dt, e * (1 - wt)
	end
	local a = zeta * omega
	local wd = omega * sqrt(1 - zeta * zeta)
	local e = exp(-a * dt)
	local c, s = cos(wd * dt), sin(wd * dt)
	return e * (c + a * s / wd), e * s / wd, -e * omega * omega * s / wd, e * (c - a * s / wd)
end
Spring.coefficients = coefficients

local rotVec = Rig.rotVec

local function fromRotVec(v: Vector3): CFrame
	local m = v.Magnitude
	if m < 1e-7 then
		return CFrame.identity
	end
	return CFrame.fromAxisAngle(v / m, m)
end

local function params(t: Tuning, freqScale: number?): (number, number, number)
	local omega = TAU * t.Freq * (freqScale or 1)
	return omega, math.clamp(t.Damping, 0.05, 1), t.Response or 1
end

-- Один шаг для ошибки e (относительно цели) и её скорости ev при скорости цели tv
local function solve(e: Vector3, ev: Vector3, tv: Vector3, omega: number, zeta: number, r: number, dt: number): (Vector3, Vector3)
	-- При r < 1 пружина отстаёт от движущейся цели на постоянную величину eq
	local eq = tv * (-2 * zeta * (1 - r) / omega)
	local y = e - eq
	local xx, xv, vx, vv = coefficients(omega, zeta, dt)
	return y * xx + ev * xv + eq, y * vx + ev * vv
end

function Spring.rot(tuning: Tuning, value: CFrame?): Rot
	return { Tuning = tuning, Value = value or CFrame.identity, Velocity = ZERO, Target = nil }
end

function Spring.vec(tuning: Tuning, value: Vector3?): Vec
	return { Tuning = tuning, Value = value or ZERO, Velocity = ZERO, Target = nil }
end

-- Сразу поставить в позу (телепорт, первый кадр, долгий пропуск обновлений)
function Spring.snapRot(s: Rot, target: CFrame)
	s.Value, s.Velocity, s.Target = target, ZERO, target
end

function Spring.snapVec(s: Vec, target: Vector3)
	s.Value, s.Velocity, s.Target = target, ZERO, target
end

function Spring.stepRot(s: Rot, target: CFrame, dt: number, freqScale: number?): CFrame
	local prev = s.Target
	if not prev then
		Spring.snapRot(s, target)
		return target
	end
	s.Target = target
	if dt <= 0 then
		return s.Value
	end
	local omega, zeta, r = params(s.Tuning, freqScale)
	-- Скорость цели за этот шаг (цель двигалась от prev к target)
	local move = rotVec(target * prev:Inverse())
	local tv = move / dt
	local base = prev
	if move.Magnitude > JUMP_ANGLE or tv.Magnitude > JUMP_SPEED then
		tv = ZERO
		base = target
	end
	local e = rotVec(s.Value * base:Inverse())
	local e1, ev1 = solve(e, s.Velocity - tv, tv, omega, zeta, r, dt)
	local value = fromRotVec(e1) * target
	s.Value = value
	s.Velocity = ev1 + tv
	return value
end

function Spring.stepVec(s: Vec, target: Vector3, dt: number, freqScale: number?): Vector3
	local prev = s.Target
	if not prev then
		Spring.snapVec(s, target)
		return target
	end
	s.Target = target
	if dt <= 0 then
		return s.Value
	end
	local omega, zeta, r = params(s.Tuning, freqScale)
	local move = target - prev
	local tv = move / dt
	local base = prev
	if move.Magnitude > JUMP_DIST or tv.Magnitude > JUMP_VEL then
		tv = ZERO
		base = target
	end
	local e1, ev1 = solve(s.Value - base, s.Velocity - tv, tv, omega, zeta, r, dt)
	local value = target + e1
	s.Value = value
	s.Velocity = ev1 + tv
	return value
end

------------------------------------------------------------------------
-- Настройки суставов R6: голова лёгкая и быстрая, корпус тяжёлый,
-- руки с заметной «оттяжкой», ноги точные (чтобы стопы попадали в землю).
------------------------------------------------------------------------

Spring.R6 = {
	Root = { Freq = 2.6, Damping = 0.78, Response = 1 },
	RootPos = { Freq = 3.2, Damping = 0.72, Response = 1 },
	Neck = { Freq = 4.4, Damping = 0.62, Response = 1 },
	LArm = { Freq = 3.3, Damping = 0.52, Response = 0.85 },
	RArm = { Freq = 3.3, Damping = 0.52, Response = 0.85 },
	LLeg = { Freq = 4.8, Damping = 0.82, Response = 1 },
	RLeg = { Freq = 4.8, Damping = 0.82, Response = 1 },
} :: { [string]: Tuning }

return Spring
