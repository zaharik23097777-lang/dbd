-- Общие помощники стен для зданий и оформления ячеек.
-- Стена (тип Wall): CF — центр основания (y = 0), длина вдоль локальной X, толщина вдоль локальной Z.
-- Сталкивается только корпус W.core (те же коробки, что и раньше: сегменты вокруг проёмов + подоконники
-- Common.windowSill высотой ровно 3); доски, рамы, обломки и прочее — декор без столкновений.
local Kit = require(script.Parent.Parent.Kit)
local Common = require(script.Parent.Common)

local P = Kit.Palette
local Mat = Kit.Mat
local A = Kit.A
local V = Vector3.new
local C = CFrame.new

local W = {}

W.DECOR = { Decor = true }
-- Крупные видимые детали без столкновений, но с тенью (крыши навесов, трубы)
W.SOLID = { CanCollide = false, CanQuery = false, CanTouch = false }
local DECOR = W.DECOR

export type Opening = { Center: number, Width: number, Sill: number, Top: number }
export type Wall = { CF: CFrame, Length: number, Height: number, Thick: number, Openings: { Opening } }
-- Прямоугольник на стене: x0, x1, y0, y1 (локальные координаты стены)
export type Rect = { number }

function W.wall(cf: CFrame, length: number, height: number, thick: number, openings: { Opening }?): Wall
	local list = table.clone(openings or {})
	table.sort(list, function(a, b)
		return a.Center < b.Center
	end)
	return { CF = cf, Length = length, Height = height, Thick = thick, Openings = list }
end

-- Сплошной корпус стены (map.Walls) с проёмами; Sill > 0 — окно с подоконником Common.windowSill.
function W.core(map, w: Wall, color: Color3, material: Enum.Material): { BasePart }
	local parts = {}
	local function seg(x0: number, x1: number, y0: number, y1: number)
		if x1 - x0 > 0.05 and y1 - y0 > 0.05 then
			local p = Kit.box(map.Walls, w.CF * C((x0 + x1) / 2, (y0 + y1) / 2, 0), V(x1 - x0, y1 - y0, w.Thick), color, material)
			p.Name = "Wall"
			table.insert(parts, p)
		end
	end
	local x = -w.Length / 2
	for _, o in w.Openings do
		local x0, x1 = o.Center - o.Width / 2, o.Center + o.Width / 2
		seg(x, x0, 0, w.Height)
		seg(x0, x1, o.Top, w.Height)
		if o.Sill > 0 then
			Common.windowSill(map, w.CF * C(o.Center, 0, 0), o.Width, w.Thick, color, material)
		end
		x = x1
	end
	seg(x, w.Length / 2, 0, w.Height)
	return parts
end

-- Куски горизонтальной полосы [y0, y1] вдоль стены без проёмов (под окном и над проёмом — отдельные куски)
function W.band(w: Wall, y0: number, y1: number): { Rect }
	local out: { Rect } = {}
	local function add(x0: number, x1: number, a: number, b: number)
		if x1 - x0 > 0.2 and b - a > 0.05 then
			table.insert(out, { x0, x1, a, b })
		end
	end
	local x = -w.Length / 2
	for _, o in w.Openings do
		local x0, x1 = o.Center - o.Width / 2, o.Center + o.Width / 2
		if y1 > o.Sill and y0 < o.Top then
			add(x, x0, y0, y1)
			if y0 < o.Sill then
				add(x0, x1, y0, math.min(y1, o.Sill))
			end
			if y1 > o.Top then
				add(x0, x1, math.max(y0, o.Top), y1)
			end
			x = x1
		end
	end
	add(x, w.Length / 2, y0, y1)
	return out
end

-- Сплошные (на всю высоту полосы) куски — туда можно ставить стойки, швы, заплатки
function W.solid(w: Wall, y0: number, y1: number): { Rect }
	local out = {}
	for _, r in W.band(w, y0, y1) do
		if r[3] <= y0 and r[4] >= y1 then
			table.insert(out, r)
		end
	end
	return out
end

