-- Действия, пока игрок держит кнопку (Poses.Action): ключевые клипы всего тела.
-- Функция действия (t, p) -> поза, где t — секунды от НАЧАЛА действия (Animator считает его сам
-- и плавно вводит/выводит слой). Зацикленные (Loop) — пока действие длится сколько угодно
-- (ремонт, лечение); с фиксированной длительностью ActionInfo (крюк, пинок, обыск) — один проход,
-- последняя поза держится. Позы — как в Anim/Clips.lua: body{} (корпус вокруг таза, ноги —
-- мировые углы, руки/голова — в пространстве торса). Clip.sample пишет в общую таблицу клипа —
-- без выделения памяти каждый кадр.
local Rig = require(script.Parent.Rig)
local Clip = require(script.Parent.Clip)
local Clips = require(script.Parent.Clips)

local Actions = {}

local A = Rig.A
local V = Vector3.new
local AT, K, body = Clips.AT, Clips.K, Clips.body

local Action = {}
Actions.Action = Action
-- Длина клипа каждого действия (для превью и тестов)
Actions.Length = {} :: { [string]: number }
Actions.Clips = {} :: { [string]: Clip.Clip }

-- Стойка + поза (стойка подставляет таз и ноги, если их нет в позе)
local function on(stance: Clips.Spec, s: Clips.Spec): Clip.Pose
	local spec = table.clone(stance)
	for k, v in s do
		(spec :: any)[k] = v
	end
	return body(spec)
end

-- На правом колене (левая нога впереди) и на левом; таз на высоте ~1 стада
local KNEEL_R: Clips.Spec = { hip = V(0, -1.0, 0), ll = A(60, 0, -6), rl = A(-58, 0, 6) }
local KNEEL_L: Clips.Spec = { hip = V(0, -1.0, 0), ll = A(-58, 0, -6), rl = A(60, 0, 6) }
local STAND: Clips.Spec = { ll = A(0, 0, -3), rl = A(0, 0, 3) }

local function define(names: { string }, def: Clip.Def)
	local clip = Clip.new(def)
	local fn = function(t: number, _p: any?): Clip.Pose
		return Clip.sample(clip, t)
	end
	for _, name in names do
		Action[name] = fn
		Actions.Length[name] = clip.Duration
		Actions.Clips[name] = clip
	end
end

------------------------------------------------------------------------
-- Выживший
------------------------------------------------------------------------

-- Ремонт: на колене, руки копаются в механизме (вразнобой, с поворотом кистей), тянется глубже,
-- дёргает провода на себя, замирает и оглядывается через плечо.
do
	local function k(t, s, e)
		return K(t, on(KNEEL_R, s), e or "SineInOut")
	end
	define({ "Repair" }, {
		Duration = 6.4,
		Loop = true,
		Keys = {
			k(0, { lean = 18, turn = 3, la = AT(80, -6, -10), ra = AT(70, 8, 12), neck = A(-16, 4, 0) }),
			k(0.4, { lean = 17, turn = -2, la = AT(68, -10, 8), ra = AT(84, 4, -14), neck = A(-18, -3, 0) }),
			k(0.8, { lean = 19, turn = 4, la = AT(84, -4, -16), ra = AT(66, 10, 10), neck = A(-15, 6, 0) }),
			k(1.2, { lean = 17, turn = -3, la = AT(70, -12, 6), ra = AT(80, 2, -10), neck = A(-17, -2, 0) }),
			k(1.65, { lean = 24, hip = V(0, -0.98, -0.1), la = AT(92, -2, 0), ra = AT(94, 0, 0), neck = A(-8, 0, 0) }),
			k(1.9, { lean = 10, turn = 2, la = AT(56, -12, 10), ra = AT(60, 12, -10), neck = A(-20, 0, 0) }, "QuadOut"),
			k(2.3, { lean = 17, la = AT(78, -6, -8), ra = AT(72, 6, 8), neck = A(-16, 2, 0) }),
			k(2.65, { lean = 18, turn = -3, la = AT(68, -10, 10), ra = AT(84, 4, -12), neck = A(-17, -4, 0) }),
			k(3.0, { lean = 17, turn = 3, la = AT(82, -4, -12), ra = AT(68, 8, 12), neck = A(-15, 5, 0) }),
			k(3.4, { lean = 15, la = AT(76, -6, 0), ra = AT(76, 6, 0), neck = A(-12, 0, 0) }),
			k(3.8, { lean = 11, turn = 12, roll = 2, la = AT(74, -6, 0), ra = AT(72, 6, 0), neck = A(-2, 58, 0) }),
			k(4.4, { lean = 11, turn = 10, roll = 2, la = AT(74, -6, 0), ra = AT(72, 6, 0), neck = A(2, 50, -4) }, "Linear"),
			k(4.8, { lean = 17, la = AT(78, -6, -8), ra = AT(70, 8, 10), neck = A(-16, 0, 0) }),
			k(5.2, { lean = 18, turn = -3, la = AT(68, -10, 10), ra = AT(84, 4, -12), neck = A(-17, -4, 0) }),
			k(5.6, { lean = 17, turn = 3, la = AT(84, -4, -14), ra = AT(68, 10, 12), neck = A(-15, 5, 0) }),
			k(6.0, { lean = 18, turn = -1, la = AT(70, -12, 6), ra = AT(80, 2, -10), neck = A(-17, -2, 0) }),
		},
	})
