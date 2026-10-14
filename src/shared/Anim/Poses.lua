-- Процедурные позы R6. Каждая поза — функция, возвращающая таблицу поворотов суставов:
--   Root (поворот торса вокруг HumanoidRootPart), RootPos (сдвиг торса в стадах),
--   Neck, LArm, RArm, LLeg, RLeg.
-- Углы в градусах: +X — вперёд (руку поднять перед собой), +Y — влево, +Z — вправо.
-- Корпус наклоняется вперёд ОТРИЦАТЕЛЬНЫМ X. Не указанные суставы берутся из базовой позы.
--   Poses.locomotion / Poses.stepRate — походка (Anim/Gait.lua)
--   Poses.State.*  — особые состояния (Anim/States.lua)
--   Poses.Action.* — зацикленные действия, пока игрок держит кнопку: (t, p) -> поза
--   Poses.OneShot.* — одноразовые: { Duration, Fn(a, p) -> поза } или клип Anim/Clip.lua
--     (необязательно: FadeIn, FadeOut, Additive, Stiffness — как у клипа)
local Rig = require(script.Parent.Rig)
local Gait = require(script.Parent.Gait)
local States = require(script.Parent.States)

local Poses = {}

local sin, abs, clamp = math.sin, math.abs, math.clamp

local A = Rig.A
Poses.A = A

local V = Vector3.new

export type Params = Gait.Params

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function smooth(t: number): number
	t = clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- Колено на одну ногу: опускаем торс на 1 стад и разводим ноги так,
-- чтобы прямые ноги R6 не уходили в землю.
local function kneel(lean: number)
	return {
		Root = A(-lean),
		RootPos = V(0, -1.05, 0),
		LLeg = A(85 - lean * 0.2),
		RLeg = A(-35 + lean * 0.2, 0, 4),
	}
end

local function merge(base, over)
	local out = table.clone(base)
	for k, v in over do
		out[k] = v
	end
	return out
end
Poses.merge = merge

Poses.stepRate = Gait.stepRate
Poses.locomotion = Gait.locomotion
Poses.State = States

------------------------------------------------------------------------
-- Действия (зацикленные, пока игрок держит кнопку)
------------------------------------------------------------------------

Poses.Action = {}

local function handsWork(t: number, speed: number, base: number, amp: number)
	return A(base + sin(t * speed) * amp, 0, -6), A(base + sin(t * speed + 2.2) * amp, 0, 6)
end

function Poses.Action.Repair(t: number)
	local la, ra = handsWork(t, 9, 72, 14)
	return merge(kneel(18), { LArm = la, RArm = ra, Neck = A(-18, sin(t * 0.8) * 6, 0) })
end

function Poses.Action.Heal(t: number)
	local la, ra = handsWork(t, 4, 62, 7)
	return merge(kneel(20), { LArm = la, RArm = ra, Neck = A(-25, 0, 0) })
end

function Poses.Action.Cleanse(t: number)
	local la, ra = handsWork(t, 5, 55, 12)
	return merge(kneel(25), { LArm = la, RArm = ra, Neck = A(-25, 0, 0) })
end

function Poses.Action.OpenChest(t: number)
	local la, ra = handsWork(t, 7, 70, 12)
	return merge(kneel(20), { LArm = la, RArm = ra, Neck = A(-20, 0, 0) })
end

Poses.Action.FreeTrap = function(t: number)
	local la, ra = handsWork(t, 6, 45, 15)
	return merge(kneel(30), { LArm = la, RArm = ra, Neck = A(-30, 0, 0) })
end
Poses.Action.DisarmTrap = Poses.Action.FreeTrap

function Poses.Action.Unhook(t: number)
	return {
		Root = A(4),
		LArm = A(158 + sin(t * 8) * 6, 0, -12),
		RArm = A(158 - sin(t * 8) * 6, 0, 12),
		Neck = A(28, 0, 0),
	}
end

