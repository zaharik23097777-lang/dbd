-- Особые состояния выживших: ползёт (повержен), на плече у маньяка, на крюке, в шкафчике,
-- в капкане, сидит у костра. Все «живые»: дыхание, мелкие движения, оглядывания.
-- Углы — как в позах (Rig.A): +X вперёд, +Y влево, +Z вправо; корпус вперёд — минус X.
local Rig = require(script.Parent.Rig)
local Life = require(script.Parent.Life)
local Gait = require(script.Parent.Gait)

type Params = Gait.Params

local States = {}

local sin, cos, abs, max, clamp, rad, pi = math.sin, math.cos, math.abs, math.max, math.clamp, math.rad, math.pi
local TAU = pi * 2
local A = Rig.A
local V = Vector3.new
local YXZ = CFrame.fromEulerAnglesYXZ
local IDENTITY = CFrame.identity
local smoothstep = Life.smoothstep

-- Голова: гасит поворот корпуса на k (0..1) и смотрит (наклон, поворот, крен) в мире
local function neck(r: CFrame, k: number, pitch: number, yaw: number, roll: number?): CFrame
	return IDENTITY:Lerp(r:Inverse(), k) * YXZ(rad(pitch), rad(yaw), rad(roll or 0))
end

-- Корпус, наклонённый от таза: таз на высоте hip (стоя — 2)
local function torso(pose, pitch: number, yaw: number, roll: number, hip: number, side: number?, fwd: number?): CFrame
	local r = YXZ(rad(-pitch), rad(yaw), rad(roll))
	pose.Root = r
	pose.RootPos = V(side or 0, hip - 3, fwd or 0) + r.UpVector
	return r
end

------------------------------------------------------------------------
-- Повержен: лежит на животе и подтягивается руками (по-пластунски)
------------------------------------------------------------------------

-- Гребок одной руки, w ∈ [0,1): 0..0.55 — тянет (ладонь на земле, рука уходит вбок),
-- дальше — заносит руку вперёд над землёй. Возвращает (подъём, отведение) в градусах.
local function stroke(w: number, reach: number): (number, number)
	if w < 0.55 then
		local s = smoothstep(0, 1, w / 0.55)
		return 0, 10 + (60 - 10) * s * reach
	end
	local s = (w - 0.55) / 0.45
	return 22 * sin(pi * s) * reach, 10 + 50 * reach * (1 - smoothstep(0, 1, s))
end

function States.Crawl(t: number, p: Params)
	local seed = p.Seed or 0
	local moving = p.Speed > 0.3
	local b = sin(p.Breath or t * 2.2)
	-- на месте: слабые попытки дотянуться вперёд, чаще просто тяжело дышит
	local ph = moving and p.Phase or t * 0.9
	local reach = moving and 1 or 0.35
	local w = (ph / TAU) % 1
	local liftL, outL = stroke(w, reach)
	local liftR, outR = stroke((w + 0.5) % 1, reach)
	local pull = sin(TAU * w) -- + тянет левая
	local pitch = 87 - b * 1.2
	local r = YXZ(rad(-pitch), rad(pull * 5 * reach), rad(pull * 4 * reach))
	local fwd = moving and (abs(sin(TAU * w)) * 0.12) or 0
	local pose = {
		Root = r,
		RootPos = V(pull * 0.08 * reach, -2.43 + b * 0.02, -0.3 - fwd),
		-- руки над головой (вперёд по земле) и в стороны; подъём — от земли
		LArm = A(180 + liftL, 0, -outL),
		RArm = A(180 + liftR, 0, outR),
		-- ноги волочатся, чуть разведены, иногда отталкиваются
		LLeg = A(-4 - max(0, -pull) * 10 * reach, 0, -6 - pull * 3),
		RLeg = A(-4 - max(0, pull) * 10 * reach, 0, 6 - pull * 3),
	}
	-- голова приподнята и смотрит вперёд; без движения иногда роняет голову
	local drop = moving and 0 or Life.event(t, seed, 6, 0.6, 0.15, 0.5) * 30
	local gy = moving and pull * 6 or Life.glance(t, seed, 5, 0.5, 35)
	pose.Neck = A(62 - drop + b * 2, gy, 0)
	return pose
