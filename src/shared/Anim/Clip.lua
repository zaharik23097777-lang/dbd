-- Ключевые клипы для R6: позы по времени с плавностью (easing) на каждом ключе.
--
-- КАК АВТОРИТЬ КЛИП
--   local A = Rig.A  -- углы в градусах: +X вперёд, +Y влево, +Z вправо; корпус вперёд — МИНУС X
--   local swing = Clip.new({
--       Duration = 0.7,          -- секунды (по умолчанию — время последнего ключа)
--       Loop = false,            -- true: после конца снова с начала (сегмент последний -> первый)
--       FadeIn = 0.1,            -- секунды, за которые слой плавно накрывает базовую позу
--       FadeOut = 0.25,          -- ...и плавно отдаёт её обратно в конце (без рывка в походку)
--       Additive = false,        -- true: позы ключей — ДОБАВКИ к базовой позе (вздрагивание на бегу)
--       Stiffness = 1.6,         -- множитель частоты пружин суставов, пока играет (резкие удары)
--       Keys = {
--           { T = 0,    Pose = { RArm = A(40, 0, 12), Root = A(0, 10, 0) } },
--           { T = 0.25, Pose = { RArm = A(175, 0, 12), Root = A(4, 14, 0) }, Ease = "SineInOut" },
--           { T = 0.38, Pose = { RArm = A(10, 0, 12), Root = A(-14, -12, 0) }, Ease = "CubicIn" },
--       },
--   })
--   Ease ключа описывает, КАК поза ПРИХОДИТ в этот ключ (сегмент от предыдущего ключа к этому).
--   Имена: Linear, SineIn/Out/InOut, QuadIn/Out/InOut, CubicIn/Out/InOut, BackIn/Out/InOut,
--   Elastic (мягкая пружинка в конце); можно передать и свою функцию (u: 0..1) -> число.
--   Back и Elastic выходят за 0..1 — поворот при этом честно экстраполируется (перелёт).
--
--   Каждый сустав — отдельная дорожка: значение берётся из ключей, где сустав указан,
--   и интерполируется между ними (до первого и после последнего — держится). Поэтому
--   в первом ключе укажите ВСЕ суставы, которые клип двигает. Не указанные ни в одном ключе
--   суставы остаются за базовой позой (походкой). Соседние ключи одного сустава должны
--   отличаться меньше чем на 180° (иначе поворот пойдёт коротким путём) — добавьте
--   промежуточный ключ. Clip.check проверяет это в тестах.
--
--   Ритм удара удобнее собирать строителем Clip.motion (подготовка -> действие -> захлёст ->
--   возврат), см. ниже. Пружины суставов (Spring.lua) добавят инерцию сверху — ключи можно
--   ставить «чисто», лёгкий перелёт появится сам.
--
-- ИСПОЛЬЗОВАНИЕ
--   Клип совместим с Poses.OneShot: у него есть Duration и Fn(a) (a — прогресс 0..1).
--   Poses.OneShot.Swing = swing   -- Animator сам накладывает его с FadeIn/FadeOut/Additive/Stiffness
--   Clip.sample(clip, t)          -- поза в момент t (секунды); для зацикленных Action: Clip.sample(loop, t)
--   Clip.layer(dst, layer, w)     -- наложить позу-слой с весом (на месте, в свою таблицу dst)
-- Возвращаемая поза — общая таблица клипа (без выделения памяти каждый кадр): прочитайте
-- или скопируйте её до следующего вызова для этого же клипа.
local Rig = require(script.Parent.Rig)

local Clip = {}

export type Pose = { [string]: any }
export type EaseFn = (number) -> number
export type Ease = string | EaseFn
export type Key = { T: number, Pose: Pose, Ease: Ease? }
export type Def = {
	Duration: number?,
	Loop: boolean?,
	FadeIn: number?,
	FadeOut: number?,
	Additive: boolean?,
	Stiffness: number?,
	Keys: { Key },
}

type Track = {
	Joint: string,
	IsVector: boolean,
	Times: { number },
	Values: { any },
	Eases: { EaseFn },
	-- для поворотов: ось и угол перехода от ключа i к ключу i+1 (i = n — переход к первому при Loop)
	Axes: { Vector3 },
	Angles: { number },
}

export type Clip = {
	Duration: number,
	Loop: boolean,
	FadeIn: number,
	FadeOut: number,
	FadeInEase: EaseFn,
	FadeOutEase: EaseFn,
	Additive: boolean,
	Stiffness: number?,
	Tracks: { Track },
	Out: Pose,
	Fn: (number, any?) -> Pose,
}

