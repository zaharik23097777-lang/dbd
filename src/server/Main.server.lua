-- Точка входа сервера: лобби -> раунд -> результаты -> снова лобби.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

Players.CharacterAutoLoads = false

local Config = require(ReplicatedStorage.Shared.Config)
require(ReplicatedStorage.Shared.Remotes) -- создаёт RemoteEvent'ы
local MapBuilder = require(script.Parent.Map.MapBuilder)
local Characters = require(script.Parent.Core.Characters)
local Lobby = require(script.Parent.Core.Lobby)
local State = require(script.Parent.Core.State)
local Match = require(script.Parent.Core.Match)

-- Настоящие звуки из библиотеки Creator Store ищутся в фоне, игра их не ждёт
require(script.Parent.Core.SoundLibrary).start()

MapBuilder.SetupLighting()
MapBuilder.BuildLobby()
-- Все объекты карты строятся один раз заранее (с CSG), раунды только копируют их
require(script.Parent.Map.Art.Templates).prebuild()

local function onPlayerAdded(player: Player)
	-- Shift — это бег, поэтому Shift Lock отключаем
	pcall(function()
		player.DevEnableMouseLock = false
	end)
	task.spawn(Characters.spawnLobby, player)
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
Players.PlayerRemoving:Connect(Match.OnPlayerRemoving)

RunService.Heartbeat:Connect(function(dt)
	local ok, err = pcall(Match.Update, dt)
	if not ok then
		warn("[DBD] Ошибка в Match.Update: " .. tostring(err))
	end
end)

local function minPlayers(): number
	if RunService:IsStudio() then
		return Config.StudioMinPlayers
	end
	return Config.MinPlayers
end

local function readyPlayers(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player)
		end
	end
	return list
end

while true do
	State.setGame("Phase", "Waiting")
	State.setGame("Timer", 0)
	State.setGame("NeedPlayers", minPlayers())
	while #readyPlayers() < minPlayers() do
		task.wait(1)
	end

	local cancelled = false
	State.setGame("Phase", "Starting")
	for i = Config.LobbyCountdown, 1, -1 do
		State.setGame("Timer", i)
		task.wait(1)
		if #readyPlayers() < minPlayers() then
			cancelled = true
			break
		end
	end

	if not cancelled then
		local list = readyPlayers()
		local killer, killerType = Lobby.pickKiller(list)
		State.setGame("Phase", "Loading")
		local ok, err = pcall(Match.Start, list, killer, killerType)
		if not ok then
			warn("[DBD] Не удалось начать раунд: " .. tostring(err))
			State.Active = true
			Match.End("Ошибка запуска")
		end
		while State.Active do
			task.wait(0.5)
		end
		State.setGame("Phase", "Results")
		for i = Config.ResultsTime, 1, -1 do
			State.setGame("Timer", i)
			task.wait(1)
		end
	end
end
