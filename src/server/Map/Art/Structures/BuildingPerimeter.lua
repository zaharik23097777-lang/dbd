-- Внешняя стена карты: пролёты из бетона и кирпича между пилонами, парапет поверху, потёки, заплаты.
-- Высота 16 везде, толщина 2, проёмы ворот ровно gateGap (север и юг). Стена сплошная, непрозрачная
-- и сталкивается целиком (пролёты стыкуются без щелей). Снаружи у ворот — карман откатной двери,
-- поэтому всё выступающее — только с внутренней стороны (выше 16 парапет выступает на 0.25 с обеих).
local Kit = require(script.Parent.Parent.Kit)

local P = Kit.Palette
local Mat = Kit.Mat
local A = Kit.A
local V = Vector3.new
local C = CFrame.new
local DECOR = { Decor = true }

local HEIGHT = 16
local THICK = 2
local SECTION = 12 -- примерная длина пролёта между пилонами
local PIER = 0.6 -- насколько пилон выступает внутрь

-- Прямой участок стены: Frame — X вдоль стены, Z наружу (y = 0 на земле); From..To — отрезок по X
type Run = { Frame: CFrame, From: number, To: number, GateFrom: boolean, GateTo: boolean }

local STYLES = {
	{ Color = P.Concrete, Mat = Mat.Concrete, Weight = 0.55 },
	{ Color = P.DarkConcrete, Mat = Mat.Concrete, Weight = 0.25 },
	{ Color = Kit.dark(P.Brick, 0.15), Mat = Mat.Brick, Weight = 0.2 },
}

local function pickStyle(rng: Random)
	local r = rng:NextNumber()
	for _, s in STYLES do
		r -= s.Weight
		if r <= 0 then
			return s
		end
	end
	return STYLES[1]
end

-- Мелочи на внутренней грани пролёта (x — центр, len — длина)
local function sectionDetail(parent: Instance, rng: Random, f: CFrame, x: number, len: number, core: BasePart)
	local zi = -THICK / 2
	local r = rng:NextNumber()
	if r < 0.3 then
		-- потёки от парапета
		for _ = 1, rng:NextInteger(1, 2) do
			local h = rng:NextNumber(3, 8)
			Kit.box(parent, f * C(x + rng:NextNumber(-len / 2 + 1, len / 2 - 1), HEIGHT - h / 2, zi - 0.02), V(rng:NextNumber(0.25, 0.6), h, 0.04), Kit.jitter(Color3.fromRGB(52, 44, 38), 0.06, rng), Mat.Concrete, DECOR)
		end
		Kit.rustStreaks(core, Enum.NormalId.Front, rng, 4)
	elseif r < 0.45 then
		-- ржавая заплата на болтах
		local plate = Kit.box(parent, f * C(x + rng:NextNumber(-2, 2), rng:NextNumber(3, 10), zi - 0.06) * A(0, 0, rng:NextNumber(-4, 4)), V(rng:NextNumber(2, 3.2), rng:NextNumber(2.2, 3.6), 0.12), Kit.jitter(P.Rust, 0.06, rng), Mat.CorrodedMetal, DECOR)
		Kit.rustStreaks(plate, Enum.NormalId.Front, rng, 3)
	elseif r < 0.55 then
		-- осыпавшиеся куски у основания
		for _ = 1, 2 do
			local s = rng:NextNumber(0.5, 1.1)
			Kit.box(parent, f * C(x + rng:NextNumber(-len / 3, len / 3), s * 0.35, zi - rng:NextNumber(0.4, 1.0)) * A(rng:NextNumber(-20, 20), rng:NextNumber(0, 90), 0), V(s, s * 0.7, s * 0.9), Kit.jitter(P.DarkConcrete, 0.06, rng), Mat.Slate, DECOR)
		end
	elseif r < 0.63 then
		-- оголённая арматура над парапетом
		for _ = 1, 2 do
			local bx = x + rng:NextNumber(-len / 3, len / 3)
			local top = f * C(bx + rng:NextNumber(-0.3, 0.3), HEIGHT + rng:NextNumber(1.0, 1.8), rng:NextNumber(-0.6, 0.6))
			Kit.rod(parent, (f * C(bx, HEIGHT + 0.3, 0)).Position, top.Position, 0.14, P.DarkRust, Mat.CorrodedMetal, DECOR)
		end
	elseif r < 0.68 then
		-- табличка
		local sign = Kit.box(parent, f * C(x + rng:NextNumber(-2, 2), rng:NextNumber(6, 8), zi - 0.04) * A(0, 0, rng:NextNumber(-6, 6)), V(3, 1.4, 0.06), Kit.jitter(Color3.fromRGB(150, 140, 112), 0.05, rng), Mat.Metal, DECOR)
		Kit.label(sign, Enum.NormalId.Front, "NO TRESPASSING", Color3.fromRGB(120, 20, 16), Enum.Font.Oswald)
	end
