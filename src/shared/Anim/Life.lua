-- Мелкие «живые» движения без состояния (зависят только от времени и зерна персонажа):
-- перенос веса, оглядывания, вспышки усилия, редкие события (вздрог, рывок).
-- seed (0..1) у каждого персонажа свой — иначе все двигались бы синхронно.
local Life = {}

local sin, floor, clamp = math.sin, math.floor, math.clamp

-- Псевдослучайное 0..1 от числа
function Life.hash(x: number): number
	local s = sin(x * 12.9898 + 78.233) * 43758.5453
	return s - floor(s)
end
local hash = Life.hash

function Life.smoothstep(a: number, b: number, x: number): number
	local t = clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end
local smoothstep = Life.smoothstep

-- Плавный перенос веса (-1 — на левую ногу, +1 — на правую) раз в period секунд
function Life.weightShift(t: number, seed: number, period: number): number
	local tt = t / period + seed * 13.7
	local slot = floor(tt)
	local function target(i: number): number
		local side = hash(i + seed * 101) > 0.5 and 1 or -1
		return side * (0.35 + 0.65 * hash(i * 1.7 + 3.1))
	end
	local a, b = target(slot - 1), target(slot)
	return a + (b - a) * smoothstep(0, 0.35, tt - slot)
end

-- Иногда оглядывается: (поворот, наклон) головы в градусах
function Life.glance(t: number, seed: number, period: number, chance: number, maxYaw: number): (number, number)
	local tt = t / period + seed * 7.3
	local slot = floor(tt)
	if hash(slot * 3.3 + seed * 57) > chance then
		return 0, 0
	end
	local f = tt - slot
	local w = smoothstep(0.05, 0.25, f) * (1 - smoothstep(0.7, 0.92, f))
	local side = hash(slot * 5.1 + 1.7) > 0.5 and 1 or -1
	local yaw = side * maxYaw * (0.45 + 0.55 * hash(slot * 7.7 + 2.9))
	local pitch = (hash(slot * 2.3 + 9.1) - 0.45) * 16
	return yaw * w, pitch * w
end

-- Редкое короткое событие: огибающая 0..1 (быстрый вход за attack, спад за release, доли окна).
-- Раз в period секунд, с вероятностью chance.
function Life.event(t: number, seed: number, period: number, chance: number, attack: number, release: number): number
	local tt = t / period + seed * 3.1
	local slot = floor(tt)
	if hash(slot * 4.7 + seed * 23) > chance then
		return 0
	end
	local f = tt - slot
	local start = 0.15 + 0.5 * hash(slot * 1.3 + 0.7)
	if f < start then
		return 0
	end
	return smoothstep(start, start + attack, f) * (1 - smoothstep(start + attack, start + attack + release, f))
end

-- Неровные вспышки усилия 0..1 (борьба, дёрганья): несколько несоизмеримых волн
function Life.bursts(t: number, seed: number): number
	local s = seed * 31
	local v = 0.45 + 0.55 * sin(t * 1.3 + s) + 0.35 * sin(t * 2.9 + s * 1.7) + 0.2 * sin(t * 5.3 + s * 0.3)
	return clamp(v, 0, 1)
end

return Life