end

-- Лечение другого: на левом колене, ладони на ране — ритмично давит всем корпусом,
-- перевязывает, иногда поднимает глаза.
do
	local function k(t, s, e)
		return K(t, on(KNEEL_L, s), e or "SineInOut")
	end
	local up = { lean = 24, la = AT(58, 8, 0), ra = AT(56, -8, 0), neck = A(-24, 0, 0) }
	local press = { lean = 31, hip = V(0, -1.05, -0.05), la = AT(46, 10, 4), ra = AT(44, -10, -4), neck = A(-26, 0, 0) }
	define({ "Heal" }, {
		Duration = 3.2,
		Loop = true,
		Keys = {
			k(0, up),
			k(0.4, press),
			k(0.8, up),
			k(1.2, press),
			k(1.65, { lean = 22, turn = 6, la = AT(64, -6, -10), ra = AT(50, -16, 8), neck = A(-24, -6, 4) }),
			k(2.05, { lean = 24, turn = 2, la = AT(52, 14, 6), ra = AT(60, -4, -6), neck = A(-22, 4, 0) }),
			k(2.45, press),
			k(2.85, { lean = 20, turn = 4, la = AT(56, 8, 0), ra = AT(54, -8, 0), neck = A(-4, 34, 0) }),
		},
	})
end

-- Очищение тотема: на колене, выдирает кости и отбрасывает в стороны
do
	local function k(t, s, e)
		return K(t, on(KNEEL_R, s), e or "SineInOut")
	end
	local reach = { lean = 32, la = A(55, 0, -4), ra = A(52, 0, 4), neck = A(-22, 0, 0) }
	define({ "Cleanse" }, {
		Duration = 2.4,
		Loop = true,
		Keys = {
			k(0, reach),
			k(0.45, { lean = 22, turn = -12, la = A(50, 0, -8), ra = A(95, 0, 50), neck = A(-14, -14, 0) }, "QuadOut"),
			k(0.8, reach),
			k(1.2, { lean = 30, turn = 6, la = AT(58, -20, -15), ra = AT(58, 20, 15), neck = A(-24, 4, 0) }),
			k(1.6, { lean = 22, turn = 12, la = A(90, 0, -55), ra = A(55, 0, 6), neck = A(-14, 16, 0) }, "QuadOut"),
			k(2.0, { lean = 32, la = A(54, 0, -6), ra = A(52, 0, 6), neck = A(-22, 0, 0) }),
		},
	})
end

