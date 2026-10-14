-- Походка R6: шаг, бег, спринт, присед, хромота раненого, тяжёлый шаг маньяка, перенос выжившего
-- и «живое» стояние (дыхание, перенос веса, оглядывания).
--
-- Ноги R6 — жёсткие бруски без колен (длина 2, сечение 1×1, сустав сверху). Поэтому цикл шага
-- считается геометрически:
--   * опора: стопа стоит на земле. Угол ноги подбирается так, чтобы точка опоры (пятка, затем
--     носок — перекат по низу бруска) не двигалась, пока таз идёт вперёд со скоростью шага;
--     высота таза = досягаемость опорной ноги (низ в мировой земле, без проваливания);
--   * перенос: нога возвращается вперёд по кубической кривой (Эрмита) — с захлёстом назад после
--     отрыва и подтягиванием перед касанием;
--   * полёт (бег): обе ноги в воздухе, таз летит по дуге (Lift).
-- Частота шагов (Steps, шагов/с) задаётся в профиле, а доля опоры (Duty) выводится из неё так,
-- чтобы стопа не скользила: Duty = Steps · Stride / (2 · v). Фаза (Params.Phase) копится в
-- Animator по Gait.stepRate; касания — при фазе, кратной π (там же звук шагов).
-- Все углы «мировые» (относительно HumanoidRootPart) и переводятся в пространство торса,
-- поэтому наклон и скручивание корпуса не уводят ноги из-под тела.
local Rig = require(script.Parent.Rig)
local Clip = require(script.Parent.Clip)
local Life = require(script.Parent.Life)

local Gait = {}

export type Params = {
	Speed: number, -- скорость по земле (стад/с)
	Phase: number, -- фаза шага (радианы; 2π — два шага)
	Injured: boolean?,
	Crouching: boolean?,
	Killer: boolean?,
	Carrying: boolean?,
	Wiggle: number?,
	Struggle: boolean?,
	LookYaw: number?, -- поворот головы к маньяку (градусы)
	KillerType: string?,
	-- Необязательные (их считает Animator): по умолчанию — спокойное движение вперёд
	Scale: number?, -- масштаб персонажа: скорость делится на него (длина ног)
	Forward: number?, -- направление движения относительно взгляда: вперёд (-1..1)
	Strafe: number?, -- ...и вправо (-1..1); у маньяка от первого лица бывает бег боком/назад
	AccelForward: number?, -- сглаженное ускорение вперёд (стад/с²) — наклон при разгоне/торможении
	AccelSide: number?, -- сглаженное ускорение вправо (стад/с²) — крен в повороте
	TurnRate: number?, -- скорость поворота (рад/с, + влево) — голова смотрит в поворот
	Exertion: number?, -- усталость 0..1: после бега дышит глубже и сутулится
	Breath: number?, -- фаза дыхания (рад), копится в Animator с частотой по усталости
	Seed: number?, -- 0..1, у каждого персонажа своё (оглядывания не синхронны)
}

local sin, cos, abs, asin, clamp, rad, pi = math.sin, math.cos, math.abs, math.asin, math.clamp, math.rad, math.pi
local TAU = pi * 2
local A = Rig.A
local V = Vector3.new
local YXZ = CFrame.fromEulerAnglesYXZ
local IDENTITY = CFrame.identity
local smoothstep, glance = Life.smoothstep, Life.glance

------------------------------------------------------------------------
-- Профили походок: ключи по скорости (стад/с при масштабе 1), между ними — линейно
------------------------------------------------------------------------

