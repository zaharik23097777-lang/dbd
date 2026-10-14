-- Проверяет математику суставов на настоящих C0/C1 персонажа R6, пружины, клипы,
-- походку (стопы на земле, не скользят) и все позы.
-- ANIM_REPORT=1 — напечатать метрики походок (для настройки профилей).
local Harness = require("./harness")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3

local game, req = Harness.load(process.args[1] or "DeadByDaylight.rbxlx")
local Anim = game.ReplicatedStorage.Shared.Anim
local Rig = req(Anim.Rig)
local Poses = req(Anim.Poses)
local Spring = req(Anim.Spring)
local Clip = req(Anim.Clip)
local Gait = req(Anim.Gait)

local REPORT = process.env.ANIM_REPORT == "1"
local failures = 0
local function check(cond, msg)
	if not cond then
		failures += 1
		print("FAIL: " .. msg)
	end
end
local function near(a, b, eps)
	return math.abs(a - b) < (eps or 1e-3)
end

-- Стандартные суставы R6 (значения из стандартного персонажа Roblox)
local R_RIGHT = { 0, 0, 1, 0, 1, 0, -1, 0, 0 }
local R_LEFT = { 0, 0, -1, 0, 1, 0, 1, 0, 0 }
local R_NECK = { -1, 0, 0, 0, 0, 1, 0, 1, 0 }
local function cf(x, y, z, r)
	return CFrame.new(x, y, z, table.unpack(r))
end
local joints = {
	RArm = Rig.makeJoint(nil, cf(1, 0.5, 0, R_RIGHT), cf(-0.5, 0.5, 0, R_RIGHT)),
	LArm = Rig.makeJoint(nil, cf(-1, 0.5, 0, R_LEFT), cf(0.5, 0.5, 0, R_LEFT)),
	RLeg = Rig.makeJoint(nil, cf(1, -1, 0, R_RIGHT), cf(0.5, 1, 0, R_RIGHT)),
	LLeg = Rig.makeJoint(nil, cf(-1, -1, 0, R_LEFT), cf(-0.5, 1, 0, R_LEFT)),
	Neck = Rig.makeJoint(nil, cf(0, 1, 0, R_NECK), cf(0, -0.5, 0, R_NECK)),
	Root = Rig.makeJoint(nil, cf(0, 0, 0, R_NECK), cf(0, 0, 0, R_NECK)),
}

local function part1(joint, transform)
	-- Положение Part1 в пространстве Part0
	return joint.C0 * transform * joint.C1:Inverse()
end

local function finite(c)
	for _, v in { c:GetComponents() } do
		if v ~= v or v == math.huge or v == -math.huge then
			return false
		end
	end
	return true
end
local function finiteV(v)
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z and math.abs(v.X) < 1e6 and math.abs(v.Y) < 1e6 and math.abs(v.Z) < 1e6
end
local function angleBetween(a, b)
	return Rig.rotVec(a:Inverse() * b).Magnitude
end

------------------------------------------------------------------------
-- 1. Суставы
------------------------------------------------------------------------

-- Нулевая поза -> единичный Transform
for name, j in joints do
	local t = Rig.transform(j, CFrame.new())
	local p = t.Position
	local rx, ry, rz = t:ToEulerAnglesXYZ()
	check(p.Magnitude < 1e-4 and near(rx, 0) and near(ry, 0) and near(rz, 0), "rest identity " .. name)
end

-- Рука вперёд на 90°: рука направлена вперёд (-Z торса)
for _, name in { "RArm", "LArm", "RLeg", "LLeg" } do
	local j = joints[name]
	local rel = part1(j, Rig.transform(j, Poses.A(90)))
	local down = -rel.UpVector
	check(near(down.Z, -1, 1e-2), name .. " +90 points forward, got " .. tostring(down))
	-- Сустав остаётся на месте
	local restRel = part1(j, CFrame.new())
	local pivotLocalRest = restRel:PointToObjectSpace(j.Pivot)
	local pivotNow = rel:PointToWorldSpace(pivotLocalRest)
	check((pivotNow - j.Pivot).Magnitude < 1e-3, name .. " pivot stays")
end

-- Правая рука +Z отводится вправо
do
	local j = joints.RArm
	local rel = part1(j, Rig.transform(j, Poses.A(0, 0, 90)))
	check(-rel.UpVector.X > 0.99, "RArm +Z abducts to the right")
