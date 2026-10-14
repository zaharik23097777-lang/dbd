-- Лобби: лагерь у костра на поляне в тёмном лесу (как главное меню DBD).
-- Lobby.build() строит модель (сиденья — Seat в группе "DBDSeats"), Lobby.spawnCFrame() — точка появления.
-- Земля — Terrain (Terrain.buildLobby); здесь только детали. Бюджет ≤ 700 деталей.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Kit)
local Trees = require(script.Parent.NatureTrees)
local Ground = require(script.Parent.NatureGround)
local FX = require(script.Parent.NatureFX)
local Camp = require(script.Parent.LobbyCamp)
local Terrain = require(script.Parent.Parent.Terrain)

local C = CFrame.new

local Lobby = {}

-- Кольцо появления игроков (см. spawnCFrame): в полосе 11..17 от костра ничего твёрдого
local SPAWN_RADIUS = 14

-- Точка на кругу вокруг костра (угол в градусах от +X к +Z), «перед» (-Z) смотрит на костёр
local function around(center: Vector3, deg: number, r: number, turn: number?): CFrame
	local a = math.rad(deg)
	local p = center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
	return CFrame.lookAt(p, center) * CFrame.Angles(0, math.rad(turn or 0), 0)
end

-- Расстояние от точки до отрезка (в плоскости XZ)
local function segDist(p: Vector3, a: Vector3, b: Vector3): number
	local ab = (b - a) * Vector3.new(1, 0, 1)
	local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
	return ((a + ab * t - p) * Vector3.new(1, 0, 1)).Magnitude
end

-- Лес вокруг поляны: три смещённых кольца (ближнее — подробные ели, дальние — силуэты),
-- деревья по равным секторам со случайным сдвигом, тропы и ограда (±57) остаются свободными.
local function forest(parent: Instance, center: Vector3, rng: Random)
	local paths = {}
	for _, deg in Terrain.LobbyPaths do
		local a = math.rad(deg)
		table.insert(paths, center + Vector3.new(math.cos(a) * 80, 0, math.sin(a) * 80))
	end
	local function onPath(p: Vector3): boolean
		for _, far in paths do
			if segDist(p, center, far) < 4.5 then
				return true
			end
		end
		return false
	end
	-- {деревьев, радиус от, радиус до, детализация}. Внешнее кольцо видно почти только из лагеря —
	-- там силуэты, повёрнутые к костру (дешевле, поэтому их больше).
	for ring, spec in { { 8, 28, 33, "mid" }, { 14, 38, 45, "far" }, { 22, 49, 80, "far" } } do
		local count, r0, r1, lod = spec[1], spec[2], spec[3], spec[4]
		for i = 1, count do
			for _ = 1, 6 do
				local a = (i + ring * 0.37 + rng:NextNumber(-0.3, 0.3)) / count * math.pi * 2
				local c, s = math.cos(a), math.sin(a)
				-- Внешнее кольцо заходит в углы квадратной ограды, но не за неё
				local rMax = math.min(r1, 57 / math.max(math.abs(c), math.abs(s)))
				local r = rng:NextNumber(r0, math.max(r0, rMax))
				local p = center + Vector3.new(c * r, 0, s * r)
				if not onPath(p) then
					local facing = ring == 3 and (center - p).Unit or nil
					Trees.pine(parent, CFrame.new(p), rng, { Lod = lod, Lowest = rng:NextNumber(3.5, 6), Scale = ring == 3 and 1.3 or 1, Facing = facing })
					break
				end
			end
		end
	end
end

function Lobby.build(): Model
	local existing = workspace:FindFirstChild("Lobby")
	if existing then
		return existing :: Model
	end
	local rng = Random.new(42)
	local lobby = Kit.model("Lobby")
	local pos = Config.LobbyPosition
	local base = CFrame.new(pos)

	-- Невидимые стены
	for _, d in
		{
			{ Vector3.new(0, 15, 60), Vector3.new(120, 30, 2) },
			{ Vector3.new(0, 15, -60), Vector3.new(120, 30, 2) },
			{ Vector3.new(60, 15, 0), Vector3.new(2, 30, 120) },
			{ Vector3.new(-60, 15, 0), Vector3.new(2, 30, 120) },
		}
	do
		Kit.box(lobby, base * C(d[1]), d[2], Color3.new(0, 0, 0), Kit.Mat.SmoothPlastic, { Name = "Barrier", Transparency = 1 })
	end

	-- Костёр и брёвна-сиденья вокруг
	Camp.firePit(lobby, base, rng)
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		local seatPos = pos + Vector3.new(math.cos(a) * 9, 0.7, math.sin(a) * 9)
		Camp.logSeat(lobby, seatPos, pos, rng)
	end

	-- Лагерь за кольцом появления: палатки, припасы, фонари, поленница, табличка
	Camp.tent(lobby, around(pos, 128, 23, -8), rng)
	Camp.tent(lobby, around(pos, 207, 22.5, 14), rng, 0.85)
	local stash = around(pos, 104, 20.5, 20)
	Camp.crate(lobby, stash, Vector3.new(2.6, 2, 2), rng, "SUPPLY 7-B")
	Camp.crate(lobby, stash * C(2.7, 0, 0.3) * CFrame.Angles(0, math.rad(-12), 0), Vector3.new(2.2, 1.8, 1.9), rng)
	Camp.crate(lobby, stash * C(0.3, 2, 0.1) * CFrame.Angles(0, math.rad(9), 0), Vector3.new(2, 1.5, 1.7), rng)
	Camp.lantern(lobby, stash * C(-0.4, 3.5, -0.2), rng)
	Camp.drum(lobby, stash * C(-2.6, 0, 0.6), rng)
	Camp.duffel(lobby, stash * C(1.2, 0, -1.9) * CFrame.Angles(0, math.rad(15), 0), rng)
	Camp.lanternPost(lobby, around(pos, 152, 18), rng)
	Camp.lanternPost(lobby, around(pos, 252, 23, 160), rng)
	Camp.woodpile(lobby, around(pos, 328, 20), rng)
	Camp.clothesline(lobby, around(pos, 18, 22), around(pos, 50, 21.5), rng)
	Camp.sign(lobby, around(pos, 270, 26), rng, "DEAD BY DAYLIGHT")

	-- Трава и папоротники у подножия построек лагеря (угол, радиус)
	for _, spot in { { 270, 27.5 }, { 262, 25 }, { 128, 27 }, { 207, 26 }, { 104, 22.5 }, { 328, 22 } } do
		Ground.tuft(lobby, around(pos, spot[1] + rng:NextNumber(-3, 3), spot[2]), rng)
	end
	for _, spot in { { 150, 27 }, { 300, 26 } } do
		Ground.fern(lobby, around(pos, spot[1], spot[2]), rng)
	end

	-- Лес и туман
	forest(lobby, pos, rng)
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local r = i == 6 and 20 or rng:NextNumber(34, 50)
		FX.fog(lobby, pos + Vector3.new(math.cos(a) * r, 1, math.sin(a) * r), rng)
	end

	lobby.Parent = workspace
	return lobby
end

-- Точка появления в лобби (по кругу у костра)
function Lobby.spawnCFrame(): CFrame
	local pos = Config.LobbyPosition
	local a = math.random() * math.pi * 2
	local p = pos + Vector3.new(math.cos(a) * SPAWN_RADIUS, 3.5, math.sin(a) * SPAWN_RADIUS)
	return CFrame.lookAt(p, Vector3.new(pos.X, p.Y, pos.Z))
end

return Lobby