type Key = {
	V: number, -- скорость
	Steps: number, -- шагов в секунду
	Reach: number, -- угол ноги вперёд при касании (°)
	Push: number, -- угол ноги назад при отрыве (°)
	Lift: number, -- подъём таза в полёте (стады)
	Sink: number, -- насколько опорная нога может «согнуться» (уйти под землю) ради плавного бега
	Bounce: number, -- просадка таза в середине опоры (вес, удар стопы)
	Lean: number, -- наклон корпуса вперёд (°)
	ArmF: number, -- мах руки вперёд (°)
	ArmB: number, -- мах руки назад (°)
	ArmBase: number, -- руки вынесены вперёд (°) — согнутые на бегу
	ArmOut: number, -- отведение рук от корпуса (°)
	Twist: number, -- скручивание плеч навстречу ногам (°)
	Roll: number, -- крен корпуса на опорную ногу (°)
	Sway: number, -- боковое смещение таза на опорную ногу (стады)
	Nod: number, -- наклон головы (°; минус — исподлобья)
}

local FIELDS = { "Steps", "Reach", "Push", "Lift", "Sink", "Bounce", "Lean", "ArmF", "ArmB", "ArmBase", "ArmOut", "Twist", "Roll", "Sway", "Nod" }
local DEFAULT: { [string]: number } = {
	Steps = 0,
	Reach = 0,
	Push = 0,
	Lift = 0,
	Sink = 0,
	Bounce = 0,
	Lean = 0,
	ArmF = 0,
	ArmB = 0,
	ArmBase = 0,
	ArmOut = 4,
	Twist = 0,
	Roll = 0,
	Sway = 0,
	Nod = 0,
}

local function K(t: { [string]: number }): Key
	for k, v in DEFAULT do
		if t[k] == nil then
			t[k] = v
		end
	end
	return (t :: any) :: Key
end

local PROFILES: { [string]: { Key } } = {
	-- выживший: шаг 10, бег 16, рывок после удара 22
	Survivor = {
		K({ V = 0 }),
		K({ V = 3, Steps = 2.2, Reach = 24, Push = 24, Lean = 2, ArmF = 12, ArmB = 10, Twist = 3, Roll = 1.5, Sway = 0.07 }),
		K({ V = 10, Steps = 3.3, Reach = 36, Push = 38, Lift = 0.05, Sink = 0.06, Bounce = 0.03, Lean = 6, ArmF = 32, ArmB = 26, ArmBase = 4, ArmOut = 5, Twist = 6, Roll = 2, Sway = 0.06 }),
		K({ V = 16, Steps = 3.7, Reach = 44, Push = 48, Lift = 0.16, Sink = 0.12, Bounce = 0.06, Lean = 12, ArmF = 58, ArmB = 40, ArmBase = 12, ArmOut = 7, Twist = 8, Roll = 2, Sway = 0.04 }),
		K({ V = 22, Steps = 4.1, Reach = 50, Push = 54, Lift = 0.22, Sink = 0.14, Bounce = 0.08, Lean = 18, ArmF = 72, ArmB = 50, ArmBase = 16, ArmOut = 8, Twist = 9, Roll = 1.5, Sway = 0.03 }),
	},
	-- раненый: сутулится, короче шаг на больную (правую) ногу — см. LIMP
	Injured = {
		K({ V = 0, Lean = 10 }),
		K({ V = 3, Steps = 2.2, Reach = 20, Push = 20, Lean = 11, ArmF = 8, ArmB = 6, Twist = 3, Roll = 3, Sway = 0.08 }),
		K({ V = 10, Steps = 3.4, Reach = 32, Push = 34, Lift = 0.03, Sink = 0.08, Bounce = 0.05, Lean = 14, ArmF = 22, ArmB = 18, ArmBase = 6, Twist = 5, Roll = 4, Sway = 0.08, Nod = -6 }),
		K({ V = 16, Steps = 3.8, Reach = 40, Push = 44, Lift = 0.12, Sink = 0.12, Bounce = 0.07, Lean = 17, ArmF = 40, ArmB = 30, ArmBase = 10, ArmOut = 6, Twist = 6, Roll = 4, Sway = 0.06, Nod = -6 }),
		K({ V = 22, Steps = 4.1, Reach = 46, Push = 50, Lift = 0.18, Sink = 0.14, Bounce = 0.08, Lean = 21, ArmF = 52, ArmB = 38, ArmBase = 14, ArmOut = 7, Twist = 7, Roll = 3, Sway = 0.05, Nod = -4 }),
	},
	-- маньяк: тяжёлый широкий шаг с ударом стопы, плечи вперёд
	Killer = {
		K({ V = 0, Lean = 6, ArmOut = 9 }),
		K({ V = 6, Steps = 2.0, Reach = 26, Push = 26, Sink = 0.06, Bounce = 0.04, Lean = 7, ArmF = 14, ArmB = 12, ArmOut = 9, Twist = 4, Roll = 2.5, Sway = 0.08, Nod = -4 }),
		K({ V = 16, Steps = 3.0, Reach = 40, Push = 44, Lift = 0.06, Sink = 0.14, Bounce = 0.12, Lean = 12, ArmF = 34, ArmB = 28, ArmBase = 6, ArmOut = 10, Twist = 7, Roll = 3.5, Sway = 0.07, Nod = -6 }),
		K({ V = 23, Steps = 3.6, Reach = 50, Push = 54, Lift = 0.16, Sink = 0.15, Bounce = 0.1, Lean = 20, ArmF = 48, ArmB = 38, ArmBase = 10, ArmOut = 10, Twist = 8, Roll = 3, Sway = 0.05, Nod = -4 }),
	},
	-- маньяк с выжившим на плече: короче шаг, сильнее раскачка от груза
	Carry = {
		K({ V = 0, Lean = 7, ArmOut = 9 }),
		K({ V = 6, Steps = 1.9, Reach = 24, Push = 24, Sink = 0.08, Bounce = 0.05, Lean = 7, ArmF = 16, ArmB = 12, ArmOut = 10, Twist = 2, Roll = 3.5, Sway = 0.1, Nod = -3 }),
		K({ V = 15, Steps = 2.8, Reach = 36, Push = 40, Lift = 0.03, Sink = 0.14, Bounce = 0.13, Lean = 9, ArmF = 30, ArmB = 24, ArmBase = 4, ArmOut = 10, Twist = 3, Roll = 4.5, Sway = 0.09, Nod = -4 }),
	},
}

