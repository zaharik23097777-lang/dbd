-- Ландшафт (Roblox Terrain): трава, тропинки, грязь, камни, холмы за стенами.
-- Поверхность земли на карте — y = 0 (как и раньше), поэтому геймплей не меняется.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Terrain = {}

local M = Enum.Material

local function terrain(): Terrain?
	return workspace:FindFirstChildOfClass("Terrain")
end

-- Вызов метода Terrain с защитой (в тестах/эмуляторе части методов может не быть)
local function call(method: string, ...)
	local t = terrain()
	if not t then
		return
	end
	local args = table.pack(...)
	pcall(function()
		(t :: any)[method](t, table.unpack(args, 1, args.n))
	end)
end
Terrain.call = call

function Terrain.setupColors()
	call("SetMaterialColor", M.Grass, Color3.fromRGB(62, 74, 44))
	call("SetMaterialColor", M.LeafyGrass, Color3.fromRGB(52, 66, 38))
	call("SetMaterialColor", M.Ground, Color3.fromRGB(78, 64, 48))
	call("SetMaterialColor", M.Mud, Color3.fromRGB(58, 46, 36))
	call("SetMaterialColor", M.Rock, Color3.fromRGB(92, 90, 88))
	call("SetMaterialColor", M.Slate, Color3.fromRGB(72, 72, 76))
end

-- Очистить область карты (лобби высоко над картой не трогаем)
function Terrain.clearMap()
	local size = Config.MapSize + 200
	call("FillBlock", CFrame.new(0, 20, 0), Vector3.new(size, 80, size), M.Air)
end

-- Земля карты. paths — список {From = Vector3, To = Vector3, Width = number} (тропинки между ячейками)
function Terrain.buildMap(rng: Random, paths: { any }?)
	local size = Config.MapSize
	local half = size / 2
	Terrain.clearMap()
	-- Основание: трава толщиной 8 стад, верх на y = 0
	call("FillBlock", CFrame.new(0, -4, 0), Vector3.new(size + 160, 8, size + 160), M.Grass)
	-- Пятна густой травы и грязи
	for _ = 1, 40 do
		local p = Vector3.new(rng:NextNumber(-half, half), -1.5, rng:NextNumber(-half, half))
		local mat = rng:NextNumber() < 0.6 and M.LeafyGrass or M.Ground
		call("FillCylinder", CFrame.new(p), 3, rng:NextNumber(4, 10), mat)
	end
	-- Тропинки
	if paths then
		for _, path in paths do
			local a: Vector3, b: Vector3 = path.From, path.To
			local mid = (a + b) / 2
			local len = (b - a).Magnitude
			if len > 1 then
				local cf = CFrame.lookAt(Vector3.new(mid.X, -1, mid.Z), Vector3.new(b.X, -1, b.Z))
				call("FillBlock", cf, Vector3.new(path.Width or 5, 2, len), M.Ground)
			end
		end
	end
	-- Холмы за внешними стенами (скрывают край мира)
	for i = 0, 40 do
		local t = i / 40
		for _, side in { -1, 1 } do
			local along = -half - 40 + (size + 80) * t
			local height = rng:NextNumber(10, 22)
			local dist = half + rng:NextNumber(14, 30)
			local r = rng:NextNumber(14, 24)
			local mat = rng:NextNumber() < 0.5 and M.Rock or M.Grass
			-- восток/запад
			call("FillBall", Vector3.new(side * dist, height - r, along), r, mat)
			-- север/юг (оставляем коридоры ворот свободными)
			if math.abs(along) > 26 then
				call("FillBall", Vector3.new(along, height - r, side * dist), r, mat)
			end
		end
	end
end

-- Поляна в лобби
function Terrain.buildLobby()
	local pos = Config.LobbyPosition
	call("FillBlock", CFrame.new(pos + Vector3.new(0, -4, 0)), Vector3.new(160, 8, 160), M.Grass)
	call("FillCylinder", CFrame.new(pos + Vector3.new(0, -1.5, 0)), 3, 12, M.Ground)
	local rng = Random.new(7)
	for _ = 1, 24 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(62, 80)
		call("FillBall", pos + Vector3.new(math.cos(a) * r, rng:NextNumber(-6, 4), math.sin(a) * r), rng:NextNumber(10, 18), M.Rock)
	end
end

return Terrain
