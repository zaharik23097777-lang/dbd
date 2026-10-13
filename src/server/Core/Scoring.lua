-- Очки крови: 4 категории у выживших и 4 у маньяка, сохраняются в DataStore.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local State = require(script.Parent.State)

local Scoring = {}

Scoring.SurvivorCategories = { "Objectives", "Survival", "Altruism", "Boldness" }
Scoring.KillerCategories = { "Brutality", "Deviousness", "Hunter", "Sacrifice" }
Scoring.CategoryNames = {
	Objectives = "Цели",
	Survival = "Выживание",
	Altruism = "Альтруизм",
	Boldness = "Смелость",
	Brutality = "Жестокость",
	Deviousness = "Коварство",
	Hunter = "Охота",
	Sacrifice = "Жертвоприношение",
}

local store
if Config.SaveBloodpoints then
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("DBD_Bloodpoints_v1")
	end)
	if ok then
		store = result
	end
end

-- Добавить очки. label = nil — без всплывающей надписи
function Scoring.add(player: Player?, category: string, amount: number, label: string?)
	local data = State.get(player)
	if not data or not player then
		return
	end
	data.Score = data.Score or {}
	local current = data.Score[category] or 0
	local added = math.min(amount, Config.ScoreCategoryCap - current)
	if added <= 0 then
		return
	end
	data.Score[category] = current + added
	if label then
		Remotes.Score:FireClient(player, label, math.floor(added + 0.5), category)
	end
end

function Scoring.total(data): number
	local sum = 0
	for _, v in data.Score or {} do
		sum += v
	end
	return math.floor(sum)
end

function Scoring.summary(data)
	local cats = data.Role == "Killer" and Scoring.KillerCategories or Scoring.SurvivorCategories
	local out = {}
	for _, c in cats do
		table.insert(out, { Name = Scoring.CategoryNames[c], Value = math.floor((data.Score or {})[c] or 0) })
	end
	return out
end

function Scoring.load(player: Player)
	player:SetAttribute("Bloodpoints", 0)
	if not store then
		return
	end
	task.spawn(function()
		local ok, value = pcall(function()
			return store:GetAsync("u" .. player.UserId)
		end)
		if ok and typeof(value) == "number" and player.Parent then
			player:SetAttribute("Bloodpoints", value)
		end
	end)
end

function Scoring.commit(player: Player, amount: number)
	if amount <= 0 or not player.Parent then
		return
	end
	local current: number = (player:GetAttribute("Bloodpoints") :: number?) or 0
	player:SetAttribute("Bloodpoints", current + amount)
	if not store or player.UserId <= 0 then
		return
	end
	task.spawn(function()
		pcall(function()
			store:UpdateAsync("u" .. player.UserId, function(old)
				local prev: number = if typeof(old) == "number" then old else 0
				return prev + amount
			end)
		end)
	end)
end

Players.PlayerAdded:Connect(Scoring.load)
for _, p in Players:GetPlayers() do
	Scoring.load(p)
end

return Scoring