end

local function outerWalls(map, size: number, gateGap: number)
	local half = size / 2
	local rng = Random.new(size * 7 + gateGap)
	local runs: { Run } = {}
	for _, side in { 1, -1 } do
		local ns = CFrame.fromMatrix(V(0, 0, side * half), V(side, 0, 0), V(0, 1, 0))
		table.insert(runs, { Frame = ns, From = gateGap / 2, To = half, GateFrom = true, GateTo = false })
		table.insert(runs, { Frame = ns, From = -half, To = -gateGap / 2, GateFrom = false, GateTo = true })
		local ew = CFrame.fromMatrix(V(side * half, 0, 0), V(0, 0, -side), V(0, 1, 0))
		table.insert(runs, { Frame = ew, From = -half, To = half, GateFrom = false, GateTo = false })
	end
	local cap = Kit.jitter(P.DarkConcrete, 0.03, rng)
	for _, run in runs do
		local f = run.Frame
		local len = run.To - run.From
		local n = math.max(1, math.floor(len / SECTION + 0.5))
		local step = len / n
		for k = 0, n - 1 do
			local x = run.From + step * (k + 0.5)
			local style = pickStyle(rng)
			local core = Kit.box(map.Walls, f * C(x, HEIGHT / 2, 0), V(step, HEIGHT, THICK), Kit.jitter(style.Color, 0.04, rng), style.Mat)
			core.Name = "OuterWall"
			Kit.grime(core, Enum.NormalId.Front, 0.6)
			sectionDetail(map.Decor, rng, f, x, step, core)
			if k > 0 then
				-- пилон на стыке пролётов (только внутрь) с оголовком
				local bx = run.From + step * k
				local pier = Kit.jitter(P.Concrete, 0.04, rng)
				Kit.box(map.Decor, f * C(bx, (HEIGHT + 1.2) / 2, -THICK / 2 - PIER / 2 + 0.05), V(1.6, HEIGHT + 1.2, PIER + 0.1), pier, Mat.Concrete, DECOR)
				Kit.box(map.Decor, f * C(bx, HEIGHT + 1.38, -THICK / 2 - PIER / 2 + 0.05), V(2, 0.36, PIER + 0.9), Kit.dark(pier, 0.15), Mat.Concrete, DECOR)
			end
		end
		-- парапет вдоль участка (у ворот отступает от ригеля ворот)
		local a = run.GateFrom and run.From + 1.9 or run.From
		local b = run.GateTo and run.To - 1.9 or run.To
		Kit.box(map.Decor, f * C((a + b) / 2, HEIGHT + 0.225, 0), V(b - a, 0.45, THICK + 0.5), cap, Mat.Concrete, DECOR)
	end
	-- угловые башенки
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local pos = C(sx * half, 0, sz * half)
			local pier = Kit.jitter(P.Concrete, 0.04, rng)
			Kit.box(map.Decor, pos * C(0, (HEIGHT + 1.6) / 2, 0), V(3, HEIGHT + 1.6, 3), pier, Mat.Concrete, DECOR)
			Kit.box(map.Decor, pos * C(0, HEIGHT + 1.8, 0), V(3.5, 0.4, 3.5), Kit.dark(pier, 0.15), Mat.Concrete, DECOR)
		end
	end
end

return outerWalls
