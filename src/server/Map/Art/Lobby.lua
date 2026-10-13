-- Лобби у костра: Lobby.build() строит модель (сиденья — Seat в группе "DBDSeats"),
-- Lobby.spawnCFrame() — точка появления игрока.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Legacy = require(script.Parent.Legacy)

local P = Legacy.part
local A = Legacy.A

local Lobby = {}


function Lobby.build(): Model
	local existing = workspace:FindFirstChild("Lobby")
	if existing then
		return existing :: Model
	end
	local rng = Random.new(42)
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	local pos = Config.LobbyPosition
	local base = CFrame.new(pos)

	P(lobby, {
		Name = "Ground",
		Size = Vector3.new(120, 2, 120),
		CFrame = base * CFrame.new(0, -1, 0),
		Color = Color3.fromRGB(38, 48, 30),
		Material = Enum.Material.Grass,
	})
	-- Невидимые стены
	for _, d in
		{
			{ Vector3.new(0, 15, 60), Vector3.new(120, 30, 2) },
			{ Vector3.new(0, 15, -60), Vector3.new(120, 30, 2) },
			{ Vector3.new(60, 15, 0), Vector3.new(2, 30, 120) },
			{ Vector3.new(-60, 15, 0), Vector3.new(2, 30, 120) },
		}
	do
		P(lobby, { Name = "Barrier", Size = d[2], CFrame = base * CFrame.new(d[1]), Transparency = 1 })
	end

	-- Костёр
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		P(lobby, {
			Name = "FireStone",
			Size = Vector3.new(1.2, 0.8, 1),
			CFrame = base * CFrame.new(math.cos(a) * 2.4, 0.4, math.sin(a) * 2.4) * A(0, -math.deg(a), 0),
			Color = Color3.fromRGB(80, 78, 75),
			Material = Enum.Material.Slate,
		})
	end
	for i = 1, 4 do
		P(lobby, {
			Name = "FireLog",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3, 0.6, 0.6),
			CFrame = base * CFrame.new(0, 0.5, 0) * A(0, i * 45, 25),
			Color = Color3.fromRGB(50, 35, 25),
			Material = Enum.Material.Wood,
		})
	end
	Legacy.fire(lobby, base * CFrame.new(0, 1.2, 0), 2.2)

	-- Брёвна-сиденья вокруг костра
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		local seatPos = pos + Vector3.new(math.cos(a) * 9, 0.7, math.sin(a) * 9)
		local seat = Instance.new("Seat")
		seat.Name = "LogSeat"
		seat.Anchored = true
		seat.Shape = Enum.PartType.Cylinder
		seat.Size = Vector3.new(5, 1.4, 1.4)
		seat.CFrame = CFrame.lookAt(seatPos, Vector3.new(pos.X, seatPos.Y, pos.Z))
		seat.Color = Color3.fromRGB(70, 50, 35)
		seat.Material = Enum.Material.Wood
		seat.CollisionGroup = "DBDSeats"
		seat.Parent = lobby
	end

	-- Палатки, деревья, туман
	for i = 1, 3 do
		local a = i / 3 * math.pi * 2 + 0.5
		local tcf = CFrame.lookAt(pos + Vector3.new(math.cos(a) * 22, 0, math.sin(a) * 22), pos)
		for _, side in { -1, 1 } do
			local w = Instance.new("WedgePart")
			w.Anchored = true
			w.Size = Vector3.new(0.3, 4, 3)
			w.CFrame = tcf * CFrame.new(side * 1.5, 2, 0) * A(0, side * 90, 0)
			w.Color = Color3.fromRGB(70 + i * 20, 80, 60)
			w.Material = Enum.Material.Fabric
			w.Parent = lobby
		end
		P(lobby, {
			Name = "TentFloor",
			Size = Vector3.new(6, 0.2, 6),
			CFrame = tcf * CFrame.new(0, 0.1, 0),
			Color = Color3.fromRGB(60, 55, 45),
			Material = Enum.Material.Fabric,
		})
	end
	for _ = 1, 26 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(32, 55)
		Legacy.tree(lobby, base * CFrame.new(math.cos(a) * r, 0, math.sin(a) * r), rng)
	end
	for _ = 1, 6 do
		Legacy.fog(lobby, pos + Vector3.new(rng:NextNumber(-40, 40), 1, rng:NextNumber(-40, 40)), rng)
	end

	-- Табличка
	local board = P(lobby, {
		Name = "Sign",
		Size = Vector3.new(12, 4, 0.4),
		CFrame = base * CFrame.new(0, 5, -26),
		Color = Color3.fromRGB(60, 40, 30),
		Material = Enum.Material.WoodPlanks,
	})
	for _, x in { -5, 5 } do
		P(lobby, {
			Name = "SignPost",
			Size = Vector3.new(0.5, 5, 0.5),
			CFrame = base * CFrame.new(x, 2.5, -26),
			Color = Color3.fromRGB(50, 35, 25),
			Material = Enum.Material.Wood,
		})
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.CanvasSize = Vector2.new(600, 200)
	gui.Parent = board
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = "DEAD BY DAYLIGHT"
	text.Font = Enum.Font.Creepster
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(190, 20, 20)
	text.Parent = gui

	lobby.Parent = workspace
	return lobby
end

-- Точка появления в лобби (по кругу у костра)
function Lobby.spawnCFrame(): CFrame
	local pos = Config.LobbyPosition
	local a = math.random() * math.pi * 2
	local p = pos + Vector3.new(math.cos(a) * 14, 3.5, math.sin(a) * 14)
	return CFrame.lookAt(p, Vector3.new(pos.X, p.Y, pos.Z))
end

return Lobby
