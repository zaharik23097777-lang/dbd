-- Разброс мелочей по карте (≤ 450 деталей на всю карту): трава, папоротники, кусты, ветки, пни,
-- камешки — в свободных местах, чаще у подножия стен, камней и деревьев; и кольцо елей за внешней
-- стеной, чтобы мир не обрывался голыми холмами. Всё — декор (не сталкивается, не мешает лучам).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Kit)
local Trees = require(script.Parent.NatureTrees)
local Ground = require(script.Parent.NatureGround)

local Scatter = {}

local BUDGET = 450
local CELL = 2 -- шаг сетки занятости, стад

-- Сетка занятости: клетки, над которыми у земли (ниже 4 стад) есть детали карты
type Grid = { n: number, half: number, busy: { [number]: boolean } }

local function buildGrid(root: Instance, half: number): Grid
	local n = math.ceil(half * 2 / CELL)
	local busy = {}
	for _, d in root:GetDescendants() do
		if not d:IsA("BasePart") or d.Transparency >= 1 then
			continue
		end
		local cf, s = d.CFrame, d.Size / 2
		local r = cf.Rotation
		local ex = math.abs(r.XVector.X) * s.X + math.abs(r.YVector.X) * s.Y + math.abs(r.ZVector.X) * s.Z + 0.6
		local ey = math.abs(r.XVector.Y) * s.X + math.abs(r.YVector.Y) * s.Y + math.abs(r.ZVector.Y) * s.Z
		local ez = math.abs(r.XVector.Z) * s.X + math.abs(r.YVector.Z) * s.Y + math.abs(r.ZVector.Z) * s.Z + 0.6
		if cf.Y - ey > 4 then
			continue
		end
		local x0 = math.max(0, math.floor((cf.X - ex + half) / CELL))
		local x1 = math.min(n - 1, math.floor((cf.X + ex + half) / CELL))
		local z0 = math.max(0, math.floor((cf.Z - ez + half) / CELL))
		local z1 = math.min(n - 1, math.floor((cf.Z + ez + half) / CELL))
		for ix = x0, x1 do
			for iz = z0, z1 do
				busy[ix + iz * n] = true
			end
		end
	end
	return { n = n, half = half, busy = busy }
end

-- Свободные клетки: «у края» (рядом занятая) и «открытые»
local function freeCells(g: Grid): ({ Vector3 }, { Vector3 })
	local edge, open = {}, {}
	local n = g.n
	for ix = 1, n - 2 do
		for iz = 1, n - 2 do
			if not g.busy[ix + iz * n] then
				local p = Vector3.new((ix + 0.5) * CELL - g.half, 0, (iz + 0.5) * CELL - g.half)
				local near = g.busy[ix + 1 + iz * n] or g.busy[ix - 1 + iz * n] or g.busy[ix + (iz + 1) * n] or g.busy[ix + (iz - 1) * n]
				-- Тропа к воротам по оси x = 0 остаётся чистой
				if math.abs(p.X) > 4 then
					table.insert(near and edge or open, p)
				end
			end
		end
	end
	return edge, open
end

-- Кольцо елей-силуэтов за внешней стеной (стена на ±half). Коридоры ворот (север/юг) свободны.
local function treeRing(parent: Instance, rng: Random, half: number, limit: number)
	local spots = {}
	for _, side in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local along = Vector3.new(side.Z, 0, side.X)
		local gated = side.Z ~= 0
		local a = -half - 20 + rng:NextNumber(0, 10)
		while a < half + 20 do
			local dist = half + rng:NextNumber(5, 24)
			if not (gated and math.abs(a) < 16) then
				table.insert(spots, side * dist + along * a)
			end
			a += rng:NextNumber(24, 30)
		end
	end
	for i = #spots, 2, -1 do
		local j = rng:NextInteger(1, i)
		spots[i], spots[j] = spots[j], spots[i]
	end
	local used = 0
	for _, p in spots do
		if used + 7 > limit then
			break
		end
		local before = Kit.count(parent)
		local inward = -Vector3.new(p.X, 0, p.Z).Unit
		Trees.pine(parent, CFrame.new(p), rng, { Lod = "far", Scale = rng:NextNumber(1.35, 1.75), Lowest = rng:NextNumber(4, 9), Facing = inward })
		used += Kit.count(parent) - before
	end
	return used
end

function Scatter.run(map, rng: Random)
	local half = Config.MapSize / 2
	local folder = Instance.new("Folder")
	folder.Name = "Scatter"
	folder.Parent = map.Decor
	-- Сначала кольцо деревьев (бюджет ~230), затем мелочи на остаток
	local used = treeRing(folder, rng, half, 230)
	local edge, open = freeCells(buildGrid(map.Model, half))

	local function pick(list: { Vector3 }): Vector3?
		if #list == 0 then
			return nil
		end
		local i = rng:NextInteger(1, #list)
		local p = list[i]
		list[i] = list[#list]
		list[#list] = nil
		return p + Vector3.new(rng:NextNumber(-0.6, 0.6), 0, rng:NextNumber(-0.6, 0.6))
	end
	-- {функция, сколько, доля «у края», детали на штуку (макс.)}
	local kinds: { { any } } = {
		{ Ground.tuft, 40, 0.7, 3 },
		{ Ground.fern, 10, 0.8, 5 },
		{ Ground.bush, 7, 0.8, 6 },
		{ Ground.pebble, 12, 0.6, 1 },
		{ Trees.fallenBranch, 7, 0.3, 3 },
		{ Trees.stump, 5, 0.2, 4 },
	}
	for round = 1, 40 do
		for _, k in kinds do
			if round <= k[2] and used + k[4] <= BUDGET then
				local p = pick(rng:NextNumber() < k[3] and edge or open)
				if p then
					local before = Kit.count(folder)
					k[1](folder, CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), rng)
					used += Kit.count(folder) - before
				end
			end
		end
	end
end

return Scatter