-- Присед: широкий выпад (переднюю/заднюю ногу не меняет — у R6 нет колен, чтобы пронести
-- ногу под низким тазом), подкрадывающиеся шажки, корпус низко и вперёд.
local CROUCH = {
	Hip = 1.32, -- высота таза (стоя — 2)
	Front = 62, -- угол передней ноги (°)
	Back = -60, -- угол задней ноги (°)
	Spread = 5, -- ноги чуть шире
	Lean = 34,
	Steps = 2.2, -- шагов в секунду при скорости 5
}

-- Хромота: доля времени, которую «съедает» больная правая нога (см. Gait.stepRate)
local LIMP = 0.2

------------------------------------------------------------------------
-- Геометрия ноги-бруска
------------------------------------------------------------------------

local R_FOOT = math.sqrt(4.25) -- от сустава до нижнего угла бруска (2 вниз, 0.5 в сторону)
local PHI_FOOT = math.atan2(0.5, 2)
local SWING_TANGENT = 0.6 -- насколько перенос продолжает скорость опоры (захлёст/подтягивание)

-- Вынос пятки вперёд от сустава при угле th (нога впереди — опора на пятку)
local function heelX(th: number): number
	return 2 * sin(th) - 0.5 * cos(th)
end

-- Насколько низко достаёт нога (самый нижний угол бруска) при наклоне th
local function reachOf(th: number): number
	return 2 * cos(th) + 0.5 * abs(sin(th))
end
Gait.reachOf = reachOf

local G = {} :: { [string]: number } -- текущий профиль (переиспользуется)

