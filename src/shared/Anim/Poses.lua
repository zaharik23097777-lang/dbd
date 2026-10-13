-- Процедурные позы R6. Каждая поза — функция, возвращающая таблицу поворотов суставов:
--   Root (поворот торса вокруг HumanoidRootPart), RootPos (сдвиг торса в стадах),
--   Neck, LArm, RArm, LLeg, RLeg.
-- Углы в градусах: +X — вперёд (руку поднять перед собой), +Y — влево, +Z — вправо.
-- Корпус наклоняется вперёд ОТРИЦАТЕЛЬНЫМ X. Не указанные суставы берутся из базовой позы.
local Poses = {}

local sin, cos, abs, clamp, rad = math.sin, math.cos, math.abs, math.clamp, math.rad

local function A(x: number, y: number?, z: number?): CFrame
	return CFrame.Angles(rad(x), rad(y or 0), rad(z or 0))
end
Poses.A = A

local V = Vector3.new

export type Params = {
	Speed: number, -- скорость по земле
	Phase: number, -- фаза шага (радианы)
	Injured: boolean?,
	Crouching: boolean?,
	Killer: boolean?,
	Carrying: boolean?,
	Wiggle: number?,
	Struggle: boolean?,
	LookYaw: number?, -- поворот головы к маньяку (градусы)
	KillerType: string?,
}

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

------------------------------------------------------------------------
-- Передвижение
------------------------------------------------------------------------

-- Скорость изменения фазы шага (рад/с) для данной скорости
function Poses.stepRate(speed: number, crouching: boolean?): number
	if speed < 0.5 then
		return 0
	end
	local rate = clamp(speed, 0, 30) * 0.55 + 2
	if crouching then
		rate *= 1.4
	end
	return rate
end

function Poses.locomotion(t: number, p: Params)
	local s = p.Speed
	local ph = p.Phase
	local moving = s > 0.6
	local look = p.LookYaw or 0

	if p.Crouching then
		local sw = moving and sin(ph) * 18 or 0
		return {
			Root = A(-28),
			RootPos = V(0, -1.05, 0),
			LLeg = A(85 + sw),
			RLeg = A(-35 - sw * 0.6, 0, 4),
			LArm = A(35 - sw, 0, -8),
			RArm = A(35 + sw, 0, 8),
			Neck = A(18, look, 0),
		}
	end

	local amp = clamp(s * 3.2, 0, 58)
	local pose
	if moving then
		local swing = sin(ph) * amp
		local lean = -clamp(s, 0, 22) * 0.55
		local bob = -abs(cos(ph)) * 0.12 * clamp(s / 16, 0, 1.4)
		pose = {
			Root = A(lean, sin(ph) * 4, 0),
			RootPos = V(0, bob, 0),
			LLeg = A(swing),
			RLeg = A(-swing),
			LArm = A(-swing * 0.85, 0, -4),
			RArm = A(swing * 0.85, 0, 4),
			Neck = A(-lean * 0.6, look, 0),
		}
	else
		local breath = sin(t * 2.2)
		pose = {
			Root = A(breath * 1.2),
			RootPos = V(0, breath * 0.03, 0),
			LLeg = A(2, 0, -2),
			RLeg = A(-2, 0, 2),
			LArm = A(breath * 2, 0, -4 - breath),
			RArm = A(breath * 2, 0, 4 + breath),
			Neck = A(sin(t * 0.7) * 3, look + sin(t * 0.37) * 10, 0),
		}
	end

	if p.Injured then
		-- держится за бок, хромает, сутулится
		local limp = moving and sin(ph) * amp or 0
		pose.Root = pose.Root * A(-10, 0, moving and sin(ph) * 5 or 3)
		pose.LArm = A(45 + sin(t * 3) * 3, 0, 32)
		pose.RLeg = A(-limp * 0.45)
		pose.Neck = A(-12 + sin(t * 3.5) * 2, look, 0)
	end

	if p.Killer then
		-- тяжёлая походка, оружие в правой руке
		if moving then
			pose.Root = pose.Root * A(-4)
			pose.RArm = A(25 + sin(ph) * amp * 0.25, 0, 10)
		else
			local b = sin(t * 1.4)
			pose.Root = A(-6 + b * 2)
			pose.RootPos = V(0, b * 0.05, 0)
			pose.RArm = A(18 + b * 3, 0, 12)
			pose.LArm = A(6 + b * 2, 0, -10)
			pose.Neck = A(-10 + b * 3, sin(t * 0.5) * 18, 0)
		end
		if p.Carrying then
			pose.RArm = A(168, 0, 6)
		end
		if p.KillerType == "Wraith" and not p.Carrying then
			pose.LArm = A(55 + sin(t * 2) * 4, 0, -12) -- держит колокол
		end
	end
	return pose
