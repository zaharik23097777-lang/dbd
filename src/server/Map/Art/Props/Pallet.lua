-- Паллета
-- Модель строится в начале координат: земля y = 0, «перед» модели смотрит в -Z.
-- Требования — Art/Contract.lua; подвижные части — Kit.movable (см. Map/PropFX.lua).
local Kit = require(script.Parent.Parent.Kit)

local Mat = Kit.Mat
local A = Kit.A
local V = Vector3.new
local C = CFrame.new

local M = {}
local T = {}
M.Templates = T

------------------------------------------------------------------------
-- Паллета (собирается в ОПУЩЕННОМ положении: хитбокс в начале координат, длинная сторона по X).
-- Настил (верхние доски) смотрит в -Z, нижние доски — в +Z, между ними три лаги вдоль Y.
-- Сталкивается только Hitbox; доски без столкновений и лучей, но крупные отбрасывают тень.
------------------------------------------------------------------------

local LEN, HGT = 5.6, 3
local BOARD_T = 0.18 -- толщина доски
local DECK_Z, BACK_Z = -0.44, 0.44
local STRINGER_W, STRINGER_D = 0.42, 0.7
local STRINGERS = { -2.55, 0, 2.55 }

local BOARD = { CanCollide = false, CanQuery = false, CanTouch = false }
local NAIL = Color3.fromRGB(52, 44, 38)

type Board = {
	X0: number, -- левый и правый концы доски
	X1: number,
	Y: number, -- центр по высоте
	W: number, -- ширина доски
	Color: Color3,
	Tilt: number?, -- поворот вокруг Z (градусы), доски «на глаз»
	Nailed: boolean?, -- рисовать шляпки гвоздей
}

