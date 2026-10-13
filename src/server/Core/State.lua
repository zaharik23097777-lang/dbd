-- Общее состояние раунда и вспомогательные функции для всех систем.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Util = require(ReplicatedStorage.Shared.Util)

local State = {}

State.Active = false
State.Participants = {} :: { [Player]: any }
State.Killer = nil :: any -- data маньяка
State.Map = nil :: any
State.SoloTest = false
State.GensDone = 0
State.GatesPowered = false
State.EndgameDeadline = nil :: number?
State.StartTime = 0
State.HexRuin = false
State.InitialSurvivors = 0

State.RED = Color3.fromRGB(255, 70, 70)
State.YELLOW = Color3.fromRGB(255, 220, 90)
State.GREEN = Color3.fromRGB(110, 255, 140)
State.WHITE = Color3.fromRGB(240, 240, 240)

State.getRoot = Util.getRoot
State.getHumanoid = Util.getHumanoid
State.flatDist = Util.flatDist

local gameState = ReplicatedStorage:FindFirstChild("GameState")
if not gameState then
	gameState = Instance.new("Folder")
	gameState.Name = "GameState"
	gameState.Parent = ReplicatedStorage
end
State.GameState = gameState

function State.now(): number
	return os.clock()
end

function State.setGame(key: string, value: any)
	gameState:SetAttribute(key, value)
end

function State.notifyAll(text: string, color: Color3?)
	Remotes.Notify:FireAllClients(text, color)
end

function State.notify(player: Player?, text: string, color: Color3?)
	if player and player.Parent then
		Remotes.Notify:FireClient(player, text, color)
	end
end

-- Звук для всех: where = Vector3, BasePart/Model или nil (без позиции)
function State.sfx(name: string, where: any?)
	Remotes.Sfx:FireAllClients(name, where)
end

function State.sfxTo(player: Player, name: string, where: any?)
	if player.Parent then
		Remotes.Sfx:FireClient(player, name, where)
	end
end

function State.effect(player: Player, name: string, value: any?)
	if player.Parent then
		Remotes.Effect:FireClient(player, name, value)
	end
end

-- Одноразовая анимация: клиенты видят смену AnimSeq и проигрывают позу
function State.playAnim(player: Player, name: string)
	local char = player.Character
	if char then
		char:SetAttribute("Anim", name)
		char:SetAttribute("AnimSeq", (char:GetAttribute("AnimSeq") or 0) + 1)
	end
end

-- Шум для маньяка (восклицательный знак на месте)
function State.noise(position: Vector3)
	local k = State.Killer
	if k and k.Player.Parent then
		Remotes.Noise:FireClient(k.Player, position)
	end
end

function State.isInGame(data): boolean
	return Util.isInGameStatus(data.Status)
end

function State.survivors(): { any }
	local list = {}
	for _, data in State.Participants do
		if data.Role == "Survivor" then
			table.insert(list, data)
		end
	end
	return list
end

function State.remainingSurvivors(): number
	local n = 0
	for _, data in State.Participants do
		if data.Role == "Survivor" and State.isInGame(data) then
			n += 1
		end
	end
	return n
end

function State.get(player: Player?)
	return player and State.Participants[player]
end

-- Можно ли выжившего ударить / схватить
function State.isTargetable(data): boolean
	return data.Status == "Playing" and not data.Hidden and State.now() >= data.VaultUntil
end

return State