local function sampleProfile(style: string, v: number)
	local prof = PROFILES[style]
	local n = #prof
	local i = 1
	while i < n and v >= prof[i + 1].V do
		i += 1
	end
	local k0 = prof[i] :: any
	local k1 = prof[math.min(i + 1, n)] :: any
	local a = k1.V > k0.V and clamp((v - k0.V) / (k1.V - k0.V), 0, 1) or 0
	for _, f in FIELDS do
		G[f] = k0[f] + (k1[f] - k0[f]) * a
	end
	local reach, push = rad(G.Reach), rad(G.Push)
	G.HeelTravel = heelX(reach) + 0.5
	G.Stride = G.HeelTravel + 2 * sin(push) - 0.5 * cos(push) + 0.5
	-- Доля опоры, при которой стопа не скользит (ограничена разумными пределами)
	G.Duty = (v > 0.3 and G.Stride > 1e-3) and clamp(G.Steps * G.Stride / (2 * v), 0.26, 0.68) or 0.6
end

-- Сдвиг сустава ноги вперёд от скручивания плеч (у R6 таз и плечи — один брусок):
-- twist — амплитуда (рад). На фазе ноги u поворот корпуса = ±twist·cos(2πu).
local function hipShift(u: number, twist: number): number
	return sin(twist) - sin(twist * cos(TAU * u))
end

-- Угол опорной ноги, при котором точка опоры (пятка, затем носок) стоит на месте,
-- когда таз прошёл x от касания
local function stanceAngle(x: number, reach: number, heelTravel: number): number
	if x < heelTravel then
		return asin(clamp((heelX(reach) - x) / R_FOOT, -1, 1)) + PHI_FOOT
	end
	return asin(clamp((0.5 - (x - heelTravel)) / R_FOOT, -1, 1)) - PHI_FOOT
end

-- Угол ноги (рад, мировой) на фазе u ∈ [0,1): u = 0 — касание пяткой впереди.
-- twist — скручивание корпуса (рад): сустав ноги ездит вперёд-назад, опора это учитывает.
-- Возвращает угол, опорная ли нога, и прогресс внутри опоры/переноса.
local function legCycle(u: number, scale: number, twist: number): (number, boolean, number)
	local stride = G.Stride
	local reach, push = rad(G.Reach) * scale, rad(G.Push) * scale
	if stride < 1e-3 then
		return 0, true, 0.5
	end
	stride *= scale
	local heelTravel = G.HeelTravel * scale
	local d = G.Duty
	if u < d then
		local s = u / d
		return stanceAngle(s * stride + hipShift(u, twist), reach, heelTravel), true, s
	end
	-- перенос: от угла отрыва к углу касания, продолжая скорость опоры
	local s = (u - d) / (1 - d)
	local from = stanceAngle(stride + hipShift(d, twist), reach, heelTravel)
	local k = stride / d * (1 - d) * SWING_TANGENT
	local m0 = -k / (R_FOOT * cos(PHI_FOOT + from))
	local m1 = -k / (R_FOOT * cos(reach - PHI_FOOT))
	local s2, s3 = s * s, s * s * s
	local th = (2 * s3 - 3 * s2 + 1) * from + (s3 - 2 * s2 + s) * m0 + (-2 * s3 + 3 * s2) * reach + (s3 - s2) * m1
	return th, false, s
end

-- Желаемая высота таза, пока нога опорная: на беге таз идёт ровнее (от касания к отрыву
-- с просадкой Bounce), а не «перепрыгивает» через прямую ногу. Сколько при этом можно
-- «согнуть» ногу (уйти под землю), решает plant() по точной геометрии.
local function stanceHeight(s: number, scale: number, bounce: number): number
	local reach, push = rad(G.Reach) * scale, rad(G.Push) * scale
	return reachOf(reach) + (reachOf(-push) - reachOf(reach)) * s - bounce * sin(pi * s)
end

-- Нижние углы ноги-бруска относительно её сустава (сустав — верхнее наружное ребро)
local FOOT_L = { V(0, -2, -0.5), V(0, -2, 0.5), V(1, -2, -0.5), V(1, -2, 0.5) }
local FOOT_R = { V(0, -2, -0.5), V(0, -2, 0.5), V(-1, -2, -0.5), V(-1, -2, 0.5) }

-- Насколько ниже сустава достаёт нога при мировом повороте w (самый нижний угол бруска)
local function footReach(w: CFrame, side: number): number
	local low = math.huge
	for _, c in side < 0 and FOOT_L or FOOT_R do
		low = math.min(low, w:VectorToWorldSpace(c).Y)
	end
	return -low
