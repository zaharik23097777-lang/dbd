-- Точка входа сервера: лобби -> раунд -> результаты -> снова лобби.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
require(ReplicatedStorage.Shared.Remotes) -- создаёт RemoteEvent'ы
local MapBuilder = require(script.Parent.MapBuilder)
local Match = require(script.Parent.Match)

Players.RespawnTime = 2
MapBuilder.BuildLobby()
MapBuilder.SetupLighting()

Players.PlayerRemoving:Connect(Match.OnPlayerRemoving)
RunService.Heartbeat:Connect(function(dt)
	local ok, err = pcall(Match.Update, dt)
	if not ok then
		warn("[DBD] Ошибка в Match.Update: " .. tostring(err))
	end
end)

-- Новые персонажи в лобби не должны прыгать по карте во время раунда
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		local hum = char:WaitForChild("Humanoid")
		hum.WalkSpeed = 16
	end)
end)

local function minPlayers()
	if RunService:IsStudio() then
		return Config.StudioMinPlayers
	end
	return Config.MinPlayers
end

local function readyPlayers()
	local list = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player)
		end
	end
	return list
end

while true do
	-- Лобби: ждём игроков
	Match.SetState("Phase", "Waiting")
	Match.SetState("Timer", 0)
	while #readyPlayers() < minPlayers() do
		task.wait(1)
	end

	-- Отсчёт
	local cancelled = false
	Match.SetState("Phase", "Starting")
	for i = Config.LobbyCountdown, 1, -1 do
		Match.SetState("Timer", i)
		task.wait(1)
		if #readyPlayers() < minPlayers() then
			cancelled = true
			break
		end
	end

	if not cancelled then
		local list = readyPlayers()
		local ok, err = pcall(Match.Start, list)
		if not ok then
			warn("[DBD] Не удалось начать раунд: " .. tostring(err))
			Match.End("Ошибка запуска")
		end
		while Match.Active do
			task.wait(0.5)
		end
		Match.SetState("Phase", "Results")
		for i = Config.ResultsTime, 1, -1 do
			Match.SetState("Timer", i)
			task.wait(1)
		end
	end
end