end

-- Наклон корпуса вперёд отрицательным X
do
	local j = joints.Root
	local rel = part1(j, Rig.transform(j, Poses.A(-30)))
	check(rel.UpVector.Z < -0.4, "Root -X leans forward")
	local moved = part1(j, Rig.transform(j, CFrame.new(), Vector3.new(0, -2, 0)))
	check(near(moved.Position.Y, -2), "RootPos moves torso down")
end

-- Голова +X смотрит вверх, +Y поворачивает влево
do
	local j = joints.Neck
	local rel = part1(j, Rig.transform(j, Poses.A(30)))
	check(rel.LookVector.Y > 0.4, "Neck +X looks up")
	rel = part1(j, Rig.transform(j, Poses.A(0, 40, 0)))
	check(rel.LookVector.X < -0.5, "Neck +Y turns left")
end

-- Rig.aim: конечность указывает в заданную сторону
for _, dir in { Vector3.new(0, -1, 0), Vector3.new(0, 0, -1), Vector3.new(1, -1, -1), Vector3.new(-0.3, 0.8, 0.2) } do
	local j = joints.RArm
	local rel = part1(j, Rig.transform(j, Rig.aim(dir)))
	check((-rel.UpVector - dir.Unit).Magnitude < 1e-3, "Rig.aim points along " .. tostring(dir))
end

------------------------------------------------------------------------
-- 2. Пружины: сходятся и устойчивы при любом шаге
------------------------------------------------------------------------

local DTS = { 1 / 240, 1 / 120, 1 / 60, 1 / 30, 1 / 15, 1 / 10 }
for name, tuning in Spring.R6 do
	for _, dt in DTS do
		-- скачок цели: перелёт ограничен, через 3 с — на месте
		local s = Spring.rot(tuning)
		Spring.stepRot(s, CFrame.identity, dt)
		local target = Poses.A(70, -30, 20)
		local start = angleBetween(CFrame.identity, target)
		local worst = 0
		local ok = true
		for _ = 1, math.ceil(3 / dt) do
			local v = Spring.stepRot(s, target, dt)
			ok = ok and finite(v)
			worst = math.max(worst, angleBetween(v, target))
		end
		check(ok, ("spring %s dt=%.4f finite"):format(name, dt))
		check(worst <= start * 1.0001, ("spring %s dt=%.4f never moves away (%.3f > %.3f)"):format(name, dt, worst, start))
		check(angleBetween(s.Value, target) < 1e-3, ("spring %s dt=%.4f converges (err %.5f)"):format(name, dt, angleBetween(s.Value, target)))
		check(s.Velocity.Magnitude < 1e-2, ("spring %s dt=%.4f settles"):format(name, dt))

		-- движущаяся цель (цикл шага): отставание небольшое и ограниченное
		local m = Spring.rot(tuning)
		local maxErr = 0
		local t = 0
		for i = 1, math.ceil(4 / dt) do
			t = i * dt
			local goal = Poses.A(math.sin(t * 9) * 40, 0, math.cos(t * 4) * 10)
			local v = Spring.stepRot(m, goal, dt)
			ok = ok and finite(v)
			if t > 1 then
				maxErr = math.max(maxErr, angleBetween(v, goal))
			end
		end
		check(ok, ("spring %s dt=%.4f tracking finite"):format(name, dt))
		local limit = math.rad(dt <= 1 / 30 and 25 or 60)
		check(maxErr < limit, ("spring %s dt=%.4f tracking lag %.1f°"):format(name, dt, math.deg(maxErr)))
	end