-- Случайная точка на сплошной части стены (с отступом от краёв куска) или nil
function W.spot(w: Wall, rng: Random, y0: number, y1: number, margin: number): (number?, number)
	local list = {}
	for _, r in W.solid(w, y0, y1) do
		if r[2] - r[1] > margin * 2 then
			table.insert(list, r)
		end
	end
	local y = rng:NextNumber(y0, y1)
	if #list == 0 then
		return nil, y
	end
	local r = list[rng:NextInteger(1, #list)]
	return rng:NextNumber(r[1] + margin, r[2] - margin), y
end

export type BoardOpts = {
	Rng: Random,
	Color: Color3,
	Row: number?, -- ширина доски (шаг рядов)
	Gap: number?, -- щель между досками
	Y0: number?,
	Y1: number?,
	Missing: number?, -- вероятность выпавшей доски
	Broken: number?, -- вероятность сорванной доски (висит на одном гвозде)
	MaxLen: number?, -- длинные ряды режутся на доски не длиннее этого
}

-- Обшивка горизонтальными досками грани side (±1 по локальной Z): щели, выпавшие и сорванные доски.
function W.boards(parent: Instance, w: Wall, side: number, o: BoardOpts)
	local rng = o.Rng
	local row, gap, depth = o.Row or 0.9, o.Gap or 0.1, 0.14
	local y0, y1 = o.Y0 or 0, o.Y1 or w.Height
	local mat = Mat.WoodPlanks
	local n = math.max(1, math.floor((y1 - y0) / row + 0.5))
	local step = (y1 - y0) / n
	local z = side * (w.Thick / 2 + depth / 2)
	local function plank(x0: number, x1: number, ya: number, yb: number)
		local len, cy = x1 - x0, (ya + yb) / 2
		local color = Kit.jitter(o.Color, 0.09, rng)
		local size = V(len, yb - ya, depth)
		if len > 2.2 and rng:NextNumber() < (o.Broken or 0) then
			-- одна половина прибита, вторая повисла на гвозде (чуть отстаёт от стены, чтобы не слипаться с соседней)
			local cut = x0 + len * rng:NextNumber(0.35, 0.6)
			Kit.box(parent, w.CF * C((x0 + cut) / 2, cy, z), V(cut - x0, size.Y, depth), color, mat, DECOR)
			local rest = x1 - cut
			local drop = math.deg(math.asin(math.clamp((cy - 0.15) / rest, 0, 1)))
			local ang = math.min(rng:NextNumber(12, 30), drop)
			local flip = rng:NextNumber() < 0.5
			local pivot = flip and C(cut, cy, z + side * depth * 0.9) or C(x1, cy, z + side * depth * 0.9)
			local dir = flip and 1 or -1
			Kit.box(parent, w.CF * pivot * A(0, 0, -dir * ang) * C(dir * rest / 2, 0, 0), V(rest, size.Y, depth), Kit.dark(color, 0.08), mat, DECOR)
		else
			Kit.box(parent, w.CF * C((x0 + x1) / 2, cy, z + rng:NextNumber(-0.02, 0.02)), size, color, mat, DECOR)
		end
	end
	for i = 0, n - 1 do
		local ya = y0 + step * i + gap / 2
		local yb = ya + step - gap
		for _, r in W.band(w, ya, yb) do
			if rng:NextNumber() >= (o.Missing or 0) then
				local len = r[2] - r[1]
				local pieces = o.MaxLen and math.max(1, math.ceil(len / o.MaxLen)) or 1
				local x = r[1]
				for k = 1, pieces do
					local x1 = k == pieces and r[2] or r[1] + len * (k / pieces) + rng:NextNumber(-0.6, 0.6)
					plank(x + (k > 1 and 0.04 or 0), x1, r[3], r[4])
					x = x1
				end
			end
		end
	end
end

-- Рама проёма: косяки и перемычка насквозь (выступают из обеих граней на proud), у окна — отлив.
-- Края рамы на 0.05 заходят в проём, чтобы не совпадать с торцами корпуса.
function W.frame(parent: Instance, w: Wall, o: Opening, color: Color3, material: Enum.Material?, proud: number?)
	local m = material or Mat.Wood
	local pr = proud or 0.25
	local jw = 0.35
	local x0, x1 = o.Center - o.Width / 2, o.Center + o.Width / 2
	local depth = w.Thick + pr * 2
	local jh = o.Top - o.Sill
	for _, s in { -1, 1 } do
		local xe = s < 0 and x0 or x1
		Kit.box(parent, w.CF * C(xe + s * (jw / 2 - 0.05), o.Sill + jh / 2, 0), V(jw, jh, depth), color, m, DECOR)
	end
	Kit.box(parent, w.CF * C(o.Center, o.Top + jw / 2 - 0.05, 0), V(o.Width + jw * 2 + 0.1, jw, depth + 0.06), Kit.dark(color, 0.12), m, DECOR)
	if o.Sill > 0 then
		Kit.box(parent, w.CF * C(o.Center, o.Sill + 0.07, 0), V(o.Width + jw * 2 + 0.3, 0.16, depth + 0.3), Kit.dark(color, 0.05), m, DECOR)
	end
end

-- Осколки стекла, торчащие из углов оконной рамы (в плоскости окна)
local GLASS = Color3.fromRGB(150, 168, 172)
function W.shards(parent: Instance, w: Wall, o: Opening, rng: Random, count: number)
	local x0, x1 = o.Center - o.Width / 2 + 0.05, o.Center + o.Width / 2 - 0.05
	for _ = 1, count do
		local left, top = rng:NextNumber() < 0.5, rng:NextNumber() < 0.6
		local h, d = rng:NextNumber(0.45, 1.1), rng:NextNumber(0.3, 0.7)
		local x = left and x0 + d / 2 or x1 - d / 2
		local y = top and o.Top - 0.05 - h / 2 or o.Sill + 0.15 + h / 2
		-- клин: прямой угол — в углу рамы
		local rot = A(0, left and -90 or 90, 0)
		if top then
			rot = A(0, left and 90 or -90, 0) * A(180, 0, 0)
		end
		Kit.wedge(parent, w.CF * C(x, y, rng:NextNumber(-0.1, 0.1)) * rot, V(0.05, h, d), GLASS, Mat.Glass, { Decor = true, Transparency = 0.35 })
	end
end

-- Рваный верх над корпусом: ступенчатый профиль (высота шагает на ±1 ступень, до 3 ступеней по maxStep/3),
-- соседние одинаковые ступени слиты в одну деталь. width — средняя ширина ступени,
-- clear — участок по X, который оставить ровным.
function W.jagged(parent: Instance, rng: Random, w: Wall, color: Color3, material: Enum.Material, maxStep: number, width: number, clear: { number }?)
	local unit = maxStep / 3
	local half = w.Length / 2
	local level = rng:NextInteger(0, 3)
	local x, runStart, runLevel = -half, -half, -1
	local function flush(x1: number)
		if runLevel > 0 and x1 - runStart > 0.05 then
			local h = runLevel * unit
			Kit.box(parent, w.CF * C((runStart + x1) / 2, w.Height + h / 2, 0), V(x1 - runStart, h, w.Thick), Kit.jitter(color, 0.03, rng), material, DECOR)
		end
	end
	while x < half - 1e-3 do
		local wd = math.min(rng:NextNumber(0.6, 1.4) * width, half - x)
		level = math.clamp(level + (rng:NextNumber() < 0.5 and -1 or 1), 0, 3)
		local lv = (clear and x < clear[2] and x + wd > clear[1]) and 0 or level
		if lv ~= runLevel then
			flush(x)
			runStart, runLevel = x, lv
		end
		x += wd
	end
	flush(half)
end

-- Неровное пятно штукатурки (или другого покрытия) на грани side: два перекрывающихся куска
function W.patch(parent: Instance, rng: Random, w: Wall, side: number, x: number, y: number, size: Vector2, color: Color3, material: Enum.Material)
	local z = side * w.Thick / 2
	Kit.box(parent, w.CF * C(x, y, z + side * 0.02), V(size.X, size.Y, 0.04), Kit.jitter(color, 0.04, rng), material, DECOR)
	local function off(): number
		return (rng:NextNumber() < 0.5 and -1 or 1) * rng:NextNumber(0.3, 0.45)
	end
	Kit.box(parent, w.CF * C(x + off() * size.X, y + off() * size.Y, z + side * 0.025), V(size.X * 0.6, size.Y * 0.7, 0.05), Kit.jitter(color, 0.06, rng), material, DECOR)
end

-- Обломки у основания: n кирпичей/кусков и куча щебня с одной стороны
function W.debris(parent: Instance, rng: Random, w: Wall, color: Color3, material: Enum.Material, n: number, size: Vector3)
	for _ = 1, n do
		local s = rng:NextNumber() < 0.5 and -1 or 1
		local x = rng:NextNumber(-w.Length / 2 + 0.4, w.Length / 2 - 0.4)
		local z = s * (w.Thick / 2 + rng:NextNumber(0.3, 1.3))
		local tilt = rng:NextNumber() < 0.3 and rng:NextNumber(15, 35) or 0
		Kit.box(parent, w.CF * C(x, size.Y / 2 + tilt / 120, z) * A(tilt, rng:NextNumber(0, 180), 0), size, Kit.jitter(color, 0.08, rng), material, DECOR)
	end
	local s = rng:NextNumber() < 0.5 and -1 or 1
	local x = rng:NextNumber(-w.Length / 2 + 1, w.Length / 2 - 1)
	-- клин высокой стороной к стене
	Kit.wedge(parent, w.CF * C(x, 0.3, s * (w.Thick / 2 + 0.55)) * A(0, s > 0 and 180 or 0, 0), V(rng:NextNumber(1.4, 2.2), 0.6, 1.1), Kit.jitter(P.DarkConcrete, 0.06, rng), Mat.Slate, DECOR)
end

return W
