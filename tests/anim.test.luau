-- Проверяет математику суставов на настоящих C0/C1 персонажа R6 и все позы.
local Harness = require("./harness")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3

local game, req = Harness.load(process.args[1] or "DeadByDaylight.rbxlx")
local Rig = req(game.ReplicatedStorage.Shared.Anim.Rig)
local Poses = req(game.ReplicatedStorage.Shared.Anim.Poses)

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

-- 1. Нулевая поза -> единичный Transform
for name, j in joints do
	local t = Rig.transform(j, CFrame.new())
	local p = t.Position
	local rx, ry, rz = t:ToEulerAnglesXYZ()
	check(p.Magnitude < 1e-4 and near(rx, 0) and near(ry, 0) and near(rz, 0), "rest identity " .. name)
end

-- 2. Рука вперёд на 90°: рука направлена вперёд (-Z торса)
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

-- 3. Правая рука +Z отводится вправо
do
	local j = joints.RArm
	local rel = part1(j, Rig.transform(j, Poses.A(0, 0, 90)))
	check(-rel.UpVector.X > 0.99, "RArm +Z abducts to the right")
end

-- 4. Наклон корпуса вперёд отрицательным X
do
	local j = joints.Root
	local rel = part1(j, Rig.transform(j, Poses.A(-30)))
	check(rel.UpVector.Z < -0.4, "Root -X leans forward")
	local moved = part1(j, Rig.transform(j, CFrame.new(), Vector3.new(0, -2, 0)))
	check(near(moved.Position.Y, -2), "RootPos moves torso down")
end

-- 5. Голова +X смотрит вверх, +Y поворачивает влево
do
	local j = joints.Neck
	local rel = part1(j, Rig.transform(j, Poses.A(30)))
	check(rel.LookVector.Y > 0.4, "Neck +X looks up")
	rel = part1(j, Rig.transform(j, Poses.A(0, 40, 0)))
	check(rel.LookVector.X < -0.5, "Neck +Y turns left")
end

-- 6. Все позы дают конечные числа
local function finite(c)
	local comps = { c:GetComponents() }
	for _, v in comps do
		if v ~= v or v == math.huge or v == -math.huge then
			return false
		end
	end
	return true
end
local function checkPose(label, pose)
	for key, value in pose do
		if key == "RootPos" then
			check(value.X == value.X and value.Y == value.Y, label .. " RootPos finite")
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
end
print(("checked %d poses"):format(n))
if failures > 0 then
	print(("%d checks failed"):format(failures))
	process.exit(1)
end
print("anim tests OK")
