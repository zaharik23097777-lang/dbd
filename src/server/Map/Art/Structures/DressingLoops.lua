-- Стенки «петель» (паллета, окно) и укрытия (у генератора, ниша со шкафчиками) в разных стилях:
-- дощатая стенка на столбах, кирпичная руина с рваным верхом, бетонные плиты с арматурой,
-- профнастил на столбах. Сталкивается только корпус стены (те же коробки, что и раньше), остальное — декор.
local Kit = require(script.Parent.Parent.Kit)
local Common = require(script.Parent.Common)
local W = require(script.Parent.BuildingWalls)

local P = Kit.Palette
local Mat = Kit.Mat
local A = Kit.A
local V = Vector3.new
local C = CFrame.new
local DECOR = W.DECOR

-- Clear — участок верха (по X стены), который оставить ровным (там сидит ворон);
-- Back = false — обратная грань закрыта (шкафчиками): на ней ничего не строим
type StyleOpts = { Clear: { number }?, Back: boolean? }
type Style = (map: any, rng: Random, w: W.Wall, front: number, opts: StyleOpts) -> ()

local SHEET_TONES = { Kit.dark(P.Rust, 0.15), P.DarkRust, Kit.dark(P.Steel, 0.45), Color3.fromRGB(62, 72, 74), Color3.fromRGB(92, 82, 60) }

-- Столбы на концах стены (не выходят за её торцы); при Back = false обратная грань остаётся ровной
local function posts(parent: Instance, rng: Random, w: W.Wall, front: number, color: Color3, back: boolean)
	local zMin = back and -(w.Thick / 2 + 0.25) or -(w.Thick / 2 - 0.02)
	local zMax = w.Thick / 2 + 0.25
	if front < 0 then
		zMin, zMax = -zMax, -zMin
	end
	for _, s in { -1, 1 } do
		local h = w.Height + 0.4 + rng:NextNumber(0, 0.4)
		Kit.box(parent, w.CF * C(s * (w.Length / 2 - 0.28), h / 2 - 0.1, (zMin + zMax) / 2) * A(0, 0, rng:NextNumber(-1, 1)), V(0.6, h, zMax - zMin), Kit.jitter(color, 0.06, rng), Mat.Wood, DECOR)
	end
end

-- Каркас на обратной грани: два ригеля (в обход проёмов)
local function rails(parent: Instance, rng: Random, w: W.Wall, side: number, color: Color3)
	local z = side * (w.Thick / 2 + 0.15)
	for _, y in { 1.3, w.Height - 1.3 } do
		for _, r in W.band(w, y - 0.2, y + 0.2) do
			Kit.box(parent, w.CF * C((r[1] + r[2]) / 2, y, z), V(r[2] - r[1] - 0.1, 0.4, 0.3), Kit.jitter(color, 0.05, rng), Mat.Wood, DECOR)
		end
	end
end

-- Дощатая стенка: доски с щелями на лицевой грани, ригели и раскос сзади, столбы
local function planks(map, rng: Random, w: W.Wall, front: number, opts: StyleOpts)
	local timber = Kit.jitter(P.DarkWood, 0.05, rng)
	W.core(map, w, Kit.jitter(Color3.fromRGB(48, 38, 30), 0.03, rng), Mat.WoodPlanks)
	W.boards(map.Decor, w, front, { Rng = rng, Color = Kit.jitter(P.OldWood, 0.05, rng), Row = 1.3, Gap = 0.14, Missing = 0.06, Broken = 0.15 })
	local back = opts.Back ~= false
	if back then
		rails(map.Decor, rng, w, -front, timber)
		if #w.Openings == 0 and w.Length >= 4 then
			local z = -front * (w.Thick / 2 + 0.12)
			local a = w.CF * C(-w.Length / 2 + 0.7, 1.4, z)
			local b = w.CF * C(w.Length / 2 - 0.7, w.Height - 1.4, z)
			Kit.bar(map.Decor, a.Position, b.Position, 0.24, Kit.dark(timber, 0.1), Mat.Wood, DECOR, 0.35)
		end
	end
	posts(map.Decor, rng, w, front, timber, back)
end

