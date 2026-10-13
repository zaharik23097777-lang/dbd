-- Выбор в лобби: «хочу быть маньяком» и выбор маньяка.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local KillerDefs = require(ReplicatedStorage.Shared.KillerDefs)

local Lobby = {}

local function init(player: Player)
	player:SetAttribute("WantKiller", false)
	player:SetAttribute("KillerChoice", "Trapper")
end

Players.PlayerAdded:Connect(init)
for _, p in Players:GetPlayers() do
	init(p)
end

Remotes.LobbyChoice.OnServerEvent:Connect(function(player, key, value)
	if key == "WantKiller" and typeof(value) == "boolean" then
		player:SetAttribute("WantKiller", value)
	elseif key == "Killer" and typeof(value) == "string" and KillerDefs[value] and table.find(KillerDefs.Order, value) then
		player:SetAttribute("KillerChoice", value)
	end
end)

-- Выбирает маньяка: сначала среди желающих, иначе среди всех
function Lobby.pickKiller(list: { Player }): (Player?, string)
	if #list <= 1 then
		return nil, "Trapper"
	end
	local wanting = {}
	for _, p in list do
		if p:GetAttribute("WantKiller") then
			table.insert(wanting, p)
		end
	end
	local pool = #wanting > 0 and wanting or list
	local killer = pool[math.random(1, #pool)]
	return killer, killer:GetAttribute("KillerChoice") or "Trapper"
end

return Lobby
