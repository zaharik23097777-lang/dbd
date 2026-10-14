-- Математика суставов R6.
-- Позы задаются понятными углами в пространстве родительской детали (Torso или HumanoidRootPart):
--   +X = махнуть конечностью вперёд, +Y = повернуть влево, +Z = отвести вправо.
-- Rig.transform переводит такой поворот (вокруг точки сустава) в Motor6D.Transform,
-- поэтому не нужно помнить странные оси C0/C1 у R6.
local Rig = {}

local rad = math.rad

Rig.JointNames = { "Root", "Neck", "LArm", "RArm", "LLeg", "RLeg" }

local JOINT_PATHS = {
	Root = { "HumanoidRootPart", "RootJoint" },
	Neck = { "Torso", "Neck" },
	LArm = { "Torso", "Left Shoulder" },
	RArm = { "Torso", "Right Shoulder" },
	LLeg = { "Torso", "Left Hip" },
	RLeg = { "Torso", "Right Hip" },
}

export type Joint = {
	Motor: Motor6D,
	C0: CFrame,
	C1: CFrame,
	Rest: CFrame,
	Pivot: Vector3,
}

export type RigData = {
	Joints: { [string]: Joint },
	Scale: number,
}

function Rig.makeJoint(motor: Motor6D, c0: CFrame, c1: CFrame): Joint
	return {
		Motor = motor,
		C0 = c0,
		C1 = c1,
		Rest = c0 * c1:Inverse(),
		Pivot = c0.Position,
	}
end

-- Находит суставы R6 у персонажа. Возвращает nil, если это не R6.
function Rig.find(char: Model): RigData?
	local joints = {}
	for name, path in JOINT_PATHS do
		local part = char:FindFirstChild(path[1])
		local motor = part and part:FindFirstChild(path[2])
		if not motor or not motor:IsA("Motor6D") then
			return nil
		end
		joints[name] = Rig.makeJoint(motor, motor.C0, motor.C1)
	end
	local scale = 1
	local ok, s = pcall(function()
		return char:GetScale()
	end)
	if ok and typeof(s) == "number" then
		scale = s
	end
	return { Joints = joints, Scale = scale }
end

-- Поворот из углов в градусах в соглашении поз: +X — вперёд, +Y — влево, +Z — вправо
function Rig.A(x: number, y: number?, z: number?): CFrame
	return CFrame.Angles(rad(x), rad(y or 0), rad(z or 0))
end

-- Поворот конечности (руки или ноги), при котором она указывает вдоль dir.
-- dir задаётся в пространстве родителя (торса): -Z — вперёд, +X — вправо, -Y — вниз.
-- Это обратная задача к Angles(x, 0, z): конец конечности = (sin z, -cos z·cos x, -cos z·sin x).
function Rig.aim(dir: Vector3): CFrame
	local u = dir.Unit
	return CFrame.Angles(math.atan2(-u.Z, -u.Y), 0, math.asin(math.clamp(u.X, -1, 1)))
end

-- Вектор поворота (ось × угол, рад) кратчайшим путём: угол в [-π, π].
-- ToAxisAngle может вернуть угол до 2π (так в Lune) — приводим.
function Rig.rotVec(cf: CFrame): Vector3
	local axis, angle = cf:ToAxisAngle()
	if angle ~= angle or axis.X ~= axis.X or math.abs(angle) < 1e-7 then
		return Vector3.zero
	end
	if angle > math.pi then
		angle -= 2 * math.pi
	end
	return axis * angle
end

-- rot: поворот вокруг точки сустава; offset: сдвиг в пространстве родителя (в стадах)
function Rig.transform(joint: Joint, rot: CFrame, offset: Vector3?): CFrame
	local pivot = joint.Pivot
	local rel = CFrame.new(pivot + (offset or Vector3.zero)) * rot * CFrame.new(-pivot) * joint.Rest
	return joint.C0:Inverse() * rel * joint.C1
end

return Rig