local pi, sin, cos, exp, clamp = math.pi, math.sin, math.cos, math.exp, math.clamp
local IDENTITY = CFrame.identity
local ZERO = Vector3.zero

------------------------------------------------------------------------
-- Плавности: u 0..1 -> 0..1 (Back/Elastic — с выходом за пределы)
------------------------------------------------------------------------

local C1 = 1.70158
local C2 = C1 * 1.525
local C3 = C1 + 1

local Ease: { [string]: EaseFn } = {
	Linear = function(u)
		return u
	end,
	SineIn = function(u)
		return 1 - cos(u * pi / 2)
	end,
	SineOut = function(u)
		return sin(u * pi / 2)
	end,
	SineInOut = function(u)
		return (1 - cos(pi * u)) / 2
	end,
	QuadIn = function(u)
		return u * u
	end,
	QuadOut = function(u)
		return 1 - (1 - u) * (1 - u)
	end,
	QuadInOut = function(u)
		return u < 0.5 and 2 * u * u or 1 - (-2 * u + 2) ^ 2 / 2
	end,
	CubicIn = function(u)
		return u * u * u
	end,
	CubicOut = function(u)
		return 1 - (1 - u) ^ 3
	end,
	CubicInOut = function(u)
		return u < 0.5 and 4 * u * u * u or 1 - (-2 * u + 2) ^ 3 / 2
	end,
	BackIn = function(u)
		return C3 * u * u * u - C1 * u * u
	end,
	BackOut = function(u)
		local v = u - 1
		return 1 + C3 * v * v * v + C1 * v * v
	end,
	BackInOut = function(u)
		if u < 0.5 then
			return ((2 * u) ^ 2 * ((C2 + 1) * 2 * u - C2)) / 2
		end
		return ((2 * u - 2) ^ 2 * ((C2 + 1) * (u * 2 - 2) + C2) + 2) / 2
	end,
	-- Мягкая пружинка: перелёт ~13%, затем ~2% недолёт и покой; ровно 0 и 1 на концах
	Elastic = function(u)
		return 1 - (exp(-6 * u) * cos(3 * pi * u) - u * exp(-6) * cos(3 * pi))
	end,
}
Clip.Ease = Ease

local function easeFn(e: Ease?): EaseFn
	if e == nil then
		return Ease.Linear
	elseif type(e) == "function" then
		return e
	end
	local fn = Ease[e :: string]
	assert(fn, "Clip: неизвестная плавность " .. tostring(e))
	return fn
end
Clip.easeFn = easeFn

------------------------------------------------------------------------
-- Построение
------------------------------------------------------------------------

-- Переход a -> b кратчайшим путём: ось и угол (0..π)
local function segmentDelta(a: CFrame, b: CFrame): (Vector3, number)
	local v = Rig.rotVec(a:Inverse() * b)
	local angle = v.Magnitude
	if angle < 1e-6 then
		return ZERO, 0
	end
	return v / angle, angle
end

local function buildTrack(joint: string, keys: { Key }, loop: boolean): Track?
	local track: Track = {
		Joint = joint,
		IsVector = joint == "RootPos",
		Times = {},
		Values = {},
		Eases = {},
		Axes = {},
		Angles = {},
	}
	for _, key in keys do
		local v = key.Pose[joint]
		if v ~= nil then
			table.insert(track.Times, key.T)
			table.insert(track.Values, v)
			table.insert(track.Eases, easeFn(key.Ease))
		end
	end
	local n = #track.Times
	if n == 0 then
		return nil
	end
	if not track.IsVector then
		for i = 1, n do
			local j = i < n and i + 1 or (loop and 1 or nil)
			if j then
				track.Axes[i], track.Angles[i] = segmentDelta(track.Values[i], track.Values[j])
			else
				track.Axes[i], track.Angles[i] = ZERO, 0
			end
		end
	end
	return track
end