function Poses.Action.OpenGate(t: number)
	return {
		Root = A(-6),
		RArm = A(88 + sin(t * 1.4) * 5, 0, -6),
		LArm = A(30, 0, -10),
		Neck = A(-5, 0, 0),
	}
end

function Poses.Action.SelfHeal(t: number)
	return {
		Root = A(-12),
		LArm = A(55 + sin(t * 3) * 6, 0, 32),
		RArm = A(55 - sin(t * 3) * 6, 0, -32),
		Neck = A(-28, 0, 0),
	}
end

function Poses.Action.EscapeTrap(t: number, p: Params)
	local pose = Poses.State.Trapped(t * 2, p)
	pose.LArm = A(40 + sin(t * 10) * 20, 0, 10)
	pose.RArm = A(40 - sin(t * 10) * 20, 0, -10)
	return pose
end

-- Маньяк
function Poses.Action.Hook(t: number)
	return {
		Root = A(6),
		LArm = A(170 + sin(t * 5) * 4, 0, -8),
		RArm = A(170 - sin(t * 5) * 4, 0, 8),
		Neck = A(20, 0, 0),
	}
end

function Poses.Action.Break(t: number)
	local stomp = math.max(0, sin(t * 6))
	return {
		Root = A(-8 + stomp * 4),
		RLeg = A(stomp * 75),
		LArm = A(20, 0, -20),
		RArm = A(25, 0, 25),
		Neck = A(-25, 0, 0),
	}
end

function Poses.Action.Kick(t: number)
	local k = sin(t * 5)
	return {
		Root = A(6 * k),
		RLeg = A(25 + k * 55),
		LArm = A(-10 - k * 20, 0, -15),
		RArm = A(20 + k * 20, 0, 15),
		Neck = A(-20, 0, 0),
	}
end

function Poses.Action.SearchLocker(t: number)
	return {
		Root = A(-10),
		LArm = A(95 + sin(t * 8) * 6, 0, -10),
		RArm = A(95 - sin(t * 8) * 6, 0, 10),
		Neck = A(-5, 0, 0),
	}
end

function Poses.Action.SetTrap(t: number)
	local la, ra = handsWork(t, 6, 40, 12)
	return merge(kneel(35), { LArm = la, RArm = ra, Neck = A(-30, 0, 0) })
end
Poses.Action.PickupTrap = Poses.Action.SetTrap
Poses.Action.ResetTrap = Poses.Action.SetTrap
Poses.Action.CloseHatch = Poses.Action.SetTrap

------------------------------------------------------------------------
-- Одноразовые анимации: Duration и функция от прогресса a (0..1)
------------------------------------------------------------------------

Poses.OneShot = {}

Poses.OneShot.Swing = {
	Duration = 0.7,
	Fn = function(a: number)
		local arm
		if a < 0.35 then
			arm = lerp(30, 175, smooth(a / 0.35))
		elseif a < 0.55 then
			arm = lerp(175, 15, smooth((a - 0.35) / 0.2))
		else
			arm = lerp(15, 30, smooth((a - 0.55) / 0.45))
		end
		local strike = a > 0.35 and a < 0.75 and 1 or 0
		return {
			Root = A(-12 * strike, (a < 0.35 and 12 or -10), 0),
			RArm = A(arm, 0, 12),
			LArm = A(30 - strike * 20, 0, -18),
		}
	end,
}

Poses.OneShot.Wipe = {
	Duration = 2.4,
	Fn = function(a: number)
		local rub = sin(a * 24) * 18
		return {
			Root = A(-8),
			RArm = A(70, 0, -35),
			LArm = A(65, 0, 30 + rub),
			Neck = A(-25, 0, 0),
		}
	end,
}

Poses.OneShot.Stun = {
	Duration = 2.2,
	Fn = function(a: number)
		local wob = sin(a * 30) * (1 - a) * 6
		return {
			Root = A(14, wob, wob),
			LArm = A(140, 0, -25),
			RArm = A(140, 0, 25),
			Neck = A(28, 0, 0),
		}
	end,
}

