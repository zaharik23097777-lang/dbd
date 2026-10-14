-- Привод суставов персонажа: поза -> пружины (Anim/Spring.lua) -> Motor6D.Transform.
-- Один на персонажа. Используется Animator'ом на клиенте и превью (tools/preview).
local Rig = require(script.Parent.Rig)
local Spring = require(script.Parent.Spring)

local Driver = {}

export type Driver = {
	Rig: Rig.RigData,
	Springs: { [string]: Spring.Rot },
	RootPos: Spring.Vec,
}

local ZERO = Vector3.zero
local IDENTITY = CFrame.identity

function Driver.new(rig: Rig.RigData): Driver
	local springs = {}
	for _, name in Rig.JointNames do
		springs[name] = Spring.rot(Spring.R6[name])
	end
	return { Rig = rig, Springs = springs, RootPos = Spring.vec(Spring.R6.RootPos) }
end

-- Следующая поза встанет сразу, без пружин (после долгого пропуска обновлений, телепорта)
function Driver.snap(d: Driver)
	for _, s in d.Springs do
		s.Target = nil
	end
	d.RootPos.Target = nil
end

-- Шаг пружин на dt к позе и запись Transform. stiffness — множитель частоты пружин
-- (резкие удары). Возвращает false, если суставы пропали (персонажа пересобрали).
function Driver.apply(d: Driver, pose: { [string]: any }, dt: number, stiffness: number?): boolean
	local rig = d.Rig
	local offset = Spring.stepVec(d.RootPos, pose.RootPos or ZERO, dt, stiffness) * rig.Scale
	for _, name in Rig.JointNames do
		local joint = rig.Joints[name]
		if not joint.Motor.Parent then
			return false
		end
		local rot = Spring.stepRot(d.Springs[name], pose[name] or IDENTITY, dt, stiffness)
		joint.Motor.Transform = Rig.transform(joint, rot, name == "Root" and offset or nil)
	end
	return true
end

return Driver