-- Кирпичная руина: рваный верх, остатки штукатурки, упавшие кирпичи и щебень
local function brick(map, rng: Random, w: W.Wall, _front: number, opts: StyleOpts)
	local color = Kit.jitter(P.Brick, 0.05, rng)
	W.core(map, w, color, Mat.Brick)
	W.jagged(map.Decor, rng, w, color, Mat.Brick, 1.5, 0.8, opts.Clear)
	if w.Length >= 5 then
		-- остатки старой штукатурки
		local x, y = W.spot(w, rng, 1.6, w.Height - 2, 1.4)
		if x then
			local side = rng:NextNumber() < 0.5 and -1 or 1
			W.patch(map.Decor, rng, w, side, x, y, Vector2.new(rng:NextNumber(1.4, 2.4), rng:NextNumber(1.2, 2.0)), Kit.dark(P.Plaster, 0.35), Mat.Plaster)
		end
	end
	W.debris(map.Decor, rng, w, color, Mat.Brick, math.clamp(math.floor(w.Length / 2.5), 1, 4), V(0.9, 0.38, 0.44))
end

-- Бетонные плиты: швы, отверстия от стяжек опалубки, обломанный верх с ржавой арматурой и потёками
local function concrete(map, rng: Random, w: W.Wall, _front: number, opts: StyleOpts)
	local color = Kit.jitter(P.Concrete, 0.04, rng)
	W.core(map, w, color, Mat.Concrete)
	for _, r in W.solid(w, 0, w.Height) do
		if r[2] - r[1] >= 6 then
			local x = (r[1] + r[2]) / 2 + rng:NextNumber(-1, 1)
			Kit.box(map.Decor, w.CF * C(x, w.Height / 2, 0), V(0.08, w.Height - 0.02, w.Thick + 0.02), Kit.dark(color, 0.35), Mat.Concrete, DECOR)
		end
	end
	local ty = w.Height * 0.62
	for _, r in W.solid(w, ty - 0.2, ty + 0.2) do
		local n = math.floor((r[2] - r[1]) / 3.2)
		for i = 1, n do
			local x = r[1] + (r[2] - r[1]) * i / (n + 1)
			Kit.cyl(map.Decor, w.CF * C(x, ty, 0) * A(0, 90, 0), w.Thick + 0.03, 0.22, Kit.dark(color, 0.55), Mat.Concrete, DECOR)
		end
	end
	W.jagged(map.Decor, rng, w, color, Mat.Concrete, 0.9, 1.6, opts.Clear)
	local clear = opts.Clear
	for i = 1, 2 do
		local x = rng:NextNumber(-w.Length / 2 + 0.5, w.Length / 2 - 0.5)
		if not (clear and x > clear[1] - 0.3 and x < clear[2] + 0.3) then
			local z = rng:NextNumber(-0.3, 0.3)
			local mid = w.CF * C(x + rng:NextNumber(-0.2, 0.2), w.Height + rng:NextNumber(0.7, 1.4), z)
			local tip = mid * C(rng:NextNumber(-0.6, 0.6), rng:NextNumber(0.1, 0.4), rng:NextNumber(-0.5, 0.5))
			Kit.rod(map.Decor, (w.CF * C(x, w.Height - 0.2, z)).Position, mid.Position, 0.12, P.DarkRust, Mat.CorrodedMetal, DECOR)
			Kit.rod(map.Decor, mid.Position, tip.Position, 0.12, P.DarkRust, Mat.CorrodedMetal, DECOR)
			if i == 1 then
				local s = rng:NextNumber() < 0.5 and -1 or 1
				Kit.box(map.Decor, w.CF * C(x, w.Height - 1, s * (w.Thick / 2 + 0.01)), V(0.2, 1.9, 0.02), Kit.jitter(P.Rust, 0.06, rng), Mat.CorrodedMetal, DECOR)
			end
		end
	end
	W.debris(map.Decor, rng, w, color, Mat.Concrete, 1, V(0.8, 0.45, 0.6))
end