end

-- Высота середины таза, при которой нижний угол ноги касается земли (точная кинематика:
-- поворот корпуса r двигает сустав, поворот ноги legLocal задан в пространстве торса)
local function legDrop(r: CFrame, legLocal: CFrame, side: number): number
	return footReach(r * legLocal, side) - r:VectorToWorldSpace(V(side, 0, 0)).Y
end

-- Какие стопы стоят на земле и насколько их можно «согнуть» (заполняют функции стилей)
local Plant = { L = true, R = true, SinkL = 0, SinkR = 0, Lift = 0 }

-- Ставит таз по высоте так, чтобы опорные стопы касались земли: не выше касания
-- и не глубже допуска Sink. В полёте (нет опорных) — желаемая высота как есть.
local function plant(out, r: CFrame)
	local hipMid = out.RootPos - r.UpVector
	local hip = hipMid.Y + 3
	local hi, lo = -math.huge, -math.huge
	if Plant.L then
		local d = legDrop(r, out.LLeg, -1)
		hi, lo = math.max(hi, d), math.max(lo, d - Plant.SinkL)
	end
	if Plant.R then
		local d = legDrop(r, out.RLeg, 1)
		hi, lo = math.max(hi, d), math.max(lo, d - Plant.SinkR)
	end
	if hi > -math.huge then
		hip = clamp(hip, lo, hi)
	end
	out.RootPos = V(hipMid.X, hip + Plant.Lift - 3, hipMid.Z) + r.UpVector
end

------------------------------------------------------------------------
-- Сборка позы
------------------------------------------------------------------------

local function styleOf(p: Params): string
	if p.Killer then
		return p.Carrying and "Carry" or "Killer"
	end
	if p.Crouching then
		return "Crouch"
	end
	return p.Injured and "Injured" or "Survivor"
end

-- Поворот корпуса и смещение так, чтобы наклон шёл от таза (таз остаётся на высоте hip)
local function torso(pose, pitch: number, yaw: number, roll: number, hip: number, sideX: number): CFrame
	local r = YXZ(rad(-pitch), rad(yaw), rad(roll))
	pose.Root = r
	pose.RootPos = V(sideX, hip - 3, 0) + r.UpVector
	return r
end

-- Нога в мировых углах -> в пространстве торса
local function leg(rInv: CFrame, world: CFrame): CFrame
	return rInv * world
end

-- Голова: держит горизонт (гасит наклон/скручивание корпуса) и смотрит куда надо
local function head(pose, r: CFrame, pitch: number, yaw: number, roll: number?)
	local comp = IDENTITY:Lerp(r:Inverse(), 0.85)
	pose.Neck = comp * YXZ(rad(pitch), rad(yaw), rad(roll or 0))
end

local function armSwing(c: number): number
	return c > 0 and c * G.ArmF or c * G.ArmB
end

------------------------------------------------------------------------
-- Стояние (дыхание, вес, оглядывания)
------------------------------------------------------------------------