end
do
	-- смещение корпуса и лёгкий перелёт у недодемпфированной пружины
	for _, dt in DTS do
		local s = Spring.vec(Spring.R6.RootPos)
		Spring.stepVec(s, Vector3.zero, dt)
		local target = Vector3.new(0, -1.2, 0.4)
		local overshoot = 0
		local ok = true
		for _ = 1, math.ceil(3 / dt) do
			local v = Spring.stepVec(s, target, dt)
			ok = ok and finiteV(v)
			overshoot = math.max(overshoot, -(v.Y - target.Y) * (1 / 1.2))
		end
		check(ok and (s.Value - target).Magnitude < 1e-3, ("vec spring dt=%.4f converges"):format(dt))
		check(overshoot < 0.25, ("vec spring dt=%.4f overshoot %.2f"):format(dt, overshoot))
	end
	-- перелёт есть (поза «оседает»), но небольшой
	local s = Spring.rot(Spring.R6.LArm)
	Spring.stepRot(s, CFrame.identity, 1 / 60)
	local over = 0
	for _ = 1, 180 do
		local v = Spring.stepRot(s, Poses.A(60), 1 / 60)
		local x = v:ToEulerAnglesXYZ()
		over = math.max(over, math.deg(x) - 60)
	end
	check(over > 0.5 and over < 15, ("arm spring overshoots slightly (%.1f°)"):format(over))
	-- частота в 2 раза выше — успокаивается быстрее
	local slow, fast = Spring.rot(Spring.R6.Root), Spring.rot(Spring.R6.Root)
	Spring.stepRot(slow, CFrame.identity, 1 / 60)
	Spring.stepRot(fast, CFrame.identity, 1 / 60)
	for _ = 1, 12 do
		Spring.stepRot(slow, Poses.A(40), 1 / 60)
		Spring.stepRot(fast, Poses.A(40), 1 / 60, 2)
	end
	check(angleBetween(fast.Value, Poses.A(40)) < angleBetween(slow.Value, Poses.A(40)), "stiffness speeds the spring up")
end

------------------------------------------------------------------------
-- 3. Клипы
------------------------------------------------------------------------

local A = Poses.A
for name, fn in Clip.Ease do
	check(near(fn(0), 0, 1e-6) and near(fn(1), 1, 1e-6), "ease " .. name .. " endpoints")
	for i = 0, 20 do
		local v = fn(i / 20)
		check(v == v and v > -0.5 and v < 1.5, "ease " .. name .. " range")
	end
end
check(Clip.Ease.BackOut(0.6) > 1 and Clip.Ease.Elastic(0.33) > 1, "Back/Elastic overshoot")