-- Профнастил на столбах: листы с волнами на лицевой грани (в обход проёмов), ригели сзади
local function sheets(map, rng: Random, w: W.Wall, front: number, opts: StyleOpts)
	local timber = Kit.jitter(P.DarkWood, 0.05, rng)
	W.core(map, w, Kit.jitter(Color3.fromRGB(50, 44, 40), 0.03, rng), Mat.CorrodedMetal)
	local i = 0
	for _, r in W.band(w, 0.05, w.Height) do
		local len = r[2] - r[1]
		local n = math.max(1, math.floor(len / 3.3 + 0.5))
		local sw = len / n
		for k = 0, n - 1 do
			i += 1
			local a = math.max(r[1], r[1] + sw * k - 0.1)
			local b = math.min(r[2], r[1] + sw * (k + 1) + 0.1)
			local y1 = r[4] >= w.Height - 0.01 and r[4] + rng:NextNumber(0, 0.6) or r[4]
			local h = y1 - r[3]
			local color = Kit.jitter(SHEET_TONES[rng:NextInteger(1, #SHEET_TONES)], 0.05, rng)
			local sheet = w.CF * C((a + b) / 2, r[3] + h / 2, front * (w.Thick / 2 + 0.04 + (i % 2) * 0.07))
			Kit.box(map.Decor, sheet, V(b - a, h, 0.06), color, Mat.CorrodedMetal, DECOR)
			if b - a > 1.2 then
				for _, dx in { -0.25, 0.25 } do
					Kit.vcyl(map.Decor, sheet * C(dx * (b - a), 0, front * 0.04), h, 0.14, Kit.jitter(color, 0.03, rng), Mat.CorrodedMetal, DECOR)
				end
			end
		end
	end
	local back = opts.Back ~= false
	if back then
		rails(map.Decor, rng, w, -front, timber)
	end
	posts(map.Decor, rng, w, front, timber, back)
end

local STYLES: { Style } = { planks, brick, concrete, sheets }
local COVER: { Style } = { planks, brick, sheets }

local function pick(list: { Style }, rng: Random): Style
	return list[rng:NextInteger(1, #list)]
end

local Loops = {}

-- Петля с паллетой: две стенки по бокам проёма 5.6 и две поперечные «крылья»
function Loops.palletLoop(map, cf: CFrame, rng: Random)
	local style = pick(STYLES, rng)
	local f = rng:NextNumber() < 0.5 and -1 or 1
	style(map, rng, W.wall(cf * C(-5.6, 0, 0), 5.6, 8, 1.5), f, { Clear = { -0.8, 0.8 } })
	style(map, rng, W.wall(cf * C(5.6, 0, 0), 5.6, 8, 1.5), -f, {})
	style(map, rng, W.wall(cf * C(-8.6, 0, 4) * A(0, 90, 0), 8, 8, 1.5), 1, {})
	style(map, rng, W.wall(cf * C(8.6, 0, -4) * A(0, 90, 0), 8, 8, 1.5), -1, {})
	local upCF = cf * CFrame.new(-1.8, 3, 1) * A(0, 0, 78)
	Common.pallet(map, rng, upCF, cf * CFrame.new(0, 1.5, 0))
	table.insert(map.TrapSpots, cf * CFrame.new(0, 0, rng:NextNumber() < 0.5 and 3.5 or -3.5))
	table.insert(map.CrowSpots, cf * CFrame.new(-5.6, 8, 0))
end

-- Петля с окном: стена 18x10 с окном посередине и две боковые стенки
function Loops.windowLoop(map, cf: CFrame, rng: Random)
	local style = pick(STYLES, rng)
	local front = rng:NextNumber() < 0.5 and -1 or 1
	local main = W.wall(cf, 18, 10, 1.5, { { Center = 0, Width = 4, Sill = 3, Top = 7 } })
	style(map, rng, main, front, {})
	style(map, rng, W.wall(cf * C(-9.75, 0, -5) * A(0, 90, 0), 10, 10, 1.5), 1, {})
	style(map, rng, W.wall(cf * C(9.75, 0, 5) * A(0, 90, 0), 10, 10, 1.5), -1, {})
	-- рама с осколками, оторванная доска у окна и ещё одна под ним
	local o = main.Openings[1]
	local wood = Kit.jitter(P.DarkWood, 0.05, rng)
	W.frame(map.Decor, main, o, wood, Mat.Wood, 0.32)
	W.shards(map.Decor, main, o, rng, 3)
	local s = rng:NextNumber() < 0.5 and -1 or 1
	local side = rng:NextNumber() < 0.5 and -1 or 1
	local board = Kit.jitter(P.OldWood, 0.06, rng)
	Kit.box(map.Decor, main.CF * C(s * (o.Width / 2 + 0.85), 5.2, side * (main.Thick / 2 + 0.4)) * A(0, 0, s * rng:NextNumber(8, 20)), V(0.7, 3.6, 0.12), board, Mat.WoodPlanks, DECOR)
	Kit.box(map.Decor, main.CF * C(rng:NextNumber(-1.5, 1.5), 0.06, -side * rng:NextNumber(1.8, 2.6)) * A(0, rng:NextNumber(-40, 40), 0), V(0.7, 0.12, 3.4), Kit.dark(board, 0.1), Mat.WoodPlanks, DECOR)
	table.insert(map.TrapSpots, cf * CFrame.new(0, 0, -3))
end

-- Укрытие за генератором (генератор стоит в cf, стенка — сзади, лицом к нему)
function Loops.generatorCover(map, cf: CFrame, rng: Random)
	pick(COVER, rng)(map, rng, W.wall(cf * C(0, 0, 6.5), 10, 6, 1.5), -1, {})
end

-- Стенка с двумя шкафчиками (3.4 между центрами) под навесом
function Loops.lockerNook(map, cf: CFrame, rng: Random)
	local w = W.wall(cf * C(0, 0, 2), 8, 8, 1.2)
	local scrap = rng:NextNumber() < 0.5
	if scrap then
		sheets(map, rng, w, 1, { Back = false })
	else
		planks(map, rng, w, 1, { Back = false })
	end
	-- навес: брус на стене, кровля над шкафчиками, два подкоса по краям
	local timber = Kit.jitter(P.DarkWood, 0.05, rng)
	Kit.box(map.Decor, cf * C(0, 8.165, 2.0), V(8.4, 0.33, 0.5), timber, Mat.Wood, DECOR)
	local hi, lo = 8.42, 7.85
	if scrap then
		for _, x in { -2.1, 2.1 } do
			local color = Kit.jitter(SHEET_TONES[rng:NextInteger(1, #SHEET_TONES)], 0.05, rng)
			local sheet = Kit.bar(map.Decor, (cf * C(x, hi + (x > 0 and 0.04 or 0), 2.1)).Position, (cf * C(x, lo + (x > 0 and 0.04 or 0), -1.7)).Position, 4.4, color, Mat.CorrodedMetal, W.SOLID, 0.06)
			if sheet then
				for _, dx in { -1.4, 0, 1.4 } do
					Kit.cyl(map.Decor, sheet.CFrame * C(dx, 0.04, 0) * A(0, 90, 0), sheet.Size.Z, 0.14, Kit.jitter(color, 0.03, rng), Mat.CorrodedMetal, DECOR)
				end
			end
		end
	else
		for _, x in { -2.85, 0, 2.85 } do
			Kit.bar(map.Decor, (cf * C(x, hi, 2.1)).Position, (cf * C(x, lo + rng:NextNumber(-0.05, 0.05), -1.7)).Position, 2.75, Kit.jitter(P.OldWood, 0.07, rng), Mat.WoodPlanks, W.SOLID, 0.14)
		end
	end
	for _, x in { -3.9, 3.9 } do
		Kit.bar(map.Decor, (cf * C(x, 6.4, 1.4)).Position, (cf * C(x, 8.0, -0.9)).Position, 0.25, Kit.dark(timber, 0.1), Mat.Wood, DECOR, 0.3)
	end
	-- ведро у правого шкафчика
	local bucket = cf * C(3.75, 0, 0.6)
	Kit.vcyl(map.Decor, bucket * C(0, 0.45, 0), 0.9, 0.8, Kit.jitter(P.DarkSteel, 0.06, rng), Mat.Metal, DECOR)
	Kit.vcyl(map.Decor, bucket * C(0, 0.88, 0), 0.06, 0.84, P.Rust, Mat.CorrodedMetal, DECOR)
	Common.locker(map, rng, cf * CFrame.new(-2, 0, 0.3))
	Common.locker(map, rng, cf * CFrame.new(1.4, 0, 0.3))
end

return Loops