local function idle(t: number, p: Params, style: string, out)
	local seed = p.Seed or 0
	local exert = p.Exertion or 0
	local killer = style == "Killer" or style == "Carry"
	local b = sin(p.Breath or t * 1.9)
	local depth = (killer and 1.5 or 1) + exert * 1.6 + (style == "Injured" and 0.8 or 0)
	local shift = Life.weightShift(t, seed, killer and 7 or 5.5)
	if style == "Injured" then
		shift = -0.7 + shift * 0.2 -- бережёт правую ногу
	end
	local hipX = shift * 0.12
	local lean = G.Lean + exert * 5 - b * 0.7 * depth
	-- стопы стоят на месте: при сдвиге таза ноги наклоняются; у ненагруженной носок наружу
	local z = -math.deg(asin(clamp(hipX / 2, -1, 1)))
	local wl = A(0, 9 * math.max(0, shift), z)
	local wr = A(0, -9 * math.max(0, -shift), z)
	-- крен таза, при котором обе стопы-бруски касаются земли (наклонённый брусок «длиннее»)
	local roll = math.deg(asin(clamp((footReach(wr, 1) - footReach(wl, -1)) / 2, -0.5, 0.5)))
	local r = torso(out, lean, sin(t * 0.23 + seed * 6) * 2, roll, 2, hipX)
	local rInv = r:Inverse()
	out.LLeg = leg(rInv, wl)
	out.RLeg = leg(rInv, wr)
	Plant.L, Plant.R, Plant.SinkL, Plant.SinkR = true, true, 0, 0
	Plant.Lift = (b + 1) * 0.008 * depth -- грудь поднимается на вдохе
	local sway = sin(t * 0.9 + seed * 4) * 1.2
	local armLean = G.Lean * 0.6
	out.LArm = A(2 + armLean + b * 0.6 * depth + sway, 0, -(G.ArmOut + b * 0.8 * depth))
	out.RArm = A(2 + armLean + b * 0.6 * depth - sway, 0, G.ArmOut + b * 0.8 * depth)
	local gy, gp = glance(t, seed, killer and 5.5 or 4.2, killer and 0.6 or 0.5, killer and 45 or 60)
	return r, gy, gp + b * 0.8 * depth
end

------------------------------------------------------------------------
-- Цикл шага
------------------------------------------------------------------------

local function stride(p: Params, style: string, v: number, out): (CFrame, number)
	local u0 = (p.Phase / TAU) % 1
	-- направление движения относительно взгляда (маньяк ходит боком и пятится)
	local fwd, side = p.Forward or 1, p.Strafe or 0
	local alpha = math.atan2(side, fwd)
	local backward = abs(alpha) > rad(110)
	if backward then
		alpha -= pi * (alpha > 0 and 1 or -1)
		u0 = 1 - u0
	end
	local sideness = abs(sin(alpha))
	local uL, uR = u0, (u0 + 0.5) % 1
	local d = G.Duty
	-- хромота: правая нога короче шагает, сильнее проседает
	local scaleL, scaleR = 1, 1
	local bounceR, sinkR = G.Bounce, G.Sink
	if style == "Injured" then
		-- здоровая половина цикла дольше (см. stepRate) — шаг длиннее, больная — короче
		scaleL, scaleR = 1 + LIMP, 1 - LIMP
		bounceR += 0.07
		sinkR += 0.06
	end
	local amp = 1 - 0.35 * sideness
	local twistAmp = G.Twist * (1 - sideness)
	local thL, stL, sL = legCycle(uL, scaleL * amp, rad(twistAmp))
	local thR, stR, sR = legCycle(uR, scaleR * amp, rad(twistAmp))
	local hip
	local hL = stL and stanceHeight(sL, scaleL * amp, G.Bounce) or nil
	local hR = stR and stanceHeight(sR, scaleR * amp, bounceR) or nil
	Plant.L, Plant.R, Plant.SinkL, Plant.SinkR, Plant.Lift = stL, stR, G.Sink, sinkR, 0
	if hL or hR then
		hip = math.max(hL or 0, hR or 0)
	else
		-- полёт: от отрыва одной ноги до касания другой
		local f = (uL < 0.5 and (uL - d) or (uL - 0.5 - d)) / math.max(0.5 - d, 1e-3)
		f = clamp(f, 0, 1)
		local reach, push = rad(G.Reach) * amp, rad(G.Push) * amp
		hip = reachOf(-push) + (reachOf(reach) - reachOf(-push)) * f + 4 * G.Lift * f * (1 - f)
	end
	-- корпус: наклон, скручивание плеч навстречу ногам, крен и смещение на опорную ногу
	local onLeft = cos(TAU * (uL - d / 2)) -- +1 в середине опоры левой
	local lean = G.Lean
	local roll = G.Roll * onLeft
	if style == "Injured" then
		-- на больную ногу корпус «проваливается» вбок
		roll -= 3 * math.max(0, -onLeft)
		lean += 3 * math.max(0, -onLeft)
	end
	local twist = G.Twist * cos(TAU * uL) * (1 - sideness)
	local r = torso(out, lean, twist, roll, hip, -G.Sway * onLeft)
	local rInv = r:Inverse()
	-- ноги: качаются в плоскости движения
	local spin = A(0, -math.deg(alpha), 0)
	local unspin = A(0, math.deg(alpha), 0)
	local spread = 10 * sideness
	out.LLeg = leg(rInv, spin * CFrame.Angles(thL, 0, 0) * unspin * A(0, 0, -spread))
	out.RLeg = leg(rInv, spin * CFrame.Angles(thR, 0, 0) * unspin * A(0, 0, spread))
	-- руки: навстречу ногам, с небольшим запаздыванием
	local ca = cos(TAU * (uL - 0.04)) * (1 - 0.6 * sideness)
	local armLean = lean * 0.6
	out.RArm = A(G.ArmBase + armLean + armSwing(ca), 0, G.ArmOut)
	out.LArm = A(G.ArmBase + armLean + armSwing(-ca), 0, -G.ArmOut)
	-- голова чуть «кивает» в такт ударам стоп
	local nod = -1.5 * sin(TAU * 2 * (uL - d * 0.3)) * clamp(v / 16, 0, 1)
	return r, nod