-- Сундук (5 с): роется двумя руками по очереди, заглядывает внутрь, откидывает хлам
do
	local function k(t, s, e)
		return K(t, on(KNEEL_L, s), e or "SineInOut")
	end
	define({ "OpenChest" }, {
		Duration = 2.6,
		Loop = true,
		Keys = {
			k(0, { lean = 28, la = AT(62, -4, 10), ra = AT(48, 6, -10), neck = A(-22, 0, 0) }),
			k(0.35, { lean = 30, turn = -4, la = AT(46, -8, -10), ra = AT(66, 2, 12), neck = A(-24, -6, 0) }),
			k(0.7, { lean = 27, turn = 4, la = AT(66, -2, 8), ra = AT(46, 8, -8), neck = A(-20, 6, 0) }),
			k(1.05, { lean = 34, hip = V(0, -0.98, -0.08), la = AT(56, -6, 0), ra = AT(58, 6, 0), neck = A(-14, 0, 0) }),
			k(1.4, { lean = 22, turn = -10, la = A(52, 0, -6), ra = A(100, 0, 55), neck = A(-16, -18, 0) }, "QuadOut"),
			k(1.8, { lean = 30, turn = 2, la = AT(48, -8, -6), ra = AT(64, 4, 10), neck = A(-24, 2, 0) }),
			k(2.2, { lean = 28, turn = -2, la = AT(64, -4, 8), ra = AT(50, 6, -6), neck = A(-22, -4, 0) }),
		},
	})
end

-- Освободить из капкана / обезвредить: на колене, раздвигает челюсти капкана, руки дрожат от
-- натуги, челюсти срываются — хватается снова.
do
	local function k(t, s, e)
		return K(t, on(KNEEL_R, s), e or "SineInOut")
	end
	define({ "FreeTrap", "DisarmTrap" }, {
		Duration = 2.0,
		Loop = true,
		Keys = {
			k(0, { lean = 38, la = A(66, 0, 4), ra = A(66, 0, -4), neck = A(-24, 0, 0) }),
			k(0.5, { lean = 30, hip = V(0, -0.96, 0.08), la = A(62, 0, -22), ra = A(62, 0, 22), neck = A(-18, 0, 0) }),
			k(0.7, { lean = 31, hip = V(0, -0.96, 0.08), la = A(63, 0, -24), ra = A(61, 0, 21), neck = A(-17, 3, 0) }, "Linear"),
			k(0.9, { lean = 30, hip = V(0, -0.96, 0.08), la = A(61, 0, -21), ra = A(63, 0, 24), neck = A(-19, -3, 0) }, "Linear"),
			k(1.1, { lean = 31, hip = V(0, -0.96, 0.08), la = A(63, 0, -25), ra = A(62, 0, 25), neck = A(-16, 0, 0) }, "Linear"),
			k(1.25, { lean = 42, la = A(64, 0, 8), ra = A(64, 0, -8), neck = A(-28, 0, 0) }, "QuadIn"),
			k(1.6, { lean = 38, la = A(66, 0, 4), ra = A(66, 0, -4), neck = A(-24, 6, 0) }),
		},
	})
end

-- Снять с крюка (1.2 с): тянется вверх, берёт под руки, поднимает с натугой, отклоняясь назад
define({ "Unhook" }, {
	Duration = 1.2,
	Keys = {
		K(0, on(STAND, { lean = 2, la = A(150, 0, -10), ra = A(150, 0, 10), neck = A(25, 0, 0) })),
		K(0.3, on(STAND, { lean = 0, la = A(142, 0, 8), ra = A(142, 0, -8), neck = A(24, 0, 0) }), "SineInOut"),
		K(0.75, on(STAND, { lean = -10, hip = V(0, 0.06, 0.06), ll = A(6, 0, -3), rl = A(-8, 0, 3), la = A(166, 0, 5), ra = A(166, 0, -5), neck = A(30, 0, 0) }), "SineInOut"),
		K(1.2, on(STAND, { lean = -12, hip = V(0, 0.08, 0.08), ll = A(8, 0, -3), rl = A(-10, 0, 3), la = A(172, 0, 6), ra = A(172, 0, -6), neck = A(32, 0, 0) }), "SineInOut"),
	},
})