end

------------------------------------------------------------------------
-- На плече у маньяка: лежит животом на плече, ноги свисают перед грудью маньяка,
-- руки и голова — за его спиной. Корень выжившего повёрнут так, что «вперёд» = вниз.
------------------------------------------------------------------------

function States.Carried(t: number, p: Params)
	local seed = p.Seed or 0
	local wig = p.Wiggle or 0
	-- вырывается всё отчаяннее по мере прогресса
	local k = (0.3 + 0.7 * Life.bursts(t, seed)) * (0.45 + 0.55 * wig)
	-- болтается в такт шагам маньяка
	local gait = sin(p.Phase * 2) * clamp(p.Speed / 14, 0, 1)
	local kick = sin(t * 9.5 + seed * 5)
	local punch = sin(t * 6.3 + seed * 3)
	local twist = sin(t * 3.1 + seed)
	return {
		Root = A(twist * 4 * k, twist * 10 * k, sin(t * 2.3) * 6 * k),
		LLeg = A(62 + kick * 26 * k + gait * 4, 0, -4),
		RLeg = A(62 - kick * 26 * k + gait * 4, 0, 4),
		LArm = A(92 + punch * 28 * k + gait * 8, 0, -10 - k * 10),
		RArm = A(92 - punch * 28 * k + gait * 8, 0, 10 + k * 10),
		Neck = A(-34 + sin(t * 4.1) * 12 * k + gait * 5, sin(t * 3.7 + 1) * 25 * k, 0),
	}
end

------------------------------------------------------------------------
-- На крюке: крюк входит в плечо сзади-слева (см. Art/Props/Hook.lua: HangPoint под крюком).
-- Левое плечо задрано, левая рука держится за крюк, правая висит, ноги болтаются.
-- p.Struggle — борьба с Сущностью: толкает её лапы, бьётся.
------------------------------------------------------------------------

function States.Hooked(t: number, p: Params)
	local seed = p.Seed or 0
	local b = sin(p.Breath or t * 2.6)
	if p.Struggle then
		local e = Life.bursts(t * 1.6, seed)
		local jerk = sin(t * 11 + seed * 7) ^ 3
		local kick = sin(t * 8.3 + seed)
		local push = sin(t * 5.2 + seed * 2)
		local r = YXZ(rad(4 + jerk * 6 * e), rad(sin(t * 3.4) * 12 * e), rad(-8 + jerk * 7 * e))
		return {
			Root = r,
			RootPos = V(0, jerk * 0.06 * e, 0),
			LArm = A(172 + push * 14 * e, 0, 14 - push * 10 * e),
			RArm = A(158 - push * 24 * e, 0, -6 + jerk * 14 * e),
			LLeg = A(10 + kick * 30 * e, 0, -4 - abs(kick) * 6 * e),
			RLeg = A(10 - kick * 30 * e, 0, 4 + abs(kick) * 6 * e),
			Neck = neck(r, 0.5, 18 + jerk * 12 * e, sin(t * 4.7) * 30 * e, 0),
		}
	end
	-- тело медленно качается, иногда слабо дёргается от боли
	local sway = sin(t * 1.1 + seed * 4)
	local twitch = Life.event(t, seed, 3.2, 0.45, 0.06, 0.35)
	local r = YXZ(rad(-7 + sway * 2 - twitch * 5 - b * 1.2), rad(sway * 4), rad(-8 + twitch * 3))
	local gy, gp = Life.glance(t, seed, 5, 0.4, 40)
	local lift = Life.event(t + 2, seed, 7, 0.5, 0.2, 0.4) -- поднимает голову
	return {
		Root = r,
		RootPos = V(0, b * 0.02, 0),
		LArm = A(174 + twitch * 4 + b, 0, 12),
		RArm = A(10 + sway * 6 + twitch * 10, 0, 7 + sway * 2),
		LLeg = A(6 + sway * 5 - twitch * 12, 0, -3),
		RLeg = A(-2 + sway * 5 + twitch * 18, 0, 4),
		Neck = neck(r, 0.3, -30 + lift * 26 + gp * lift + b * 1.5, gy * lift, 10 - lift * 8),
	}
