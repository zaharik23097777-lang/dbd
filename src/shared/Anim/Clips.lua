-- Одноразовые анимации (Poses.OneShot) — ключевые клипы Anim/Clip.lua.
-- Ритм: подготовка -> действие -> захлёст -> возврат; голова и свободная рука запаздывают,
-- вес переносится через таз (корпус поворачивается вокруг таза, ноги не уезжают).
--
-- Два вида клипов:
--   * всё тело (обычный слой): позы ключей собирает body{} — корпус поворачивается вокруг таза,
--     ноги задаются МИРОВЫМИ углами (относительно HumanoidRootPart), руки и голова — в пространстве
--     торса. Для случаев, когда персонаж стоит или его двигает сервер (прыжок в окно, крюк).
--   * верх тела (Upper = true, ключи собирает up{}): персонаж может бежать. Корпус ключа — ДОБАВКА
--     к корпусу походки (поворот вокруг таза), RootPos — сдвиг таза, ноги походки сохраняют мировое
--     положение (ноги ключа применяются, только пока персонаж стоит), руки и голова — как обычно.
-- Clips.apply накладывает любой из них (Animator, превью, тесты).
--
-- Поля сверх Clip: Upper; Follows — имя клипа, из позы которого этот начинается без FadeIn
-- (Wipe после Swing, Throw после Windup).
--
-- Длительности = серверные времена (Config, KillerDefs, Systems/*, Powers/*):
--   Swing 0.7 (выпад KillerLungeTime 0.35), Wipe 2.4 (замедление после удара 2.7),
--   Stun 2.2 (PalletStunTime), Blind 2.5 (BlindDuration), Vault 0.55 / VaultWalk 0.95 (Obstacles:
--   с бега / шагом — сервер везёт корень вверх на 2.2 к середине и вниз), KillerVault 1.6,
--   PalletDrop 0.6 (удар паллеты о землю на 0.22), Windup — держится до Throw/Cancel (30),
--   Throw 0.45, Bell 1.5 (CloakTime) / BellUncloak 1.0 (UncloakTime), Pickup 0.8, Flinch 0.45,
--   HookScream 1.4, Entity 2.8 (Сущность поднимает тело с 1.6 по 2.8).
local Rig = require(script.Parent.Rig)
local Clip = require(script.Parent.Clip)
local Life = require(script.Parent.Life)

local Clips = {}

type Pose = Clip.Pose

local rad, clamp = math.rad, math.clamp
local A = Rig.A
local V = Vector3.new
local YXZ = CFrame.fromEulerAnglesYXZ
local IDENTITY = CFrame.identity
local ZERO = Vector3.zero
local DOWN = Vector3.new(0, -1, 0)

------------------------------------------------------------------------
-- Помощники авторинга
------------------------------------------------------------------------

-- Рука/нога вдоль направления (x вправо, y вверх, z назад — в пространстве родителя;
-- вперёд — минус z) с поворотом twist (°) вокруг своей оси (куда смотрит оружие в руке)
local function aim(x: number, y: number, z: number, twist: number?): CFrame
	local cf = Rig.aim(V(x, y, z))
	return twist and cf * CFrame.Angles(0, rad(twist), 0) or cf
end
Clips.aim = aim

-- Как Rig.A(x, 0, z), но с поворотом twist вокруг оси конечности (направление не меняется)
local function AT(x: number, z: number, twist: number): CFrame
	return A(x, 0, z) * CFrame.Angles(0, rad(twist), 0)
end
Clips.AT = AT

-- Корпус: наклон вперёд, поворот влево, крен влево (правое плечо вверх), в градусах
local function torso(lean: number?, turn: number?, roll: number?): CFrame
	return YXZ(rad(-(lean or 0)), rad(turn or 0), rad(roll or 0))
end

export type Spec = {
	lean: number?,
	turn: number?,
	roll: number?,
	hip: Vector3?, -- сдвиг таза (стады): +X вправо, +Y вверх, +Z назад
	ll: CFrame?, -- ноги — мировые углы
	rl: CFrame?,
	la: CFrame?, -- руки и голова — в пространстве торса
	ra: CFrame?,
	neck: CFrame?,
}

-- Поза всего тела. center = true — корпус вращается вокруг своего центра (висит на крюке),
-- иначе вокруг таза (стоит на ногах); hip — сдвиг этой точки от положения стоя.
local function body(s: Spec, center: boolean?): Pose
	local r = torso(s.lean, s.turn, s.roll)
	local inv = r:Inverse()
	local hip = s.hip or ZERO
	return {
		Root = r,
		RootPos = if center then hip else hip + DOWN + r.UpVector,
		LLeg = inv * (s.ll or IDENTITY),
		RLeg = inv * (s.rl or IDENTITY),
		LArm = s.la,
		RArm = s.ra,
		Neck = s.neck,
	}
end
Clips.body = body

local function hang(s: Spec): Pose
	return body(s, true)
end

-- Кадр «верха тела» (см. шапку): корпус и таз — добавки, ноги — мировые углы (необязательно)
local function up(s: Spec): Pose
	return {
		Root = torso(s.lean, s.turn, s.roll),
		RootPos = s.hip or ZERO,
		LLeg = s.ll,
		RLeg = s.rl,
		LArm = s.la,
		RArm = s.ra,
		Neck = s.neck,
	}
end

local function K(t: number, pose: Pose, ease: Clip.Ease?): Clip.Key
	return { T = t, Pose = pose, Ease = ease }
end
Clips.K = K

local function upperClip(def: Clip.Def): Clip.Clip
	local clip = Clip.new(def);
	(clip :: any).Upper = true
	return clip
end

------------------------------------------------------------------------
-- Наложение
------------------------------------------------------------------------

local LEGS = { "LLeg", "RLeg" }
local TOP = { "Neck", "LArm", "RArm" }

-- Слой «верх тела» с весом w: корпус поворачивается вокруг таза походки, стопы остаются на месте
local function layerUpper(dst: Pose, f: Pose, w: number, legW: number)
	local r = dst.Root or IDENTITY
	local hip = (dst.RootPos or ZERO) - r.UpVector
	local d = f.Root
	local r2 = r
	if d then
		r2 = r * (if w >= 1 then d else IDENTITY:Lerp(d, w))
	end
	local off = f.RootPos
	if off then
		hip += off * w
	end
	dst.Root = r2
	dst.RootPos = hip + r2.UpVector
	local inv = r2:Inverse()
	for _, leg in LEGS do
		local world = r * (dst[leg] or IDENTITY)
		local lw = f[leg]
		if lw and legW > 0 then
			world = world:Lerp(lw, legW)
		end
		dst[leg] = inv * world
	end
	for _, k in TOP do
		local v = f[k]
		if v then
			dst[k] = if w >= 1 then v else (dst[k] or IDENTITY):Lerp(v, w)
		end
	end
end

-- Наложить одноразовую анимацию def на позу dst (своя таблица) в момент elapsed (с) от начала.
-- fade — дополнительный множитель веса (плавная отмена). Возвращает множитель жёсткости пружин.
function Clips.apply(dst: Pose, def: any, elapsed: number, p: any?, fade: number?): number
	local w = Clip.weight(def, elapsed) * (fade or 1)
	if w <= 0 then
		return 1
	end
	local frame = def.Fn(clamp(elapsed / def.Duration, 0, 1), p)
	if def.Upper then
		-- ноги клипа — только пока стоит (на бегу ноги ведёт походка)
		local speed = p and p.Speed or 0
		layerUpper(dst, frame, w, w * clamp(1 - (speed - 1) / 3, 0, 1))
	else
		Clip.layer(dst, frame, w, def.Additive)
	end
	return 1 + ((def.Stiffness or 1) - 1) * w
end

-- Сервер шлёт одно имя, а длительность зависит от обстоятельств: прыжок с бега — 0.55 с,
-- шагом — 0.95 с; колокол Призрака: исчезнуть — 1.5 с, проявиться — 1 с.
function Clips.variant(name: string, running: boolean, powerState: any): string
	if name == "Vault" and not running then
		return "VaultWalk"
	elseif name == "Bell" and (powerState == "Uncloaking" or powerState == "Cloaked") then
		return "BellUncloak"
	end
	return name
end

local OneShot = {}
Clips.OneShot = OneShot

------------------------------------------------------------------------
-- Маньяк: удар (0.7 с, выпад 0.35 с) — замах за плечо со скруткой корпуса, быстрый диагональный
-- удар с выпадом, корпус проваливается следом, тяжёлый возврат.
------------------------------------------------------------------------

local SWING_FOLLOW = {
	lean = 22,
	turn = 30,
	roll = -12,
	hip = V(0, -0.22, -0.12),
	la = A(-28, 0, -30),
	ra = aim(-0.35, -0.75, -0.55),
	neck = A(8, -22, 8),
}

OneShot.Swing = upperClip({
	Duration = 0.7,
	FadeIn = 0.06,
	FadeOut = 0.26,
	Stiffness = 1.7,
	Keys = {
		K(0, up({ la = A(12, 0, -12), ra = A(26, 0, 14), neck = A(0, 0, 0) })),
		-- рука идёт вперёд-вверх (а не назад через низ)
		K(0.07, up({ lean = -2, turn = -12, roll = 3, la = A(40, 0, -22), ra = aim(0.5, 0.55, -0.67), neck = A(-2, 10, -2) }), "SineIn"),
		-- замах: оружие за правым плечом, корпус скручен вправо и чуть назад, левая рука — вперёд
		K(0.15, up({ lean = -6, turn = -28, roll = 8, hip = V(0, -0.03, 0.08), la = A(66, 0, -30), ra = aim(0.45, 0.8, 0.4), neck = A(-4, 24, -6) }), "QuadOut"),
		-- удар по диагонали: сверху справа вниз влево, корпус раскручивается, вес — вперёд
		K(0.205, up({ lean = 2, turn = -8, roll = 2, hip = V(0, -0.08, 0), la = A(45, 0, -28), ra = aim(0.25, 0.7, -0.65), neck = A(-2, 8, 0) }), "QuadIn"),
		K(0.26, up({ lean = 14, turn = 18, roll = -8, hip = V(0, -0.16, -0.08), la = A(-10, 0, -32), ra = aim(-0.45, -0.45, -0.77), neck = A(4, -14, 6) })),
		K(0.36, up(SWING_FOLLOW), "QuadOut"),
		-- оружие тяжёлое: рука висит, корпус выпрямляется не сразу
		K(0.5, up({ lean = 14, turn = 18, roll = -6, hip = V(0, -0.14, -0.06), la = A(-12, 0, -20), ra = aim(-0.05, -0.85, -0.45), neck = A(4, -14, 4) }), "SineInOut"),
	},
})

-- После попадания (2.4 с, маньяк медленно идёт): доводит удар, выпрямляется, проводит клинком
-- по левой руке (дважды), стряхивает и опускает оружие; голова склонена набок.
OneShot.Wipe = upperClip({
	Duration = 2.4,
	FadeIn = 0,
	FadeOut = 0.5,
	Stiffness = 1.15,
	Keys = {
		K(0, up(SWING_FOLLOW)),
		K(0.3, up({ lean = 8, turn = 8, roll = -3, hip = V(0, -0.06, -0.02), la = A(5, 0, -14), ra = A(30, 0, 4), neck = A(2, -8, 0) }), "SineInOut"),
		-- клинок поперёк груди (смотрит влево), левая рука под ним
		K(0.7, up({ lean = 10, turn = -10, la = aim(0.55, -0.2, -0.81), ra = aim(-0.35, -0.05, -0.94, 85), neck = A(-24, 14, 14) }), "SineInOut"),
		K(1.05, up({ lean = 10, turn = -6, la = aim(0.5, -0.25, -0.83), ra = aim(0.15, -0.05, -0.99, 85), neck = A(-24, 6, 14) }), "SineInOut"),
		K(1.25, up({ lean = 10, turn = -10, la = aim(0.55, -0.2, -0.81), ra = aim(-0.35, -0.05, -0.94, 85), neck = A(-22, 12, 12) }), "SineInOut"),
		K(1.5, up({ lean = 9, turn = -4, la = aim(0.48, -0.28, -0.83), ra = aim(0.3, -0.1, -0.95, 85), neck = A(-20, 0, 10) }), "QuadIn"),
		-- стряхивает кровь
		K(1.62, up({ lean = 8, turn = 2, la = A(30, 0, -10), ra = aim(0.5, -0.35, -0.79, 60), neck = A(-10, -6, 8) }), "QuadOut"),
		K(2.0, up({ lean = 6, la = A(8, 0, -12), ra = A(22, 0, 12), neck = A(-4, 0, 10) }), "SineInOut"),
	},
})

------------------------------------------------------------------------
-- Маньяк оглушён паллетой (2.2 с, стоит): отлетает назад, хватается левой за голову, оружие
-- в опущенной правой, два шага назад, трясёт головой, приходит в себя.
------------------------------------------------------------------------

local HOLD_HEAD = aim(0.4, 0.78, -0.47)

OneShot.Stun = Clip.new({
	Duration = 2.2,
	FadeIn = 0.05,
	FadeOut = 0.45,
	Stiffness = 1.35,
	Keys = {
		K(0, body({ lean = 6, ll = A(0, 0, -3), rl = A(0, 0, 3), la = A(6, 0, -9), ra = A(16, 0, 12), neck = A(0, 0, 0) })),
		-- удар: голову откидывает, руки разлетаются
		K(0.08, body({ lean = -16, turn = 8, roll = -6, hip = V(0, -0.02, 0.22), ll = A(8, 0, -6), rl = A(14, 0, 8), la = A(60, 0, -50), ra = A(40, 0, 45), neck = A(30, -10, 8) }), "QuadOut"),
		-- сгибается, держится за голову, шаг назад правой
		K(0.3, body({ lean = 24, turn = 12, roll = 6, hip = V(0.08, -0.08, 0.32), ll = A(16, 0, -8), rl = A(-18, 0, 8), la = HOLD_HEAD, ra = A(-6, 0, 22), neck = A(-28, 12, -10) }), "SineInOut"),
		-- шаг назад левой, шатается
		K(0.62, body({ lean = 28, turn = -8, roll = -8, hip = V(-0.08, -0.1, 0.4), ll = A(-20, 0, -12), rl = A(18, 0, 10), la = aim(0.36, 0.76, -0.52), ra = A(-2, 0, 18), neck = A(-32, -10, 8) }), "SineInOut"),
		-- широко стоит, трясёт головой
		K(0.95, body({ lean = 24, turn = 6, roll = 4, hip = V(0, -0.1, 0.4), ll = A(-12, 0, -12), rl = A(12, 0, 10), la = HOLD_HEAD, ra = A(-4, 0, 20), neck = A(-24, 16, -6) }), "SineInOut"),
		K(1.18, body({ lean = 25, turn = -4, roll = 2, hip = V(0, -0.1, 0.4), ll = A(-12, 0, -12), rl = A(12, 0, 10), la = aim(0.42, 0.74, -0.52), ra = A(-2, 0, 20), neck = A(-26, -16, 6) }), "SineInOut"),
		K(1.42, body({ lean = 22, turn = 4, roll = 3, hip = V(0, -0.09, 0.36), ll = A(-10, 0, -10), rl = A(10, 0, 9), la = HOLD_HEAD, ra = A(0, 0, 18), neck = A(-20, 12, -4) }), "SineInOut"),
		-- выпрямляется, рука опускается
		K(1.78, body({ lean = 10, hip = V(0, -0.04, 0.2), ll = A(-6, 0, -6), rl = A(6, 0, 6), la = A(30, 0, -14), ra = A(10, 0, 14), neck = A(-8, 4, 0) }), "SineInOut"),
	},
})

------------------------------------------------------------------------
-- Маньяк ослеплён (2.5 с, может идти): закрывает глаза руками, отворачивает голову,
-- пошатывается, трёт глаза, опускает руки.
------------------------------------------------------------------------

OneShot.Blind = upperClip({
	Duration = 2.5,
	FadeIn = 0.06,
	FadeOut = 0.5,
	Stiffness = 1.3,
	Keys = {
		K(0, up({ la = A(8, 0, -10), ra = A(16, 0, 12), neck = A(0, 0, 0) })),
		K(0.1, up({ lean = -12, turn = 10, hip = V(0, 0, 0.12), la = aim(0.45, 0.62, -0.64), ra = aim(-0.35, 0.55, -0.76), neck = A(10, 35, 0) }), "QuadOut"),
		K(0.45, up({ lean = -4, turn = -14, roll = 6, hip = V(0.05, -0.05, 0.18), la = aim(0.5, 0.58, -0.64), ra = aim(-0.3, 0.5, -0.8), neck = A(-8, -30, 6) }), "SineInOut"),
		K(0.8, up({ lean = 6, turn = 12, roll = -6, hip = V(-0.05, -0.07, 0.16), la = aim(0.42, 0.66, -0.62), ra = aim(-0.38, 0.58, -0.72), neck = A(-14, 28, -6) }), "SineInOut"),
		-- трёт глаза
		K(1.15, up({ lean = 10, turn = -8, roll = 4, hip = V(0, -0.08, 0.1), la = aim(0.48, 0.52, -0.7), ra = aim(-0.25, 0.42, -0.87), neck = A(-18, -20, 8) }), "SineInOut"),
		K(1.5, up({ lean = 8, turn = 6, roll = -3, hip = V(0, -0.06, 0.06), la = aim(0.4, 0.62, -0.67), ra = A(40, 0, 20), neck = A(-12, 14, -4) }), "SineInOut"),
		K(1.95, up({ lean = 4, la = A(55, 0, 10), ra = A(25, 0, 14), neck = A(-6, 8, 0) }), "SineInOut"),
	},
})

------------------------------------------------------------------------
-- Маньяк поднимает выжившего (0.8 с): наклоняется и хватает, рывком закидывает на правое плечо
-- (сервер кладёт тело на правое плечо, походка Carry держит его правой), оседает под весом.
------------------------------------------------------------------------

OneShot.Pickup = upperClip({
	Duration = 0.8,
	FadeIn = 0.1,
	FadeOut = 0.28,
	Stiffness = 1.3,
	Keys = {
		K(0, up({ ll = A(0, 0, -2), rl = A(0, 0, 2), la = A(8, 0, -10), ra = A(30, 0, 10), neck = A(0, 0, 0) })),
		K(0.18, up({ lean = 28, turn = -10, roll = -4, hip = V(0, -0.22, 0.1), ll = A(22, 0, -8), rl = A(-14, 0, 8), la = A(55, 0, -12), ra = A(62, 0, 6), neck = A(20, 0, 0) }), "SineOut"),
		K(0.36, up({ lean = -6, turn = 6, roll = 9, hip = V(0, 0.06, 0), ll = A(6, 0, -6), rl = A(-6, 0, 6), la = A(-25, 0, -24), ra = A(140, 0, 12), neck = A(-6, -6, 0) }), "BackOut"),
		K(0.52, up({ lean = 8, roll = 4, hip = V(0, -0.1, 0), ll = A(4, 0, -5), rl = A(-4, 0, 5), la = A(5, 0, -14), ra = A(134, 0, 10), neck = A(-10, 0, 0) }), "SineInOut"),
	},
})

------------------------------------------------------------------------
-- Выживший опускает паллету (0.6 с, удар о землю на 0.22): хватает сверху двумя руками,
-- рывком роняет вперёд всем корпусом, оглядывается.
------------------------------------------------------------------------

OneShot.PalletDrop = upperClip({
	Duration = 0.6,
	FadeIn = 0.05,
	FadeOut = 0.25,
	Stiffness = 1.5,
	Keys = {
		K(0, up({ la = A(10, 0, -8), ra = A(10, 0, 8), neck = A(0, 0, 0) })),
		K(0.09, up({ lean = -6, hip = V(0, 0.05, 0), la = aim(-0.25, 0.75, -0.6), ra = aim(0.25, 0.75, -0.6), neck = A(14, 0, 0) }), "QuadOut"),
		K(0.22, up({ lean = 26, turn = 4, roll = -3, hip = V(0, -0.18, -0.08), la = A(45, 0, -16), ra = A(50, 0, 14), neck = A(4, 0, 0) }), "CubicIn"),
		K(0.32, up({ lean = 32, turn = 6, roll = -4, hip = V(0, -0.22, -0.1), la = A(20, 0, -20), ra = A(28, 0, 18), neck = A(8, 10, 0) }), "QuadOut"),
		K(0.42, up({ lean = 14, turn = 10, hip = V(0, -0.08, 0), la = A(10, 0, -14), ra = A(12, 0, 12), neck = A(2, 30, 0) }), "SineInOut"),
	},
})

------------------------------------------------------------------------
-- Выжившего ударили (0.45 с, бежит с ускорением): удар в спину выгибает, затем резкий рывок
-- вперёд, руки болтаются, спотыкается и переходит в бег.
------------------------------------------------------------------------

OneShot.Flinch = upperClip({
	Duration = 0.45,
	FadeIn = 0.03,
	FadeOut = 0.22,
	Stiffness = 1.9,
	Keys = {
		K(0, up({ la = A(10, 0, -8), ra = A(10, 0, 8), neck = A(0, 0, 0) })),
		K(0.05, up({ lean = -14, turn = -6, roll = 8, hip = V(0, 0.04, -0.12), la = A(-35, 0, -40), ra = A(-25, 0, 45), neck = A(24, 8, 0) }), "QuadOut"),
		K(0.16, up({ lean = 26, turn = 10, roll = -6, hip = V(0, -0.14, -0.1), la = A(75, 0, -50), ra = A(30, 0, 55), neck = A(-14, -6, 4) }), "QuadOut"),
		K(0.27, up({ lean = 18, turn = -4, roll = 4, hip = V(0, -0.08, 0), la = A(40, 0, -30), ra = A(-20, 0, 30), neck = A(-6, 4, 0) }), "SineInOut"),
	},
})

------------------------------------------------------------------------
-- Охотница: замах топором (держится, пока заряжает — до Throw или Cancel) и бросок
------------------------------------------------------------------------

local WINDUP_FULL = {
	lean = -14,
	turn = -32,
	roll = 8,
	hip = V(0, -0.06, 0.12),
	la = aim(-0.36, 0.1, -0.93),
	ra = aim(0.32, 0.6, 0.73),
	neck = A(-2, 30, -6),
}
local FULL_WINDUP_TIME = 1.3 -- KillerDefs.Huntress.FullWindup

local windup = upperClip({
	Duration = 30,
	FadeIn = 0.08,
	FadeOut = 0.3,
	Keys = {
		K(0, up({ la = A(10, 0, -10), ra = A(25, 0, 12), neck = A(0, 0, 0) })),
		-- топор высоко за головой, корпус отклонён назад, левая рука вперёд — целится
		K(0.3, up({ lean = -10, turn = -24, roll = 6, hip = V(0, -0.04, 0.08), la = aim(-0.42, 0.05, -0.91), ra = aim(0.3, 0.72, 0.62), neck = A(-2, 22, -4) }), "QuadOut"),
		-- набирает силу броска до полного замаха
		K(FULL_WINDUP_TIME, up(WINDUP_FULL), "SineInOut"),
	},
})
do
	local sample = windup.Fn
	local sin = math.sin
	windup.Fn = function(a: number, p: any?): Pose
		local pose = sample(a, p)
		local t = a * windup.Duration
		if t > FULL_WINDUP_TIME then
			-- полный замах: рука подрагивает от напряжения, корпус чуть покачивается
			local k = math.min((t - FULL_WINDUP_TIME) / 0.5, 1)
			pose.RArm = pose.RArm * CFrame.Angles(rad(sin(t * 31) * 1.6 * k), 0, rad(sin(t * 23) * 1.2 * k))
			pose.Root = pose.Root * CFrame.Angles(rad(sin(t * 1.7) * 1.2 * k), rad(sin(t * 2.3) * 1.5 * k), 0)
		end
		return pose
	end
end
OneShot.Windup = windup

-- Бросок: ещё чуть назад, хлёсткий выброс руки с полным разворотом корпуса, захлёст вниз-влево
local throw = upperClip({
	Duration = 0.45,
	FadeIn = 0,
	FadeOut = 0.2,
	Stiffness = 1.8,
	Keys = {
		K(0, up(WINDUP_FULL)),
		K(0.05, up({ lean = -16, turn = -36, roll = 9, hip = V(0, -0.06, 0.14), la = aim(-0.3, 0.12, -0.95), ra = aim(0.3, 0.55, 0.78), neck = A(-2, 32, -6) }), "QuadOut"),
		K(0.12, up({ lean = 6, turn = 6, roll = -2, hip = V(0, -0.1, 0), la = A(10, 0, -30), ra = aim(0.12, 0.6, -0.79), neck = A(0, 0, 0) }), "CubicIn"),
		K(0.2, up({ lean = 20, turn = 28, roll = -8, hip = V(0, -0.16, -0.1), la = A(-30, 0, -28), ra = aim(-0.3, -0.35, -0.89), neck = A(6, -26, 4) })),
		K(0.3, up({ lean = 24, turn = 36, roll = -10, hip = V(0, -0.18, -0.12), la = A(-36, 0, -24), ra = aim(-0.45, -0.7, -0.55), neck = A(8, -32, 6) }), "QuadOut"),
	},
});
(throw :: any).Follows = "Windup"
OneShot.Throw = throw;
(OneShot.Wipe :: any).Follows = "Swing"

------------------------------------------------------------------------
-- Призрак: колокол в левой руке. Поднимает, звонит резкими встряхиваниями, голова склонена.
------------------------------------------------------------------------

local function bell(duration: number, rings: number): Clip.Clip
	local lift = duration * 0.18
	local lower = duration * 0.78
	local keys = {
		K(0, up({ la = A(52, 0, -12), ra = A(16, 0, 12), neck = A(0, 0, 0) })),
		K(lift, up({ lean = 8, turn = 10, la = AT(116, -8, 0), ra = A(28, 0, 18), neck = A(-28, 0, 4) }), "SineOut"),
	}
	local from, to = lift + 0.04, lower - 0.1
	for i = 1, rings do
		local s = i % 2 == 1 and 1 or -1
		local t = from + (to - from) * (i - 1) / math.max(rings - 1, 1)
		table.insert(keys, K(t, up({ lean = 8 + s, turn = 10, roll = s * 2, la = AT(116 + s * 7, -8, s * 24), ra = A(28, 0, 18), neck = A(-30 + s, 0, 4) }), "BackOut"))
	end
	table.insert(keys, K(lower, up({ lean = 5, turn = 4, la = A(64, 0, -12), ra = A(20, 0, 14), neck = A(-16, 0, 2) }), "SineInOut"))
	return upperClip({ Duration = duration, FadeIn = 0.1, FadeOut = duration - lower + 0.05, Keys = keys })
end
OneShot.Bell = bell(1.5, 7)
OneShot.BellUncloak = bell(1.0, 5)

------------------------------------------------------------------------
-- На крюке: крик (1.4 с) — выгибается, рвётся вверх к крюку, болтает ногами, обмякает.
-- Корпус вращается вокруг центра (тело висит на крюке, а не стоит на ногах).
------------------------------------------------------------------------

OneShot.HookScream = Clip.new({
	Duration = 1.4,
	FadeIn = 0.06,
	FadeOut = 0.45,
	Stiffness = 1.5,
	Keys = {
		K(0, hang({ lean = 7, roll = -8, ll = A(0, 0, -3), rl = A(-6, 0, 4), la = A(174, 0, 12), ra = A(10, 0, 7), neck = A(-28, 0, 8) })),
		K(0.1, hang({ lean = -22, turn = 6, roll = -14, hip = V(0, 0.2, 0), ll = A(26, 0, -8), rl = A(-10, 0, 10), la = A(178, 0, 18), ra = A(110, 0, 34), neck = A(38, -10, 10) }), "SineOut"),
		K(0.2, hang({ lean = -20, turn = 2, roll = -10, hip = V(0, 0.16, 0), ll = A(6, 0, -6), rl = A(14, 0, 8), la = A(177, 0, 16), ra = A(150, 0, 30), neck = A(36, 0, 6) }), "SineInOut"),
		K(0.3, hang({ lean = -16, turn = -10, roll = -6, hip = V(0, 0.1, 0), ll = A(-12, 0, -6), rl = A(28, 0, 8), la = A(176, 0, 14), ra = A(115, 0, 45), neck = A(30, 12, -6) }), "SineInOut"),
		K(0.5, hang({ lean = -20, turn = 8, roll = -12, hip = V(0, 0.12, 0), ll = A(22, 0, -4), rl = A(-14, 0, 10), la = A(178, 0, 18), ra = A(165, 0, 22), neck = A(34, -8, 8) }), "SineInOut"),
		K(0.72, hang({ lean = -10, turn = -4, roll = -8, hip = V(0, 0.05, 0), ll = A(-6, 0, -4), rl = A(16, 0, 6), la = A(176, 0, 14), ra = A(120, 0, 35), neck = A(20, 6, 0) }), "SineInOut"),
		K(0.95, hang({ lean = 10, roll = -8, ll = A(4, 0, -3), rl = A(-2, 0, 4), la = A(174, 0, 12), ra = A(30, 0, 10), neck = A(-30, 0, 10) }), "SineInOut"),
	},
})

-- Сущность забирает (2.8 с): отчаянно отталкивает её лапы, бьётся; судорога, руки в стороны —
-- тело поднимают (сервер: с 1.6 с вверх на 30 стад).
do
	local keys = {
		K(0, hang({ lean = -4, roll = -8, hip = V(0, 0.03, 0), ll = A(10, 0, -4), rl = A(10, 0, 4), la = A(172, 0, 14), ra = A(158, 0, -6), neck = A(18, 0, 0) })),
	}
	local t, i = 0.12, 0
	while t < 1.5 do
		i += 1
		local s = i % 2 == 1 and 1 or -1
		local e = 0.7 + 0.3 * math.min(t / 0.8, 1) -- отчаяние нарастает
		local h = Life.hash(i * 1.37)
		table.insert(
			keys,
			K(
				t,
				hang({
					lean = -10 - 6 * e + s * 4,
					turn = s * 16 * e,
					roll = -10 + s * 6 * e,
					hip = V(0, 0.06 * e, 0),
					ll = A(8 + s * 28 * e, 0, -6),
					rl = A(8 - s * 28 * e, 0, 6),
					la = A(150 + s * 14, 0, -12 - s * 12),
					ra = A(140 - s * 22, 0, 22 + s * 10),
					neck = A(18 + s * 6, -s * (20 + 12 * h) * e, s * 6),
				}),
				i % 3 == 0 and "QuadOut" or "SineInOut"
			)
		)
		t += 0.12 + 0.05 * h -- неровный ритм
	end
	table.insert(keys, K(1.68, hang({ lean = -30, roll = -4, hip = V(0, 0.2, 0), ll = A(-8, 0, -4), rl = A(-4, 0, 4), la = A(165, 0, -40), ra = A(165, 0, 40), neck = A(40, 0, 0) }), "QuadOut"))
	table.insert(keys, K(2.1, hang({ lean = -20, roll = -2, hip = V(0, 0.1, 0), ll = A(-6, 0, -3), rl = A(-2, 0, 3), la = A(30, 0, -80), ra = A(30, 0, 80), neck = A(36, 0, 6) }), "SineInOut"))
	table.insert(keys, K(2.8, hang({ lean = -16, hip = V(0, 0.08, 0), ll = A(-4, 0, -2), rl = A(-2, 0, 2), la = A(24, 0, -84), ra = A(24, 0, 84), neck = A(40, 0, 8) }), "SineInOut"))
	OneShot.Entity = Clip.new({ Duration = 2.8, FadeIn = 0.08, FadeOut = 0.3, Stiffness = 1.4, Keys = keys })
end

------------------------------------------------------------------------
-- Прыжки через окно/паллету. Сервер везёт корень (Anchored) по прямой: вверх на 2.2 стада к
-- середине препятствия за половину времени и вниз за вторую половину; высота препятствия 3.
-- Ключи — в долях длительности: u = 0.5 — над подоконником.
------------------------------------------------------------------------

local function timed(duration: number, list: { { any } }): { Clip.Key }
	local keys = {}
	for _, k in list do
		table.insert(keys, K(k[1] * duration, k[2], k[3]))
	end
	return keys
end

-- С бега (0.55 с): упор руками, тело перекатывается через левую руку, ноги проносятся над
-- подоконником вбок, приземление и сразу бег.
OneShot.Vault = Clip.new({
	Duration = 0.55,
	FadeIn = 0.04,
	FadeOut = 0.12,
	Stiffness = 1.5,
	Keys = timed(0.55, {
		{ 0, body({ lean = 14, hip = V(0, -0.04, 0), ll = A(24, 0, -3), rl = A(-26, 0, 3), la = A(-22, 0, -8), ra = A(38, 0, 8), neck = A(-2, 0, 0) }) },
		-- толчок: корпус вперёд, руки тянутся к подоконнику, ноги отталкиваются
		{ 0.16, body({ lean = 32, turn = 6, roll = 4, ll = A(-34, 0, -4), rl = A(-8, 0, 5), la = A(88, 0, -10), ra = A(84, 0, 10), neck = A(22, 0, 0) }), "QuadOut" },
		-- упор левой, ноги проносятся вперёд-вправо
		{ 0.33, body({ lean = 16, turn = 18, roll = 14, hip = V(0, 0.08, 0), ll = A(66, 0, 8), rl = A(78, 0, 20), la = A(34, 0, -6), ra = A(100, 0, 60), neck = A(10, -12, -6) }), "QuadIn" },
		{ 0.5, body({ lean = 2, turn = 22, roll = 18, hip = V(0, 0.1, 0), ll = A(84, 0, 14), rl = A(90, 0, 26), la = A(4, 0, 2), ra = A(112, 0, 76), neck = A(4, -18, -10) }) },
		-- соскальзывает вниз, ноги тянутся к земле
		{ 0.68, body({ lean = 4, turn = 12, roll = 6, ll = A(46, 0, 6), rl = A(30, 0, 10), la = A(-28, 0, -26), ra = A(62, 0, 42), neck = A(0, -10, -2) }), "QuadOut" },
		-- касание земли раньше корня: таз опускается навстречу
		{ 0.85, body({ lean = 18, turn = 4, hip = V(0, -0.62, 0), ll = A(26, 0, -4), rl = A(-14, 0, 4), la = A(-8, 0, -14), ra = A(32, 0, 14), neck = A(-6, -2, 0) }), "SineInOut" },
		{ 1, body({ lean = 15, hip = V(0, -0.04, 0), ll = A(-22, 0, -3), rl = A(28, 0, 3), la = A(36, 0, -8), ra = A(-20, 0, 8), neck = A(-2, 0, 0) }), "SineInOut" },
	}),
})

-- Шагом (0.95 с): обе руки на подоконник, правое колено вверх, перекидывает ноги сидя, спрыгивает
OneShot.VaultWalk = Clip.new({
	Duration = 0.95,
	FadeIn = 0.08,
	FadeOut = 0.18,
	Stiffness = 1.2,
	Keys = timed(0.95, {
		{ 0, body({ lean = 6, ll = A(8, 0, -3), rl = A(-10, 0, 3), la = A(10, 0, -8), ra = A(14, 0, 8), neck = A(0, 0, 0) }) },
		{ 0.18, body({ lean = 30, turn = 4, ll = A(-20, 0, -4), rl = A(10, 0, 4), la = A(84, 0, -12), ra = A(84, 0, 12), neck = A(20, 0, 0) }), "SineInOut" },
		{ 0.36, body({ lean = 34, turn = 10, roll = 8, hip = V(0, 0.05, 0), ll = A(-30, 0, -6), rl = A(70, 0, 14), la = A(44, 0, 0), ra = A(48, 0, -4), neck = A(22, -4, 0) }), "SineInOut" },
		{ 0.52, body({ lean = 6, turn = 24, roll = 16, hip = V(0, 0.1, 0), ll = A(80, 0, 10), rl = A(88, 0, 26), la = A(6, 0, 4), ra = A(40, 0, 30), neck = A(6, -18, -8) }), "SineInOut" },
		{ 0.72, body({ lean = -4, turn = 14, roll = 6, ll = A(40, 0, 4), rl = A(18, 0, 8), la = A(-10, 0, -12), ra = A(30, 0, 24), neck = A(0, -10, -2) }), "SineInOut" },
		{ 0.88, body({ lean = 10, turn = 4, hip = V(0, -0.5, 0), ll = A(20, 0, -4), rl = A(-10, 0, 4), la = A(-6, 0, -12), ra = A(16, 0, 12), neck = A(-6, -2, 0) }), "SineInOut" },
		{ 1, body({ lean = 6, hip = V(0, -0.02, 0), ll = A(-8, 0, -3), rl = A(10, 0, 3), la = A(12, 0, -8), ra = A(-6, 0, 8), neck = A(0, 0, 0) }), "SineInOut" },
	}),
})

-- Маньяк (1.6 с): тяжело, сначала заносит правую ногу на подоконник, подтягивается на руках,
-- перекидывает левую, слезает и грузно встаёт.
OneShot.KillerVault = Clip.new({
	Duration = 1.6,
	FadeIn = 0.12,
	FadeOut = 0.22,
	Keys = timed(1.6, {
		{ 0, body({ lean = 6, ll = A(0, 0, -3), rl = A(0, 0, 3), la = A(6, 0, -9), ra = A(16, 0, 12), neck = A(0, 0, 0) }) },
		{ 0.14, body({ lean = 16, turn = -6, roll = -4, hip = V(0, -0.06, 0), ll = A(-6, 0, -4), rl = A(118, 0, 8), la = A(70, 0, -14), ra = A(64, 0, 16), neck = A(10, 6, 0) }), "SineInOut" },
		{ 0.32, body({ lean = 34, turn = -4, roll = -6, hip = V(0, 0.04, 0), ll = A(-28, 0, -6), rl = A(88, 0, 10), la = A(60, 0, -6), ra = A(56, 0, 8), neck = A(22, 4, 0) }), "SineInOut" },
		{ 0.5, body({ lean = 26, turn = 6, roll = 4, hip = V(0, 0.08, 0), ll = A(70, 0, -14), rl = A(30, 0, 10), la = A(28, 0, -4), ra = A(30, 0, 6), neck = A(18, -4, 0) }), "SineInOut" },
		{ 0.7, body({ lean = 14, turn = 4, roll = 2, ll = A(46, 0, -8), rl = A(8, 0, 6), la = A(36, 0, -16), ra = A(44, 0, 18), neck = A(6, -2, 0) }), "SineInOut" },
		{ 0.86, body({ lean = 12, hip = V(0, -0.5, 0), ll = A(24, 0, -6), rl = A(-14, 0, 5), la = A(14, 0, -12), ra = A(22, 0, 14), neck = A(-4, 0, 0) }), "SineInOut" },
		{ 1, body({ lean = 7, ll = A(2, 0, -3), rl = A(-2, 0, 3), la = A(6, 0, -9), ra = A(16, 0, 12), neck = A(0, 0, 0) }), "SineInOut" },
	}),
})

return Clips