-- Ворота: правая держит рычаг вниз (дожимает), левая упирается в щиток, нервно оглядывается
do
	local function k(t, s, e)
		return K(t, on({ ll = A(4, 0, -4), rl = A(-6, 0, 4) }, s), e or "SineInOut")
	end
	define({ "OpenGate" }, {
		Duration = 4.0,
		Loop = true,
		Keys = {
			k(0, { lean = 8, turn = 4, la = A(80, 0, -12), ra = AT(70, 4, 10), neck = A(-6, 0, 0) }),
			k(0.7, { lean = 10, turn = 4, la = A(80, 0, -12), ra = AT(64, 4, 10), neck = A(-8, -4, 0) }),
			k(1.3, { lean = 8, turn = 2, la = A(78, 0, -12), ra = AT(70, 4, 10), neck = A(-4, 2, 0) }),
			k(1.8, { lean = 6, turn = 14, roll = 2, la = A(74, 0, -14), ra = AT(68, 4, 10), neck = A(2, 55, 0) }),
			k(2.6, { lean = 6, turn = 12, roll = 2, la = A(74, 0, -14), ra = AT(68, 4, 10), neck = A(4, 48, -4) }, "Linear"),
			k(3.1, { lean = 10, turn = 2, la = A(80, 0, -12), ra = AT(64, 4, 10), neck = A(-8, -20, 0) }),
			k(3.6, { lean = 9, turn = 4, la = A(80, 0, -12), ra = AT(68, 4, 10), neck = A(-6, -6, 0) }),
		},
	})
end

-- Лечение аптечкой: аптечка в правой у левого бока, левая придерживает одежду, сутулится,
-- прикладывает и морщится от боли.
do
	local function k(t, s, e)
		return K(t, on({ hip = V(-0.08, -0.05, 0), ll = A(6, 0, -6), rl = A(-4, 0, 5) }, s), e or "SineInOut")
	end
	define({ "SelfHeal" }, {
		Duration = 2.4,
		Loop = true,
		Keys = {
			k(0, { lean = 20, turn = 8, roll = 4, la = A(36, 0, 24), ra = AT(52, -38, 20), neck = A(-28, 10, 6) }),
			k(0.5, { lean = 22, turn = 9, roll = 4, la = A(38, 0, 22), ra = AT(46, -42, 26), neck = A(-30, 12, 6) }),
			k(0.8, { lean = 26, turn = 4, roll = 6, la = A(42, 0, 18), ra = AT(50, -36, 18), neck = A(-34, 6, 10) }, "QuadOut"),
			k(1.2, { lean = 20, turn = 8, roll = 4, la = A(36, 0, 24), ra = AT(54, -40, 22), neck = A(-26, 10, 6) }),
			k(1.7, { lean = 21, turn = 10, roll = 4, la = A(38, 0, 22), ra = AT(46, -44, 28), neck = A(-30, 14, 6) }),
			k(2.0, { lean = 18, turn = 6, roll = 3, la = A(34, 0, 24), ra = AT(52, -38, 20), neck = A(-12, 30, 0) }),
		},
	})
end

-- Вырваться из капкана (1.4 с — одна попытка): правая нога в капкане, левое колено на земле;
-- хватается за ногу и рвёт её вверх всем телом.
do
	local function k(t, s, e)
		return K(t, on({ hip = V(0.1, -0.4, -0.1), rl = A(-4, 0, 3), ll = A(-70, 0, -6) }, s), e or "SineInOut")
	end
	define({ "EscapeTrap" }, {
		Duration = 1.4,
		Loop = true,
		Keys = {
			k(0, { lean = 38, turn = -8, roll = -5, la = A(66, 0, 24), ra = A(62, 0, 6), neck = A(-28, 0, 0) }),
			k(0.35, { lean = 44, turn = -10, roll = -6, la = A(76, 0, 26), ra = A(72, 0, 8), neck = A(-30, 0, 0) }),
			k(0.55, { lean = 22, turn = -4, roll = -8, hip = V(0.1, -0.3, -0.04), la = A(40, 0, 20), ra = A(36, 0, 4), neck = A(-8, 0, 0) }, "QuadOut"),
			k(0.75, { lean = 26, turn = -6, roll = -6, hip = V(0.1, -0.32, -0.06), la = A(44, 0, 22), ra = A(40, 0, 4), neck = A(-14, -6, 0) }),
			k(1.05, { lean = 40, turn = -8, roll = -4, la = A(70, 0, 24), ra = A(66, 0, 6), neck = A(-30, 6, 0) }),
		},
	})