function Clip.new(def: Def): Clip
	local keys = table.clone(def.Keys)
	assert(#keys > 0, "Clip: нужен хотя бы один ключ")
	table.sort(keys, function(a, b)
		return a.T < b.T
	end)
	local loop = def.Loop == true
	local duration = def.Duration or keys[#keys].T
	assert(duration > 0, "Clip: Duration должна быть больше нуля")
	local joints = {}
	for _, key in keys do
		for joint in key.Pose do
			joints[joint] = true
		end
	end
	local tracks = {}
	for joint in joints do
		local track = buildTrack(joint, keys, loop)
		if track then
			table.insert(tracks, track)
		end
	end
	table.sort(tracks, function(a, b)
		return a.Joint < b.Joint
	end)
	local clip: Clip = {
		Duration = duration,
		Loop = loop,
		FadeIn = def.FadeIn or 0,
		FadeOut = def.FadeOut or 0,
		FadeInEase = Ease.SineInOut,
		FadeOutEase = Ease.SineInOut,
		Additive = def.Additive == true,
		Stiffness = def.Stiffness,
		Tracks = tracks,
		Out = {},
		Fn = nil :: any,
	}
	clip.Fn = function(a: number): Pose
		return Clip.sample(clip, a * clip.Duration)
	end
	return clip
end

------------------------------------------------------------------------
-- Выборка
------------------------------------------------------------------------

local function interp(track: Track, i: number, j: number, a: number): any
	local from = track.Values[i]
	if track.IsVector then
		local to = track.Values[j]
		return from + (to - from) * a
	end
	local angle = track.Angles[i]
	if angle == 0 or a == 0 then
		return from
	end
	return from * CFrame.fromAxisAngle(track.Axes[i], angle * a)
end

local function sampleTrack(track: Track, t: number, duration: number, loop: boolean): any
	local times = track.Times
	local n = #times
	if n == 1 then
		return track.Values[1]
	end
	if t < times[1] or t >= times[n] then
		if not loop then
			return t < times[1] and track.Values[1] or track.Values[n]
		end
		-- сегмент «последний -> первый» через конец цикла
		local span = duration - times[n] + times[1]
		local local_t = t >= times[n] and t - times[n] or t + duration - times[n]
		local u = span > 1e-6 and clamp(local_t / span, 0, 1) or 1
		return interp(track, n, 1, track.Eases[1](u))
	end
	for i = 1, n - 1 do
		local t1 = times[i + 1]
		if t < t1 then
			local t0 = times[i]
			local u = t1 > t0 and (t - t0) / (t1 - t0) or 1
			return interp(track, i, i + 1, track.Eases[i + 1](u))
		end
	end
	return track.Values[n]
end

-- Поза клипа в момент t (секунды). Пишет в out (по умолчанию — общая таблица клипа).
function Clip.sample(clip: Clip, t: number, out: Pose?): Pose
	local dst = out or clip.Out
	local d = clip.Duration
	if clip.Loop then
		t = t % d
	else
		t = clamp(t, 0, d)
	end
	for _, track in clip.Tracks do
		dst[track.Joint] = sampleTrack(track, t, d, clip.Loop)
	end
	return dst
end

-- Вес слоя в момент t (секунды от начала): плавный вход FadeIn и выход FadeOut.
-- Работает для любого описания с полями Duration/FadeIn/FadeOut (и для старых OneShot).
function Clip.weight(def: any, t: number): number
	local w = 1
	local fadeIn = def.FadeIn or 0
	if fadeIn > 0 and t < fadeIn then
		w = (def.FadeInEase or Ease.SineInOut)(clamp(t / fadeIn, 0, 1))
	end
	local fadeOut = def.FadeOut or 0
	if fadeOut > 0 and not def.Loop then
		local left = def.Duration - t
		if left < fadeOut then
			w = math.min(w, (def.FadeOutEase or Ease.SineInOut)(clamp(left / fadeOut, 0, 1)))
		end
	end
	return clamp(w, 0, 1)
end

------------------------------------------------------------------------
-- Слои
------------------------------------------------------------------------

local LAYER_KEYS = { "Root", "Neck", "LArm", "RArm", "LLeg", "RLeg", "RootPos" }
Clip.Keys = LAYER_KEYS

-- Копия позы в свою таблицу dst (без выделения памяти)
function Clip.copy(src: Pose, dst: Pose): Pose
	for _, k in LAYER_KEYS do
		dst[k] = src[k]
	end
	return dst
end

-- Наложить позу layer на dst с весом w (dst меняется на месте — это должна быть ВАША таблица).
--   обычный слой: сустав плавно заменяется позой слоя (w = 1 — полностью);
--   additive: поворот слоя ДОБАВЛЯЕТСЯ к базовому (base * delta^w), RootPos складывается.
-- Суставы, которых нет в layer, не трогаются.
function Clip.layer(dst: Pose, layer: Pose, w: number, additive: boolean?): Pose
	if w <= 0 then
		return dst
	end
	for _, k in LAYER_KEYS do
		local v = layer[k]
		if v == nil then
			continue
		end
		local base = dst[k]
		if k == "RootPos" then
			local b = base or ZERO
			if additive then
				dst[k] = b + v * w
			else
				dst[k] = w >= 1 and v or b + (v - b) * w
			end
		elseif additive then
			dst[k] = (base or IDENTITY) * (w >= 1 and v or IDENTITY:Lerp(v, w))
		elseif w >= 1 then
			dst[k] = v
		else
			dst[k] = (base or IDENTITY):Lerp(v, w)
		end
	end
	return dst
end

-- Смешать две позы: out = a·(1-w) + b·w по каждому суставу (для смены походок и т.п.)
function Clip.blend(a: Pose, b: Pose, w: number, out: Pose): Pose
	for _, k in LAYER_KEYS do
		local va, vb = a[k], b[k]
		if va == nil and vb == nil then
			out[k] = nil
		elseif k == "RootPos" then
			local pa, pb = va or ZERO, vb or ZERO
			out[k] = pa + (pb - pa) * w
		else
			out[k] = (va or IDENTITY):Lerp(vb or IDENTITY, w)
		end
	end
	return out
end

------------------------------------------------------------------------
-- Строитель удара: подготовка -> действие -> захлёст -> (пауза) -> возврат
------------------------------------------------------------------------

export type Phase = { Time: number, Pose: Pose?, Ease: Ease? }
export type MotionDef = {
	Anticipation: Phase?, -- замах/подготовка: поза набирается из базовой за Time
	Action: Phase, -- само действие: быстрый переход в позу (обычно CubicIn/QuadIn)
	FollowThrough: Phase?, -- захлёст за точку удара (обычно CubicOut/BackOut)
	Hold: number?, -- секунды держать последнюю позу
	Recover: Phase?, -- плавный возврат в базовую позу (вес слоя -> 0)
	Additive: boolean?,
	Stiffness: number?,
}

-- Каждая фаза без Pose держит предыдущую. Суставы, впервые появившиеся в поздней фазе,
-- копируются в ранние (держатся с начала), поэтому удобнее перечислять всё в Anticipation.
function Clip.motion(def: MotionDef): Clip
	local phases = {}
	if def.Anticipation then
		table.insert(phases, def.Anticipation)
	end
	table.insert(phases, def.Action)
	if def.FollowThrough then
		table.insert(phases, def.FollowThrough)
	end
	-- накопительные позы: каждая фаза наследует суставы предыдущей
	local poses = {}
	local acc = {}
	for i, ph in phases do
		for k, v in ph.Pose or {} do
			acc[k] = v
		end
		poses[i] = table.clone(acc)
	end
	for i = #phases - 1, 1, -1 do
		for k, v in poses[i + 1] do
			if poses[i][k] == nil then
				poses[i][k] = v
			end
		end
	end
	local keys = {}
	local t = 0
	for i, ph in phases do
		t += ph.Time
		table.insert(keys, { T = t, Pose = poses[i], Ease = i == 1 and "Linear" or ph.Ease })
	end
	if def.Hold and def.Hold > 0 then
		t += def.Hold
		table.insert(keys, { T = t, Pose = poses[#poses], Ease = "Linear" })
	end
	local recover = def.Recover
	local first = phases[1]
	local clip = Clip.new({
		Duration = t + (recover and recover.Time or 0),
		FadeIn = first.Time,
		FadeOut = recover and recover.Time or 0,
		Additive = def.Additive,
		Stiffness = def.Stiffness,
		Keys = keys,
	})
	clip.FadeInEase = easeFn(first.Ease or "SineInOut")
	clip.FadeOutEase = easeFn(recover and recover.Ease or "SineInOut")
	return clip
end

------------------------------------------------------------------------
-- Проверка (для тестов): шаги > 175° между ключами, нечисла
------------------------------------------------------------------------

function Clip.check(clip: Clip): { string }
	local issues = {}
	for _, track in clip.Tracks do
		for i, v in track.Values do
			if track.IsVector then
				if v.X ~= v.X or v.Y ~= v.Y or v.Z ~= v.Z then
					table.insert(issues, ("%s: ключ %d — не число"):format(track.Joint, i))
				end
			elseif track.Angles[i] and track.Angles[i] > math.rad(175) then
				table.insert(issues, ("%s: ключи %d->%d отличаются почти на 180°"):format(track.Joint, i, i + 1))
			end
		end
	end
	return issues
end

return Clip