end

------------------------------------------------------------------------
-- Присед
------------------------------------------------------------------------

local function crouch(t: number, p: Params, move: number, out): (CFrame, number, number)
	local seed = p.Seed or 0
	local ph = p.Phase
	local b = sin(p.Breath or t * 1.9)
	local depth = 1 + (p.Exertion or 0)
	local frontLeft = seed < 0.5
	-- шажок: передняя нога выносится, задняя подтягивается следом
	local stepF = sin(ph) * 9 * move
	local stepB = sin(ph - 1.3) * 7 * move
	local front = CROUCH.Front + stepF
	local back = CROUCH.Back + stepB
	local hip = CROUCH.Hip
	Plant.L, Plant.R, Plant.SinkL, Plant.SinkR = true, true, 0, 0
	Plant.Lift = math.max(0, sin(ph)) * 0.06 * move + (b + 1) * 0.006 * depth
	local sideX = sin(ph) * 0.1 * move + (frontLeft and -0.05 or 0.05)
	local lean = CROUCH.Lean - b * 0.6 * depth + sin(ph * 2) * 1.5 * move
	local r = torso(out, lean, (frontLeft and -6 or 6) + sin(ph) * 3 * move, sin(ph) * 3 * move, hip, sideX)
	local rInv = r:Inverse()
	local spread = CROUCH.Spread
	local fl = A(front, 0, frontLeft and -spread or spread)
	local bl = A(back, 0, frontLeft and spread or -spread)
	out.LLeg = leg(rInv, frontLeft and fl or bl)
	out.RLeg = leg(rInv, frontLeft and bl or fl)
	-- руки вперёд-вниз, у колен; чуть балансируют
	local arm = 34 + lean * 0.35
	out.LArm = A(arm + sin(ph + 0.6) * 6 * move + b * depth, 0, -8)
	out.RArm = A(arm - sin(ph + 0.6) * 6 * move + b * depth, 0, 8)
	local gy, gp = glance(t, seed, 3.6, 0.55 * (1 - move), 55)
	return r, gy, gp + 8
end

------------------------------------------------------------------------
-- Поверх: руки по «роли» (рана, оружие, колокол, груз)
------------------------------------------------------------------------