Poses.OneShot.Blind = {
	Duration = 2.5,
	Fn = function(a: number)
		return {
			Root = A(8, sin(a * 18) * 8, 0),
			LArm = A(150, 0, 38),
			RArm = A(150, 0, -38),
			Neck = A(-15, 0, 0),
		}
	end,
}

Poses.OneShot.Pickup = {
	Duration = 0.8,
	Fn = function(a: number)
		local b = sin(a * math.pi)
		return {
			Root = A(-55 * b),
			RootPos = V(0, -0.5 * b, 0),
			LLeg = A(55 * b),
			RLeg = A(50 * b),
			LArm = A(80 * b, 0, -10),
			RArm = A(80 * b, 0, 10),
		}
	end,
}

Poses.OneShot.Vault = {
	Duration = 0.7,
	Fn = function(a: number)
		local b = sin(a * math.pi)
		return {
			Root = A(-50 * b),
			LArm = A(60 + 110 * b, 0, -10),
			RArm = A(60 + 110 * b, 0, 10),
			LLeg = A(-30 * b),
			RLeg = A(-50 * b),
			Neck = A(30 * b, 0, 0),
		}
	end,
}

Poses.OneShot.KillerVault = {
	Duration = 1.6,
	Fn = function(a: number)
		local b = sin(a * math.pi)
		return {
			Root = A(-30 * b),
			RLeg = A(95 * b),
			LLeg = A(-10 * b),
			LArm = A(70 * b, 0, -15),
			RArm = A(70 * b, 0, 15),
		}
	end,
}

Poses.OneShot.PalletDrop = {
	Duration = 0.6,
	Fn = function(a: number)
		local push = a < 0.4 and smooth(a / 0.4) or 1
		return {
			Root = A(-15 * push),
			LArm = A(lerp(60, 110, push), 0, -10),
			RArm = A(lerp(60, 110, push), 0, 10),
		}
	end,
}

Poses.OneShot.Flinch = {
	Duration = 0.45,
	Fn = function(a: number)
		local b = sin(a * math.pi)
		return {
			Root = A(14 * b, 0, 6 * b),
			LArm = A(50 * b, 0, -30 * b),
			RArm = A(50 * b, 0, 30 * b),
			Neck = A(20 * b, 0, 0),
		}
	end,
}

Poses.OneShot.Windup = {
	Duration = 30, -- держится, пока сервер не отправит Throw
	Fn = function(a: number)
		return {
			Root = A(4, -12, 0),
			RArm = A(200 + sin(a * 60) * 3, 0, 18),
			LArm = A(60, 0, -20),
		}
	end,
}

Poses.OneShot.Throw = {
	Duration = 0.45,
	Fn = function(a: number)
		return {
			Root = A(-15 * sin(a * math.pi), lerp(-12, 15, smooth(a * 2)), 0),
			RArm = A(lerp(200, 40, smooth(a * 2.5)), 0, 10),
			LArm = A(40, 0, -20),
		}
	end,
}

Poses.OneShot.Bell = {
	Duration = 1.5,
	Fn = function(a: number)
		local hit = abs(sin(a * 18))
		return {
			LArm = A(80, 0, -15),
			RArm = A(70 + hit * 15, 0, 35),
			Neck = A(-15, 0, 0),
		}
	end,
}

Poses.OneShot.HookScream = {
	Duration = 1.4,
	Fn = function(a: number)
		local b = sin(a * math.pi)
		return {
			LArm = A(150 * b, 0, -20),
			RArm = A(150, 0, 20),
			Neck = A(40 * b, 0, 0),
			Root = A(10 * b),
		}
	end,
}

Poses.OneShot.Entity = {
	Duration = 2,
	Fn = function(a: number)
		local f = sin(a * 40)
		return {
			Root = A(25 * a, f * 10, 0),
			LArm = A(170 + f * 10, 0, -30),
			RArm = A(170 - f * 10, 0, 30),
			LLeg = A(40 * a + f * 20),
			RLeg = A(40 * a - f * 20),
			Neck = A(50, 0, 0),
		}
	end,
}

return Poses