end

------------------------------------------------------------------------
-- Маньяк
------------------------------------------------------------------------

-- Повесить на крюк (1.2 с): выживший на правом плече; приседает и подхватывает обеими руками,
-- рывком поднимает вверх и насаживает, отклоняясь назад.
define({ "Hook" }, {
	Duration = 1.2,
	Keys = {
		K(0, on(STAND, { lean = 8, la = A(10, 0, -10), ra = A(132, 0, 10), neck = A(-4, 0, 0) })),
		K(0.3, on({ hip = V(0, -0.18, 0), ll = A(16, 0, -8), rl = A(-14, 0, 8) }, { lean = 16, la = A(120, 0, -8), ra = A(118, 0, 16), neck = A(6, 0, 0) }), "SineInOut"),
		K(0.62, on({ hip = V(0, 0.04, 0), ll = A(4, 0, -4), rl = A(-6, 0, 4) }, { lean = -8, la = A(168, 0, -6), ra = A(166, 0, 12), neck = A(28, 0, 0) }), "QuadOut"),
		K(0.9, on({ hip = V(0, 0.06, 0.04), ll = A(6, 0, -4), rl = A(-8, 0, 4) }, { lean = -12, la = A(174, 0, -4), ra = A(172, 0, 10), neck = A(32, 0, 0) }), "SineInOut"),
		K(1.2, on({ hip = V(0, 0.02, 0.02), ll = A(4, 0, -4), rl = A(-6, 0, 4) }, { lean = -6, la = A(160, 0, -8), ra = A(158, 0, 12), neck = A(24, 0, 0) }), "SineInOut"),
	},
})

-- Сломать паллету (2.6 с): высоко заносит правую ногу и топчет; второй замах сильнее — паллета ломается
do
	local lift = { hip = V(-0.14, 0.04, 0.05), ll = A(-2, 0, -4) }
	local stomp = { hip = V(-0.1, -0.12, -0.05), ll = A(-6, 0, -4) }
	define({ "Break" }, {
		Duration = 2.6,
		Keys = {
			K(0, on(STAND, { lean = 6, la = A(6, 0, -9), ra = A(16, 0, 12), neck = A(-6, 0, 0) })),
			K(0.45, on(lift, { lean = -4, rl = A(85, 0, 6), la = A(30, 0, -35), ra = A(40, 0, 35), neck = A(-24, 0, 0) }), "SineInOut"),
			K(0.58, on(stomp, { lean = 14, rl = A(26, 0, 4), la = A(10, 0, -22), ra = A(14, 0, 24), neck = A(-34, 0, 0) }), "CubicIn"),
			K(0.9, on(STAND, { lean = 8, rl = A(10, 0, 4), la = A(10, 0, -14), ra = A(18, 0, 14), neck = A(-26, 0, 0) }), "SineInOut"),
			K(1.6, on(lift, { lean = -10, hip = V(-0.15, 0.06, 0.08), rl = A(98, 0, 6), la = A(50, 0, -45), ra = A(60, 0, 40), neck = A(-26, 4, 0) }), "SineInOut"),
			K(1.74, on(stomp, { lean = 20, hip = V(-0.1, -0.16, -0.08), rl = A(28, 0, 4), la = A(6, 0, -26), ra = A(10, 0, 28), neck = A(-36, 0, 0) }), "CubicIn"),
			K(2.1, on(stomp, { lean = 16, rl = A(24, 0, 4), la = A(8, 0, -18), ra = A(16, 0, 18), neck = A(-30, 0, 0) }), "SineInOut"),
			K(2.6, on(STAND, { lean = 8, rl = A(4, 0, 3), la = A(6, 0, -10), ra = A(16, 0, 12), neck = A(-14, 0, 0) }), "SineInOut"),
		},
	})
end