end

------------------------------------------------------------------------
-- В шкафчике: часто и испуганно дышит, руки прижаты к груди, смотрит в щели дверцы
------------------------------------------------------------------------

function States.Hidden(t: number, p: Params)
	local seed = p.Seed or 0
	local b = sin(t * 6.4 + seed * 3)
	local shift = Life.weightShift(t, seed, 4)
	local flinch = Life.event(t, seed, 4, 0.35, 0.04, 0.4) -- вздрагивает от звука
	local pose = {}
	local r = torso(pose, 4 + flinch * 4 - b * 1.2, sin(t * 0.7 + seed) * 3, shift * 1.2, 2 - flinch * 0.05 + b * 0.015, shift * 0.06)
	local rInv = r:Inverse()
	pose.LLeg = rInv * A(0, 0, -1 - shift * 2)
	pose.RLeg = rInv * A(0, 0, 1 - shift * 2)
	pose.LArm = A(62 + b * 2 + flinch * 12, -10, 30 + flinch * 6)
	pose.RArm = A(66 + b * 2 + flinch * 12, 10, -30 - flinch * 6)
	-- выглядывает в щели: медленно водит головой, чуть вверх
	local look = sin(t * 0.55 + seed * 6) * 22 + sin(t * 1.7) * 4
	pose.Neck = neck(r, 0.8, 4 + b * 1.5 - flinch * 6, look, 0)
	return pose
end

------------------------------------------------------------------------
-- В капкане: правая нога в челюстях капкана, левая на колене, тянется к капкану,
-- иногда пытается выдернуть ногу и вздрагивает от боли
------------------------------------------------------------------------

function States.Trapped(t: number, p: Params)
	local seed = p.Seed or 0
	local b = sin(p.Breath or t * 2.8)
	local tug = Life.event(t, seed, 2.6, 0.75, 0.08, 0.3) -- рывок ногой
	local shake = sin(t * 23) * 0.6 -- дрожь от боли
	local lean = 38 - tug * 12 - b * 1.5
	local pose = {}
	local r = torso(pose, lean, -8 + tug * 4, -5, 1.6 + tug * 0.08 + b * 0.01, 0.1, -0.1)
	local rInv = r:Inverse()
	pose.RLeg = rInv * A(34 + tug * 6, 0, 3) -- в капкане
	pose.LLeg = rInv * A(-56, 0, -6) -- колено на земле
	-- руки к капкану (вниз-вперёд к правой стопе), на рывке тянут
	pose.LArm = A(68 - tug * 22 + shake, 0, 24)
	pose.RArm = A(64 - tug * 22 - shake, 0, 6)
	local gy, gp = Life.glance(t, seed, 3.5, 0.45, 50)
	pose.Neck = neck(r, 0.5, -28 + gp + tug * 10, gy, 0)
	return pose
end

------------------------------------------------------------------------
-- Сидит у костра (лобби): руки на коленях, греет руки, оглядывается
------------------------------------------------------------------------

function States.Sit(t: number, p: Params)
	local seed = p.Seed or 0
	local b = sin(p.Breath or t * 1.8)
	local warm = Life.event(t, seed, 9, 0.6, 0.12, 0.25) -- тянет руки к огню и трёт
	local rub = sin(t * 9) * warm
	local lean = 10 + seed * 6 + warm * 6 - b
	local r = YXZ(rad(-lean), rad(sin(t * 0.3 + seed * 5) * 3), 0)
	local gy, gp = Life.glance(t, seed, 4.5, 0.55, 55)
	local bent = seed > 0.5 and 1 or -1 -- одна нога чуть подогнута
	return {
		Root = r,
		RootPos = V(0, b * 0.015, 0),
		LLeg = A(90 + lean * 0.2 + bent * 4, 0, -5),
		RLeg = A(90 + lean * 0.2 - bent * 4, 0, 5),
		LArm = A(52 + warm * 28 + rub * 4 + b, 0, 6 + warm * 14),
		RArm = A(52 + warm * 28 - rub * 4 + b, 0, -6 - warm * 14),
		Neck = neck(r, 0.6, -6 + gp - warm * 8 + b, gy * (1 - warm), 0),
	}
end

return States