local function overlays(t: number, p: Params, style: string, out, move: number, u: number)
	local b = sin(p.Breath or t * 1.9)
	if style == "Injured" then
		-- зажимает рану левой рукой, локоть прижат
		out.LArm = A(50 + b * 2 + sin(TAU * u * 2) * 3 * move, -8, 30)
	elseif style == "Killer" then
		-- оружие в правой: рука тяжелее и впереди
		local x, _, z = out.RArm:ToEulerAnglesXYZ()
		out.RArm = A(14 + math.deg(x) * 0.45, 0, 10 + math.deg(z) * 0.2)
		if p.KillerType == "Wraith" then
			out.LArm = A(52 + sin(t * 2) * 3 + sin(TAU * u) * 6 * move, 0, -12) -- держит колокол
		end
	elseif style == "Carry" then
		-- правая рука обхватывает ноги выжившего на плече
		out.RArm = A(132 + sin(TAU * u * 2) * 3 * move + b, 0, 10)
	end
end

------------------------------------------------------------------------
-- Публичное
------------------------------------------------------------------------

-- Скорость изменения фазы шага (рад/с). Касания стоп — при фазе, кратной π.
-- crouching оставлен для совместимости; при переданных p берутся все их флаги.
function Gait.stepRate(speed: number, crouching: boolean?, p: Params?): number
	local v = speed / (p and p.Scale or 1)
	if v < 0.5 then
		return 0
	end
	if crouching or (p and p.Crouching and not p.Killer) then
		return pi * CROUCH.Steps * clamp(v / 5, 0.5, 1.6)
	end
	local style = p and styleOf(p) or "Survivor"
	sampleProfile(style, v)
	local rate = pi * G.Steps
	if style == "Injured" and p then
		-- больная (правая) половина цикла проходит быстрее, здоровая — медленнее
		rate /= (p.Phase % TAU) < pi and (1 + LIMP) or (1 - LIMP)
	end
	return rate
end

local scratchIdle, scratchMove = {}, {}

-- Передвижение и стояние. Сигнатура прежняя: (время, Params) -> поза.
function Gait.locomotion(t: number, p: Params)
	local style = styleOf(p)
	local v = p.Speed / (p.Scale or 1)
	local move = smoothstep(0.3, 2.2, v)
	local out = {}
	local r, lookYaw, lookPitch
	local nodBase = 0
	if style == "Crouch" then
		r, lookYaw, lookPitch = crouch(t, p, move, out)
	else
		sampleProfile(style, v)
		nodBase = G.Nod
		if move >= 1 then
			local nod
			r, nod = stride(p, style, v, out)
			lookYaw, lookPitch = 0, nod
		elseif move <= 0 then
			r, lookYaw, lookPitch = idle(t, p, style, out)
		else
			-- трогается с места / останавливается: смешиваем стояние и шаг
			local _, gy, gp = idle(t, p, style, scratchIdle)
			local lift = Plant.Lift
			local _, nod = stride(p, style, v, scratchMove)
			Clip.blend(scratchIdle, scratchMove, move, out)
			r = out.Root
			lookYaw, lookPitch = gy * (1 - move), gp * (1 - move) + nod * move
			if move < 0.5 then
				Plant.L, Plant.R = true, true
			end
			Plant.SinkL *= move
			Plant.SinkR *= move
			Plant.Lift = lift * (1 - move)
		end
	end
	-- разгон/торможение и вираж: корпус наклоняется от таза, ноги остаются под телом
	local accel = clamp((p.AccelForward or 0) * 0.3, -10, 14)
	local bank = clamp(-(p.AccelSide or 0) * 0.22, -10, 10)
	if abs(accel) > 0.05 or abs(bank) > 0.05 then
		local extra = YXZ(rad(-accel), 0, rad(bank))
		local hipPos = out.RootPos - r.UpVector
		r = r * extra
		out.Root = r
		out.RootPos = hipPos + r.UpVector
		local inv = extra:Inverse()
		out.LLeg = inv * out.LLeg
		out.RLeg = inv * out.RLeg
	end
	plant(out, r)
	overlays(t, p, style, out, move, (p.Phase / TAU) % 1)
	-- голова держит горизонт и смотрит на маньяка / в поворот / по сторонам
	local look = p.LookYaw or 0
	local yaw = look + clamp((p.TurnRate or 0) * 7, -25, 25) + (look ~= 0 and 0 or lookYaw)
	head(out, r, nodBase + lookPitch, yaw)
	return out
end

return Gait