end

------------------------------------------------------------------------
-- Особые состояния (выжившие)
------------------------------------------------------------------------

Poses.State = {}

-- Повержен: ползёт на животе
function Poses.State.Crawl(t: number, p: Params)
	local s = p.Speed
	local ph = s > 0.3 and p.Phase or t * 1.5
	local reach = sin(ph) * (s > 0.3 and 28 or 10)
	return {
		Root = A(-84, 0, sin(ph) * 6),
		RootPos = V(0, -2.4, -0.3),
		LArm = A(150 + reach, 0, -12),
		RArm = A(150 - reach, 0, 12),
		LLeg = A(-4 + sin(ph) * 6),
		RLeg = A(-4 - sin(ph) * 6),
		Neck = A(65, sin(t * 0.8) * 10, 0),
	}
end

-- На плече у маньяка (тело лежит животом вниз, голова за спиной маньяка)
function Poses.State.Carried(t: number, p: Params)
	local w = p.Wiggle or 0
	local k = 0.4 + w * 1.6
	return {
		Root = A(0),
		LArm = A(85 + sin(t * 2.5) * 10 * k, 0, -8),
		RArm = A(85 + sin(t * 2.5 + 1) * 10 * k, 0, 8),
		LLeg = A(80 + sin(t * 9) * 22 * k),
		RLeg = A(80 - sin(t * 9) * 22 * k),
		Neck = A(-25 + sin(t * 3) * 8 * k, sin(t * 4) * 20 * k, 0),
	}
end

-- Висит на крюке
function Poses.State.Hooked(t: number, p: Params)
	if p.Struggle then
		local f = sin(t * 7)
		return {
			Root = A(6, sin(t * 3) * 6, f * 4),
			LArm = A(160 + f * 18, 0, -15),
			RArm = A(160 - f * 18, 0, 15),
			LLeg = A(25 + sin(t * 9) * 25),
			RLeg = A(25 - sin(t * 9) * 25),
			Neck = A(30 + f * 5, 0, 0),
		}
	end
	local sway = sin(t * 1.1)
	return {
		Root = A(-8 + sway * 2, sway * 3, 10),
		LArm = A(8 + sway * 4, 0, -6),
		RArm = A(150, 0, 18), -- рука на крюке
		LLeg = A(6 + sway * 5),
		RLeg = A(-4 + sway * 5),
		Neck = A(-28, sin(t * 0.6) * 12, 8),
	}
end

-- В шкафчике: быстро и испуганно дышит
function Poses.State.Hidden(t: number, _p: Params)
	local b = sin(t * 7)
	return {
		Root = A(-4 + b * 1.5),
		RootPos = V(0, b * 0.03, 0),
		LArm = A(20, 0, 25),
		RArm = A(20, 0, -25),
		LLeg = A(0),
		RLeg = A(0),
		Neck = A(-5 + b * 2, sin(t * 0.9) * 15, 0),
	}
end

-- Нога в капкане
function Poses.State.Trapped(t: number, _p: Params)
	local pull = sin(t * 4)
	return {
		Root = A(-30 + pull * 6, 0, -6),
		RootPos = V(0, -0.5, 0),
		LLeg = A(45, 0, -6),
		RLeg = A(-30 + pull * 4),
		LArm = A(55 + pull * 15, 0, 10),
		RArm = A(55 - pull * 15, 0, -10),
		Neck = A(-35, 0, 0),
	}
end

-- Сидит у костра
function Poses.State.Sit(t: number, _p: Params)
	local b = sin(t * 1.8)
	return {
		Root = A(-6 + b),
		LLeg = A(90, 0, -4),
		RLeg = A(90, 0, 4),
		LArm = A(40, 0, 18),
		RArm = A(40, 0, -18),
		Neck = A(-8 + b * 2, sin(t * 0.4) * 20, 0),
	}
end

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