do
	local keys = {
		{ T = 0, Pose = { RArm = A(30, 0, 10), Root = A(0, 10, 0), RootPos = Vector3.new(0, 0, 0) } },
		{ T = 0.2, Pose = { RArm = A(170, 0, 10), Root = A(5, 15, 0) }, Ease = "SineInOut" },
		{ T = 0.35, Pose = { RArm = A(20, 0, 14), Root = A(-12, -10, 0), RootPos = Vector3.new(0, -0.3, -0.2) }, Ease = "CubicIn" },
		{ T = 0.6, Pose = { RArm = A(40, 0, 10), Root = A(0, 0, 0) }, Ease = "BackOut" },
	}
	local clip = Clip.new({ Duration = 0.8, FadeIn = 0.1, FadeOut = 0.2, Keys = keys })
	check(#Clip.check(clip) == 0, "test clip passes Clip.check: " .. table.concat(Clip.check(clip), "; "))
	-- попадает в ключи
	for _, key in keys do
		local pose = Clip.sample(clip, key.T)
		for joint, value in key.Pose do
			if joint == "RootPos" then
				check((pose.RootPos - value).Magnitude < 1e-4, ("clip hits key T=%.2f %s"):format(key.T, joint))
			else
				check(angleBetween(pose[joint], value) < 1e-3, ("clip hits key T=%.2f %s"):format(key.T, joint))
			end
		end
	end
	-- конечные значения между ключами и за пределами
	for i = -5, 100 do
		local pose = Clip.sample(clip, i / 100)
		for joint, value in pose do
			check(if joint == "RootPos" then finiteV(value) else finite(value), "clip sample finite " .. joint)
		end
	end
	-- Back даёт перелёт (рука проходит дальше 40° по пути от 20° к 40°)
	local maxArm = -math.huge
	for i = 0, 50 do
		local x = Clip.sample(clip, 0.35 + 0.25 * i / 50).RArm:ToEulerAnglesXYZ()
		maxArm = math.max(maxArm, math.deg(x))
	end
	check(maxArm > 40.5, ("BackOut overshoots key (%.1f°)"):format(maxArm))
	-- RootPos держится между ключами, где сустав не указан
	check((Clip.sample(clip, 0.25).RootPos - Vector3.new(0, -0.3, -0.2) * (1 / 1)).Magnitude < 0.3, "RootPos interpolated across keys")
	-- совместимость с OneShot: Fn(a)
	check(angleBetween(clip.Fn(0.25).RArm, A(170, 0, 10)) < 1e-3, "clip.Fn(a) samples at a*Duration")
	-- веса слоя
	check(near(Clip.weight(clip, 0), 0) and near(Clip.weight(clip, 0.4), 1) and near(Clip.weight(clip, 0.8), 0), "clip fade weights")
	check(Clip.weight(clip, 0.05) > 0 and Clip.weight(clip, 0.05) < 1, "clip fade-in in between")
end

do
	-- зацикленный клип: непрерывен через конец цикла
	local loop = Clip.new({
		Duration = 1,
		Loop = true,
		Keys = {
			{ T = 0, Pose = { LArm = A(10) }, Ease = "SineInOut" },
			{ T = 0.5, Pose = { LArm = A(60) }, Ease = "SineInOut" },
		},
	})
	check(angleBetween(Clip.sample(loop, 0.999).LArm, Clip.sample(loop, 1.001).LArm) < math.rad(1), "loop clip continuous at wrap")
	check(angleBetween(Clip.sample(loop, 0.75).LArm, A(35)) < math.rad(1), "loop clip interpolates last->first")
	check(angleBetween(Clip.sample(loop, 2.5).LArm, A(60)) < 1e-3, "loop clip repeats")
end

do
	-- строитель: подготовка -> удар -> захлёст -> возврат
	local m = Clip.motion({
		Anticipation = { Time = 0.2, Pose = { RArm = A(160, 0, 10), Root = A(4, 15, 0) }, Ease = "SineInOut" },
		Action = { Time = 0.08, Pose = { RArm = A(10, 0, 10), Root = A(-12, -12, 0), LArm = A(-20) }, Ease = "CubicIn" },
		FollowThrough = { Time = 0.12, Pose = { RArm = A(-15, 0, 12) }, Ease = "CubicOut" },
		Hold = 0.05,
		Recover = { Time = 0.3, Ease = "SineInOut" },
		Stiffness = 1.6,
	})
	check(near(m.Duration, 0.75), ("motion duration %.3f"):format(m.Duration))
	check(near(Clip.weight(m, 0), 0) and near(Clip.weight(m, 0.2), 1) and near(Clip.weight(m, 0.75), 0), "motion fades in/out")
	check(angleBetween(Clip.sample(m, 0.2).RArm, A(160, 0, 10)) < 1e-3, "motion anticipation key")
	check(angleBetween(Clip.sample(m, 0.28).RArm, A(10, 0, 10)) < 1e-3, "motion action key")
	check(angleBetween(Clip.sample(m, 0.4).RArm, A(-15, 0, 12)) < 1e-3, "motion follow-through key")
	check(angleBetween(Clip.sample(m, 0.4).Root, A(-12, -12, 0)) < 1e-3, "motion phases inherit joints")
	check(angleBetween(Clip.sample(m, 0.1).LArm, A(-20)) < 1e-3, "motion back-fills later joints")
	check(m.Stiffness == 1.6 and #Clip.check(m) == 0, "motion stiffness/check")
end

do
	-- слои
	local base = { Root = A(-10), LArm = A(20), RootPos = Vector3.new(0, -0.5, 0) }
	local dst = Clip.copy(base, {})
	Clip.layer(dst, { LArm = A(80), RootPos = Vector3.new(0, -1, 0) }, 0.5)
	check(angleBetween(dst.LArm, A(50)) < 1e-3 and near(dst.RootPos.Y, -0.75), "layer blends by weight")
	check(angleBetween(dst.Root, A(-10)) < 1e-6, "layer keeps other joints")
	local add = Clip.copy(base, {})
	Clip.layer(add, { LArm = A(10), RootPos = Vector3.new(0, 0.2, 0) }, 1, true)
	check(angleBetween(add.LArm, A(30)) < 1e-3 and near(add.RootPos.Y, -0.3), "additive layer adds")
	local bl = Clip.blend(base, { Root = A(10) }, 0.5, {})
	check(angleBetween(bl.Root, A(0)) < 1e-3 and angleBetween(bl.LArm, A(10)) < 1e-3, "blend between poses")
end

------------------------------------------------------------------------
-- 4. Походка: стопы на земле и не скользят
------------------------------------------------------------------------

-- Мировые (в пространстве HumanoidRootPart) CFrame торса и ног для позы
local function legFrames(pose)
	local torso = part1(joints.Root, Rig.transform(joints.Root, pose.Root or CFrame.identity, pose.RootPos or Vector3.zero))
	local out = {}
	for _, name in { "LLeg", "RLeg" } do
		local j = joints[name]
		out[name] = torso * part1(j, Rig.transform(j, pose[name] or CFrame.identity))
	end
	return out
end
-- Нижние углы ноги-бруска 1×2×1 (y относительно земли: HRP на высоте 3) и самый нижний из них
local CORNERS = { Vector3.new(-0.5, -1, -0.5), Vector3.new(0.5, -1, -0.5), Vector3.new(-0.5, -1, 0.5), Vector3.new(0.5, -1, 0.5) }
local function corners(legCF)
	local out = {}
	for i, c in CORNERS do
		out[i] = legCF:PointToWorldSpace(c) + Vector3.new(0, 3, 0)
	end
	return out
end
local function lowest(legCF)
	local best, index
	for i, p in corners(legCF) do
		if not best or p.Y < best.Y then
			best, index = p, i
		end
	end
	return best, index
end

-- Метрики цикла: мин./макс. высота нижней точки стоп, проскальзывание опорной стопы
local function gaitMetrics(p, steps)
	local speed = p.Speed
	local rate = Poses.stepRate(speed, p.Crouching, p)
	local period = 2 * math.pi / rate
	local n = steps or 96
	local dt = period / n
	local minY, maxDip = math.huge, 0
	local slide, contactTime = 0, 0
	local prev = {}
	local phase = 0
	local travel = 0
	for i = 0, n do
		local q = table.clone(p)
		q.Phase = phase
		local pose = Poses.locomotion(i * dt, q)
		-- опорная стопа — самая нижняя; следим за её нижним углом (тело движется вперёд, -Z)
		local support, low, index, all
		for name, legCF in legFrames(pose) do
			local l, i = lowest(legCF)
			if not low or l.Y < low.Y then
				support, low, index, all = name, l, i, corners(legCF)
			end
		end
		local shift = Vector3.new(0, 0, -travel)
		local last = prev[support]
		if last and prev.Index == index and low.Y < 0.06 then
			-- тот же угол той же стопы: насколько он сдвинулся по земле
			local a, b = last[index] + prev.Shift, all[index] + shift
			slide += Vector3.new(b.X - a.X, 0, b.Z - a.Z).Magnitude
			contactTime += dt
		end
		prev = { [support] = all, Index = index, Shift = shift }
		minY = math.min(minY, low.Y)
		maxDip = math.max(maxDip, low.Y)
		phase += Poses.stepRate(speed, p.Crouching, q) * dt
		travel += speed / (p.Scale or 1) * dt -- ноги в тесте масштаба 1
	end
	local slideSpeed = contactTime > 0 and slide / contactTime or 0
	return {
		MinY = minY, -- насколько стопа уходит под землю (отрицательно)
		MaxLow = maxDip, -- максимальная высота самой низкой стопы (полёт)
		Slide = slideSpeed / math.max(speed, 1e-3), -- доля скорости, с которой скользит опорная стопа
		StepsPerSec = rate / math.pi,
	}
end

-- Пороги — защита от регрессий для ног R6 без коленей (старая походка v2 скользила на ~100% скорости).
-- { имя, параметры, мин. глубина стопы, макс. «полёт», макс. доля проскальзывания }
local GAITS = {
	{ "walk", { Speed = 10 }, -0.12, 0.1, 0.3 },
	{ "slow walk", { Speed = 4 }, -0.12, 0.1, 0.15 },
	{ "run", { Speed = 16 }, -0.3, 0.25, 0.6 },
	{ "sprint", { Speed = 22 }, -0.4, 0.4, 0.7 },
	{ "injured walk", { Speed = 10, Injured = true }, -0.25, 0.15, 0.4 },
	{ "injured run", { Speed = 16, Injured = true }, -0.5, 0.25, 0.5 },
	{ "killer walk", { Speed = 6, Killer = true }, -0.15, 0.1, 0.5 },
	{ "killer stride", { Speed = 18.4, Killer = true, Scale = 1.15 }, -0.25, 0.2, 0.5 },
	{ "killer carry", { Speed = 16.4, Killer = true, Carrying = true, Scale = 1.15 }, -0.25, 0.2, 0.5 },
}
for _, g in GAITS do
	local p = { Phase = 0, LookYaw = 0, Seed = 0.4, Breath = 0 }
	for k, v in g[2] do
		p[k] = v
	end
	local m = gaitMetrics(p)
	if REPORT then
		print(("%-14s steps/s %.2f  minY %.3f  maxLow %.3f  slide %.2f"):format(g[1], m.StepsPerSec, m.MinY, m.MaxLow, m.Slide))
	end
	check(m.MinY > g[3], ("%s: feet sink too deep (%.2f)"):format(g[1], m.MinY))
	check(m.MaxLow < g[4], ("%s: body floats above ground (%.2f)"):format(g[1], m.MaxLow))
	check(m.Slide < g[5], ("%s: stance foot slides (%.0f%% of speed)"):format(g[1], m.Slide * 100))
end
do
	-- стояние: обе стопы на земле
	for _, flags in { {}, { Injured = true }, { Killer = true }, { Killer = true, Carrying = true } } do
		local p = { Speed = 0, Phase = 0, LookYaw = 0, Seed = 0.7, Breath = 1 }
		for k, v in flags do
			p[k] = v
		end
		for _, t in { 0, 1.3, 4.1, 9.7 } do
			for name, legCF in legFrames(Poses.locomotion(t, p)) do
				local y = lowest(legCF).Y
				check(y > -0.1 and y < 0.1, ("idle foot %s on ground (%.2f)"):format(name, y))
			end
		end
	end
	-- шаг тем чаще, чем быстрее; на месте — ноль
	check(Poses.stepRate(0, false) == 0, "stepRate 0 at rest")
	local last = 0
	for v = 1, 24 do
		local r = Poses.stepRate(v, false, { Speed = v, Phase = 0 })
		check(r > last or (v > 22 and r >= last), ("stepRate grows with speed (v=%d)"):format(v))
		last = r
	end
end

------------------------------------------------------------------------
-- 5. Все позы дают конечные числа
------------------------------------------------------------------------

local function checkPose(label, pose)
	for key, value in pose do
		if key == "RootPos" then
			check(finiteV(value), label .. " RootPos finite")
		else
			check(joints[key] ~= nil, label .. " unknown joint " .. tostring(key))
			if joints[key] then
				check(finite(Rig.transform(joints[key], value, nil)), label .. " " .. key .. " finite")
			end
		end
	end
end
local params = { Speed = 12, Phase = 1.3, Injured = true, Wiggle = 0.5, Struggle = true, LookYaw = 20 }
local n = 0
for _, t in { 0, 0.37, 2.5 } do
	for _, killer in { false, true } do
		params.Killer = killer
		params.Carrying = killer
		params.Crouching = not killer
		checkPose("locomotion", Poses.locomotion(t, params))
		params.Crouching = false
		params.Speed = 0
		checkPose("locomotion idle", Poses.locomotion(t, params))
		params.Speed = 12
		n += 2
	end
	for name, fn in Poses.State do
		checkPose("state " .. name, fn(t, params))
		n += 1
	end
	for name, fn in Poses.Action do
		checkPose("action " .. name, fn(t, params))
		n += 1
	end
end
for name, shot in Poses.OneShot do
	check(shot.Duration > 0, name .. " duration")
	for _, a in { 0, 0.25, 0.5, 0.99 } do
		checkPose("oneshot " .. name, shot.Fn(a, params))
		n += 1
	end
	if shot.Tracks then
		for _, issue in Clip.check(shot) do
			check(false, "oneshot " .. name .. ": " .. issue)
		end
	end
end

------------------------------------------------------------------------
-- 6. Одноразовые анимации и действия: без рывков, от базовой позы к базовой, длительности = сервер
------------------------------------------------------------------------

do
	local Config = req(game.ReplicatedStorage.Shared.Config)
	local KillerDefs = req(game.ReplicatedStorage.Shared.KillerDefs)
	local OneShot = Poses.OneShot
	-- все имена, которые шлёт сервер (+ варианты, которые выбирает Animator)
	for _, name in { "Swing", "Wipe", "Stun", "Blind", "Pickup", "Vault", "VaultWalk", "KillerVault", "PalletDrop", "Flinch", "Windup", "Throw", "Bell", "BellUncloak", "HookScream", "Entity" } do
		check(OneShot[name] ~= nil, "oneshot exists: " .. name)
	end
	local function dur(name, want)
		check(OneShot[name] and near(OneShot[name].Duration, want, 1e-6), ("%s duration %.2f = server %.2f"):format(name, OneShot[name] and OneShot[name].Duration or -1, want))
	end
	dur("Stun", Config.PalletStunTime)
	dur("Blind", Config.BlindDuration)
	dur("Vault", 0.55) -- Obstacles: с бега
	dur("VaultWalk", 0.95) -- шагом
	dur("KillerVault", 1.6)
	dur("Swing", 0.7)
	dur("Bell", KillerDefs.Wraith.CloakTime)
	dur("BellUncloak", KillerDefs.Wraith.UncloakTime)
	check(OneShot.Swing.Duration >= Config.KillerLungeTime and OneShot.Wipe.Duration <= Config.AttackCooldownHit, "swing/wipe fit lunge and hit cooldown")
	check(OneShot.Windup.Duration >= 10, "windup is held while charging")
	check(Poses.shotVariant("Vault", false, nil) == "VaultWalk" and Poses.shotVariant("Vault", true, nil) == "Vault", "vault variant by running")
	check(Poses.shotVariant("Bell", false, "Uncloaking") == "BellUncloak" and Poses.shotVariant("Bell", false, "Cloaking") == "Bell", "bell variant by power state")
	check(Poses.shotVariant("Swing", false, nil) == "Swing", "other shots keep their name")

	local KEYS = { "Root", "Neck", "LArm", "RArm", "LLeg", "RLeg" }
	-- наибольшее отличие двух поз: (угол в градусах, сдвиг корпуса)
	local function diff(a, b)
		local worst = 0
		for _, k in KEYS do
			worst = math.max(worst, math.deg(angleBetween(a[k] or CFrame.identity, b[k] or CFrame.identity)))
		end
		local d = ((a.RootPos or Vector3.zero) - (b.RootPos or Vector3.zero)).Magnitude
		return worst, d
	end
	local function layered(base, shot, e, p)
		local pose = Clip.copy(base, {})
		Poses.applyShot(pose, shot, e, p)
		return pose
	end
	local function idleBase(killer)
		local p = { Speed = 0, Phase = 0, LookYaw = 0, Seed = 0.4, Breath = 0.3, Killer = killer }
		return Clip.copy(Poses.locomotion(1, p), {}), p
	end
	local function runBase()
		local p = { Speed = 16, Phase = 2.1, LookYaw = 0, Seed = 0.4, Breath = 0.3 }
		return Clip.copy(Poses.locomotion(1, p), {}), p
	end
	for name, shot in OneShot do
		if shot.Tracks then
			for _, issue in Clip.check(shot) do
				check(false, "oneshot " .. name .. ": " .. issue)
			end
		end
		-- конечные значения по всей длине
		for i = 0, 40 do
			checkPose("oneshot sample " .. name, shot.Fn(i / 40, params))
		end
		local bases = { { idleBase(false) }, { idleBase(true) }, { runBase() } }
		if name == "HookScream" or name == "Entity" then
			local p = { Speed = 0, Phase = 0, Seed = 0.4, Breath = 0.3, Struggle = name == "Entity" }
			bases = { { Clip.copy(Poses.State.Hooked(1, p), {}), p } }
		end
		for _, b in bases do
			local base, p = b[1], b[2]
			local d = math.min(shot.Duration, 3)
			-- начало и конец — базовая поза (или поза клипа, за которым этот идёт)
			local a0, p0 = diff(layered(base, shot, 0, p), base)
			if shot.Follows then
				local prev = OneShot[shot.Follows]
				local best = math.huge
				for i = 0, 60 do
					local x = diff(shot.Fn(0, p), prev.Fn(i / 60, p))
					best = math.min(best, x)
				end
				check(best < 8, ("%s starts from a %s pose (%.1f°)"):format(name, shot.Follows, best))
			else
				check(a0 < 2 and p0 < 0.02, ("%s starts at base pose (%.1f°, %.2f)"):format(name, a0, p0))
			end
			local a1, p1 = diff(layered(base, shot, shot.Duration, p), base)
			check(a1 < 2 and p1 < 0.02, ("%s ends at base pose (%.1f°, %.2f)"):format(name, a1, p1))
			-- без рывков: разрыв остаётся разрывом при любой частоте, а быстрое движение за 1/240 с мало
			local prev = layered(base, shot, 0, p)
			local worst, at = 0, 0
			for i = 1, math.ceil(d * 240) do
				local cur = layered(base, shot, i / 240, p)
				local x = diff(cur, prev)
				if x > worst then
					worst, at = x, i / 240
				end
				prev = cur
			end
			check(worst < 20, ("%s jumps %.0f° in 1/240 s at t=%.2f"):format(name, worst, at))
			n += 1
		end
	end

	-- действия: конечны 10 с, клипы проходят Clip.check, зацикленные — без скачка на стыке
	local Actions = req(Anim.Actions)
	for _, name in { "Repair", "Heal", "Cleanse", "OpenChest", "FreeTrap", "DisarmTrap", "Unhook", "OpenGate", "SelfHeal", "EscapeTrap", "Hook", "Break", "Kick", "SearchLocker", "SetTrap", "PickupTrap", "ResetTrap", "CloseHatch" } do
		check(Poses.Action[name] ~= nil, "action exists: " .. name)
	end
	for name, fn in Poses.Action do
		local clip = Actions.Clips[name]
		if clip then
			for _, issue in Clip.check(clip) do
				check(false, "action " .. name .. ": " .. issue)
			end
		end
		local prev = Clip.copy(fn(0, params), {})
		local worst = 0
		for i = 1, 600 do
			local pose = fn(i / 60, params)
			checkPose("action 10s " .. name, pose)
			worst = math.max(worst, (diff(pose, prev)))
			Clip.copy(pose, prev)
		end
		check(worst < 30, ("action %s jumps %.0f° in one frame"):format(name, worst))
		n += 1
	end
end

-- Походка при множестве сочетаний параметров
local rngState = 7
local rng = {}
function rng:NextNumber(a, b)
	rngState = (rngState * 48271) % 2147483647
	local u = rngState / 2147483647
	return (a or 0) + ((b or 1) - (a or 0)) * u
end
local flagsList = {
	{},
	{ Injured = true },
	{ Crouching = true },
	{ Killer = true },
	{ Killer = true, Carrying = true },
	{ Killer = true, KillerType = "Wraith" },
}
for _, flags in flagsList do
	for _ = 1, 60 do
		local p = {
			Speed = rng:NextNumber(0, 30),
			Phase = rng:NextNumber(-50, 500),
			LookYaw = rng:NextNumber(-70, 70),
			Scale = rng:NextNumber(0.8, 1.3),
			Forward = rng:NextNumber(-1, 1),
			Strafe = rng:NextNumber(-1, 1),
			AccelForward = rng:NextNumber(-200, 200),
			AccelSide = rng:NextNumber(-200, 200),
			TurnRate = rng:NextNumber(-12, 12),
			Exertion = rng:NextNumber(0, 1),
			Breath = rng:NextNumber(0, 400),
			Seed = rng:NextNumber(0, 1),
			Wiggle = rng:NextNumber(0, 1),
		}
		for k, v in flags do
			p[k] = v
		end
		local t = rng:NextNumber(0, 1000)
		checkPose("locomotion random", Poses.locomotion(t, p))
		local r = Poses.stepRate(p.Speed, p.Crouching, p)
		check(r == r and r >= 0 and r < 60, "stepRate finite")
		for name, fn in Poses.State do
			p.Struggle = rng:NextNumber() > 0.5
			checkPose("state random " .. name, fn(t, p))
		end
		n += 1
	end
end
-- Поворот без движения и «пустые» параметры
checkPose("locomotion minimal", Poses.locomotion(0, { Speed = 0, Phase = 0 }))
checkPose("locomotion zero dir", Poses.locomotion(0, { Speed = 5, Phase = 1, Forward = 0, Strafe = 0 }))
check(Gait.reachOf(0) == 2, "leg reach at rest")

print(("checked %d poses"):format(n))
if failures > 0 then
	print(("%d checks failed"):format(failures))
	process.exit(1)
end
print("anim tests OK")