-- Повредить генератор (1.8 с): заносит ногу, отклоняясь назад, мощный прямой удар, ставит ногу
define({ "Kick" }, {
	Duration = 1.8,
	Keys = {
		K(0, on(STAND, { lean = 6, la = A(6, 0, -9), ra = A(16, 0, 12), neck = A(0, 0, 0) })),
		K(0.5, on({ hip = V(-0.12, 0.02, 0.1), ll = A(-4, 0, -4) }, { lean = -10, turn = -8, rl = A(70, 0, 4), la = A(40, 0, -30), ra = A(50, 0, 30), neck = A(-10, 8, 0) }), "SineInOut"),
		K(0.62, on({ hip = V(-0.1, 0.04, -0.2), ll = A(-14, 0, -4) }, { lean = -16, turn = 6, rl = A(84, 0, 2), la = A(-10, 0, -34), ra = A(-6, 0, 30), neck = A(-4, -6, 0) }), "CubicIn"),
		K(0.85, on({ hip = V(-0.1, 0.02, -0.1), ll = A(-8, 0, -4) }, { lean = -8, turn = 2, rl = A(60, 0, 4), la = A(10, 0, -24), ra = A(14, 0, 24), neck = A(-8, 0, 0) }), "QuadOut"),
		K(1.25, on(STAND, { lean = 8, rl = A(-4, 0, 3), la = A(8, 0, -12), ra = A(18, 0, 14), neck = A(-10, 0, 0) }), "SineInOut"),
		K(1.8, on(STAND, { lean = 6, la = A(6, 0, -9), ra = A(16, 0, 12), neck = A(-4, 0, 0) }), "SineInOut"),
	},
})

-- Обыск шкафчика (0.9 с): левой рывком распахивает дверцу, правой лезет внутрь
define({ "SearchLocker" }, {
	Duration = 0.9,
	Keys = {
		K(0, on(STAND, { lean = 6, la = A(6, 0, -9), ra = A(16, 0, 12), neck = A(0, 0, 0) })),
		K(0.2, on(STAND, { lean = 10, turn = -6, la = A(84, 0, -4), ra = A(24, 0, 14), neck = A(-4, -4, 0) }), "SineInOut"),
		K(0.36, on(STAND, { lean = 6, turn = 14, la = A(56, 0, -72), ra = A(30, 0, 16), neck = A(-2, -10, 0) }), "QuadOut"),
		K(0.6, on({ hip = V(0, -0.06, -0.18), ll = A(-12, 0, -4), rl = A(14, 0, 4) }, { lean = 22, turn = 6, la = A(60, 0, -60), ra = A(92, 0, -4), neck = A(-6, -6, 0) }), "SineInOut"),
		K(0.9, on({ hip = V(0, -0.06, -0.2), ll = A(-12, 0, -4), rl = A(14, 0, 4) }, { lean = 24, turn = 4, la = A(58, 0, -58), ra = A(98, 0, 8), neck = A(-8, -2, 0) }), "SineInOut"),
	},
})

-- Капкан: ставит, забирает, взводит; люк закрывает — на колене, руки у земли, разжимает пружины
do
	local function k(t, s, e)
		return K(t, on({ hip = V(0, -1.05, 0), ll = A(58, 0, -8), rl = A(-60, 0, 8) }, s), e or "SineInOut")
	end
	define({ "SetTrap", "PickupTrap", "ResetTrap", "CloseHatch" }, {
		Duration = 1.6,
		Loop = true,
		Keys = {
			k(0, { lean = 40, la = A(72, 0, -8), ra = A(72, 0, 8), neck = A(-20, 0, 0) }),
			k(0.4, { lean = 46, hip = V(0, -1.1, 0), la = A(64, 0, -12), ra = A(64, 0, 12), neck = A(-24, 0, 0) }),
			k(0.8, { lean = 42, turn = -4, la = A(66, 0, -12), ra = A(80, 0, -4), neck = A(-22, -6, 0) }),
			k(1.2, { lean = 40, la = A(70, 0, -10), ra = A(70, 0, 10), neck = A(-18, 4, 0) }),
		},
	})
end

return Actions