-- Центры досок снизу вверх с равными щелями (края настила совпадают с краями лаг)
local function layout(widths: { number }): { number }
	local total = 0
	for _, w in widths do
		total += w
	end
	local gap = (HGT - total) / (#widths - 1)
	local ys = {}
	local y = -HGT / 2
	for _, w in widths do
		table.insert(ys, y + w / 2)
		y += w + gap
	end
	return ys
end

local function board(m: Model, b: Board, z: number, material: Enum.Material?): BasePart
	local cf = C((b.X0 + b.X1) / 2, b.Y, z) * A(0, 0, b.Tilt or 0)
	return Kit.box(m, cf, V(b.X1 - b.X0, b.W, BOARD_T), b.Color, material or Mat.Wood, BOARD)
end

-- Обломанный конец доски: острая щепа-клин в плоскости настила (dir = +1 — обломан правый конец)
local function splinter(m: Model, b: Board, z: number, dir: number, len: number, frac: number, top: boolean)
	local h = b.W * frac
	local x = (dir > 0 and b.X1 or b.X0) + dir * len / 2
	local y = top and b.Y + b.W / 2 - h / 2 or b.Y - b.W / 2 + h / 2
	local cf = C(x, y, z) * A(0, dir > 0 and -90 or 90, top and 180 or 0)
	Kit.wedge(m, cf, V(BOARD_T * 0.8, h, len), Kit.dark(b.Color, 0.08), Mat.Wood, { Decor = true })
end

-- Шляпки гвоздей: один SurfaceGui на невидимой пластине перед настилом вместо десятков деталей
local function nailHeads(m: Model, boards: { Board }, rng: Random)
	local plate = Kit.box(m, C(0, 0, DECK_Z - BOARD_T / 2 - 0.012), V(LEN, HGT, 0.02), NAIL, Mat.SmoothPlastic, { Decor = true, Transparency = 1 })
	plate.Name = "Nails"
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 1
	gui.MaxDistance = 45
	gui.Parent = plate
	local function dot(x: number, y: number, px: number, color: Color3, transparency: number)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		-- на передней грани левый край GUI соответствует +X детали
		f.Position = UDim2.fromScale(0.5 - x / LEN, 0.5 - y / HGT)
		f.Size = UDim2.fromOffset(px, px)
		f.BorderSizePixel = 0
		f.BackgroundColor3 = color
		f.BackgroundTransparency = transparency
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = f
		f.Parent = gui
	end
	for _, b in boards do
		if not b.Nailed then
			continue
		end
		for _, sx in STRINGERS do
			if sx > b.X0 + 0.15 and sx < b.X1 - 0.15 then
				for _, k in { -0.24, 0.24 } do
					local x, y = sx + rng:NextNumber(-0.08, 0.08), b.Y + k * b.W
					-- ржавый ореол вокруг шляпки и сама шляпка
					dot(x, y, 9, Kit.dark(b.Color, 0.45), 0.55)
					dot(x, y, 5, Kit.jitter(NAIL, 0.08, rng), 0)
				end
			end
		end
	end
end

local function stringer(m: Model, x: number, color: Color3, notched: boolean)
	if not notched then
		Kit.box(m, C(x, 0, 0), V(STRINGER_W, HGT, STRINGER_D), color, Mat.Wood, BOARD)
		return
	end
	-- Лага с вырезами под вилы погрузчика: сплошная часть у настила и три «ножки» у нижних досок
	local front = 0.45
	Kit.box(m, C(x, 0, -STRINGER_D / 2 + front / 2), V(STRINGER_W, HGT, front), color, Mat.Wood, BOARD)
	for _, y in { -1.2, 0, 1.2 } do
		Kit.box(m, C(x, y, -STRINGER_D / 2 + front + (STRINGER_D - front) / 2), V(STRINGER_W, 0.6, STRINGER_D - front), Kit.dark(color, 0.06), Mat.Wood, BOARD)
	end
end

-- Нижние доски (обратная сторона, +Z)
local function backBoards(m: Model, rng: Random, color: Color3, skip: number?)
	for i, y in { -1.2, 0, 1.2 } do
		if i ~= skip then
			local b: Board = {
				X0 = -LEN / 2 + rng:NextNumber(0, 0.08),
				X1 = LEN / 2 - rng:NextNumber(0, 0.08),
				Y = y,
				W = 0.58,
				Color = Kit.jitter(color, 0.08, rng),
				Tilt = rng:NextNumber(-0.5, 0.5),
			}
			board(m, b, BACK_Z)
		end
	end
end

-- Обычная доска настила во всю длину
local function full(rng: Random, y: number, w: number, color: Color3): Board
	return {
		X0 = -LEN / 2 + rng:NextNumber(0, 0.06),
		X1 = LEN / 2 - rng:NextNumber(0, 0.06),
		Y = y,
		W = w,
		Color = Kit.jitter(color, 0.09, rng),
		Tilt = rng:NextNumber(-0.6, 0.6),
		Nailed = true,
	}
end

T.Pallet = {
	Variants = 3,
	Build = function(rng: Random, variant: number)
		local m = Kit.model("Pallet")
		m:SetAttribute("Kind", "Pallet")
		local hitbox = Kit.box(m, CFrame.identity, V(LEN, HGT, 1.2), Color3.new(0, 0, 0), Mat.SmoothPlastic, { Transparency = 1, CanCollide = false })
		hitbox.Name = "Hitbox"
		Kit.setOrigin(m, hitbox)

		local deck: { Board } = {}
		if variant == 1 then
			-- Заводская: пять ровных досок, лаги с вырезами
			local wood = Kit.jitter(Color3.fromRGB(134, 110, 82), 0.04, rng)
			local widths = { 0.5, 0.38, 0.42, 0.38, 0.5 }
			for i, y in layout(widths) do
				table.insert(deck, full(rng, y, widths[i], wood))
			end
			-- верхняя доска сдвинута и торчит, у нижней отколот угол
			deck[5].X0 += 0.25
			deck[5].X1 += 0.12
			deck[1].X1 -= 0.35
			for _, b in deck do
				board(m, b, DECK_Z)
			end
			splinter(m, deck[1], DECK_Z, 1, 0.3, 0.6, true)
			for _, x in STRINGERS do
				stringer(m, x, Kit.dark(wood, 0.24), true)
			end
			backBoards(m, rng, Kit.dark(wood, 0.08))
		elseif variant == 2 then
			-- Старая и сырая: доска сломана и висит на одном гвозде, другой не хватает, одна заменена
			local wood = Kit.jitter(Color3.fromRGB(98, 84, 68), 0.04, rng)
			local widths = { 0.54, 0.5, 0.5, 0.48, 0.52 }
			local ys = layout(widths)
			deck[1] = full(rng, ys[1], widths[1], wood)
			deck[2] = full(rng, ys[2], widths[2], wood)
			deck[2].X1 = -0.25 -- правая половина отломана
			deck[3] = full(rng, ys[3], widths[3], wood)
			deck[3].X1 = 0.45
			deck[4] = full(rng, ys[4], widths[4], Color3.fromRGB(150, 122, 86)) -- новая доска взамен сгнившей
			deck[5] = full(rng, ys[5], widths[5], wood)
			deck[5].X0 += 0.3
			for _, b in deck do
				board(m, b, DECK_Z)
			end
			splinter(m, deck[2], DECK_Z, 1, 0.45, 0.7, false)
			splinter(m, deck[3], DECK_Z, 1, 0.35, 0.55, true)
			-- обломок средней доски провис на гвозде правой лаги
			local hanging: Board = {
				X0 = 0.8,
				X1 = LEN / 2 - 0.05,
				Y = ys[3],
				W = widths[3],
				Color = Kit.jitter(wood, 0.06, rng),
			}
			local piece = board(m, hanging, DECK_Z - 0.04)
			local pivot = C(STRINGERS[3], ys[3], DECK_Z - 0.04)
			piece.CFrame = Kit.aroundHinge(piece.CFrame, pivot, A(0, 4, 19))
			splinter(m, hanging, DECK_Z - 0.04, -1, 0.3, 0.6, false)
			for _, x in STRINGERS do
				stringer(m, x, Kit.dark(wood, 0.2), false)
			end
			backBoards(m, rng, Kit.dark(wood, 0.05), 2)
		else
			-- Самодельная: шесть разномастных узких досок (одна — крашеная от старого ящика) и косая распорка сзади
			local wood = Kit.jitter(Color3.fromRGB(122, 98, 72), 0.04, rng)
			local widths = { 0.42, 0.36, 0.4, 0.34, 0.42, 0.38 }
			local colors = { wood, Color3.fromRGB(86, 94, 98), wood, Kit.dark(wood, 0.3), wood, Color3.fromRGB(140, 116, 84) }
			for i, y in layout(widths) do
				local b = full(rng, y, widths[i], colors[i])
				b.X0 += rng:NextNumber(-0.05, 0.25)
				b.X1 -= rng:NextNumber(-0.05, 0.25)
				b.Tilt = rng:NextNumber(-1.2, 1.2)
				table.insert(deck, b)
			end
			for _, b in deck do
				board(m, b, DECK_Z)
			end
			for _, x in STRINGERS do
				stringer(m, x + rng:NextNumber(-0.1, 0.1), Kit.dark(wood, 0.22), false)
			end
			backBoards(m, rng, Kit.dark(wood, 0.1))
			-- косая распорка поверх нижних досок
			local z = BACK_Z + BOARD_T / 2 + 0.07
			Kit.bar(m, V(-2.3, -1.3, z), V(2.3, 1.3, z), 0.14, Kit.jitter(wood, 0.08, rng), Mat.Wood, BOARD, 0.4)
		end
		nailHeads(m, deck, rng)
		m:SetAttribute("State", "Up")
		return m
	end,
}

return M
