-- Поиск ближайшего доступного действия для подсказки и нажатия.
-- primary — кнопка E (держать), secondary — Пробел.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Util = require(ReplicatedStorage.Shared.Util)
local ActionInfo = require(ReplicatedStorage.Shared.ActionInfo)
local KillerDefs = require(ReplicatedStorage.Shared.KillerDefs)

local player = Players.LocalPlayer
local gameState = ReplicatedStorage:WaitForChild("GameState")

local Interaction = {}

export type Candidate = { Kind: string, Target: Instance, Text: string }

local function children(name: string): { Instance }
	local map = workspace:FindFirstChild("Map")
	local f = map and map:FindFirstChild(name)
	return f and f:GetChildren() or {}
end

local function hatch(): Instance?
	local map = workspace:FindFirstChild("Map")
	return map and map:FindFirstChild("Hatch")
end

local function add(list, kind: string, target: Instance, text: string?)
	table.insert(list, { Kind = kind, Target = target, Text = text or ActionInfo[kind].Label })
end

local function nearest(rootPos: Vector3, candidates): Candidate?
	local best, bestDist = nil, math.huge
	for _, c in candidates do
		local pos = Util.objectPosition(c.Target)
		if pos then
			local d = Util.flatDist(rootPos, pos)
			if d <= ActionInfo[c.Kind].Range and d < bestDist and math.abs(rootPos.Y - pos.Y) < 9 then
				best, bestDist = c, d
			end
		end
	end
	return best
end

local function myTrap(): Instance?
	for _, trap in children("Traps") do
		if trap:GetAttribute("Caught") == player.UserId then
			return trap
		end
	end
	return nil
end

local function myLocker(): Instance?
	for _, l in children("Lockers") do
		if l:GetAttribute("Occupant") == player.UserId then
			return l
		end
	end
	return nil
end

local function survivorCandidates(primary, secondary)
	if player:GetAttribute("Hidden") then
		local locker = myLocker()
		if locker then
			add(secondary, "ExitLocker", locker)
		end
		return true
	end
	if player:GetAttribute("Trapped") then
		local trap = myTrap()
		if trap then
			add(primary, "EscapeTrap", trap)
		end
		return true
	end
	if (player:GetAttribute("Health") or 0) <= 0 then
		return true
	end
	for _, p in Players:GetPlayers() do
		if p ~= player and p:GetAttribute("Role") == "Survivor" then
			local status = p:GetAttribute("Status")
			local health = p:GetAttribute("Health") or 2
			if status == "Hooked" then
				add(primary, "Unhook", p, "Снять " .. p.DisplayName .. " с крюка")
			elseif status == "Playing" and health < 2 and not p:GetAttribute("Hidden") and not p:GetAttribute("Trapped") then
				add(primary, "Heal", p, (health == 0 and "Поднять " or "Лечить ") .. p.DisplayName)
			end
		end
	end
	if (gameState:GetAttribute("GensLeft") or 0) > 0 then
		for _, gen in children("Generators") do
			if not gen:GetAttribute("Done") then
				add(primary, "Repair", gen)
			end
		end
	end
	for _, gate in children("ExitGates") do
		if gate:GetAttribute("Powered") and not gate:GetAttribute("Open") then
			add(primary, "OpenGate", gate)
		end
	end
	for _, totem in children("Totems") do
		if not totem:GetAttribute("Cleansed") then
			add(primary, "Cleanse", totem, totem:GetAttribute("Hex") and "Очистить проклятый тотем" or nil)
		end
	end
	for _, chest in children("Chests") do
		if not chest:GetAttribute("Opened") then
			add(primary, "OpenChest", chest)
		end
	end
	for _, trap in children("Traps") do
		local caught = trap:GetAttribute("Caught") or 0
		if caught ~= 0 then
			add(primary, "FreeTrap", trap)
		elseif trap:GetAttribute("Armed") then
			add(primary, "DisarmTrap", trap)
		end
	end
	local h = hatch()
	if h and h:GetAttribute("Open") then
		add(primary, "JumpHatch", h)
	end
	for _, pallet in children("Pallets") do
		local state = pallet:GetAttribute("State")
		if state == "Up" then
			add(secondary, "DropPallet", pallet)
		elseif state == "Dropped" then
			add(secondary, "Vault", pallet, "Перепрыгнуть паллету")
		end
	end
	for _, window in children("Windows") do
		add(secondary, "Vault", window, "Перелезть через окно")
	end
	for _, locker in children("Lockers") do
		if locker:GetAttribute("Occupant") == 0 then
			add(secondary, "EnterLocker", locker)
		end
	end
	return false
end

local function killerCandidates(primary, secondary)
	if player:GetAttribute("Stunned") or player:GetAttribute("Blinded") then
		return
	end
	if player:GetAttribute("Carrying") then
		for _, hook in children("Hooks") do
			if hook:GetAttribute("Occupant") == 0 then
				add(primary, "Hook", hook)
			end
		end
		return
	end
	local cloaked = player:GetAttribute("PowerState") == "Cloaked"
	if not cloaked then
		for _, p in Players:GetPlayers() do
			if p:GetAttribute("Role") == "Survivor" and p:GetAttribute("Status") == "Playing" and not p:GetAttribute("Hidden") then
				if p:GetAttribute("Health") == 0 or p:GetAttribute("Trapped") then
					add(primary, "Pickup", p, "Поднять " .. p.DisplayName)
				end
			end
		end
	end
	for _, pallet in children("Pallets") do
		if pallet:GetAttribute("State") == "Dropped" then
			add(primary, "Break", pallet)
		end
	end
	if (gameState:GetAttribute("GensLeft") or 0) > 0 then
		for _, gen in children("Generators") do
			if not gen:GetAttribute("Done") and (gen:GetAttribute("Progress") or 0) > 0 and not gen:GetAttribute("Regressing") then
				add(primary, "Kick", gen)
			end
		end
	end
	local huntress = player:GetAttribute("KillerType") == "Huntress"
	for _, locker in children("Lockers") do
		add(primary, "SearchLocker", locker, huntress and "Обыскать шкафчик / взять топоры" or nil)
	end
	local h = hatch()
	if h and h:GetAttribute("Open") then
		add(primary, "CloseHatch", h)
	end
	if player:GetAttribute("KillerType") == "Trapper" then
		local inHand = player:GetAttribute("PowerCount") or 0
		for _, trap in children("Traps") do
			if (trap:GetAttribute("Caught") or 0) == 0 then
				if not trap:GetAttribute("Armed") then
					add(primary, "ResetTrap", trap)
				elseif inHand < KillerDefs.Trapper.MaxTrapsInHand then
					add(primary, "PickupTrap", trap)
				end
			end
		end
	end
	for _, window in children("Windows") do
		add(secondary, "Vault", window, "Перелезть через окно")
	end
end

function Interaction.find(): (Candidate?, Candidate?)
	local root = Util.getRoot(player)
	local role = player:GetAttribute("Role")
	if not root or not role or player:GetAttribute("Status") ~= "Playing" or player:GetAttribute("ActionName") then
		return nil, nil
	end
	local primary, secondary = {}, {}
	local pos = root.Position
	if role == "Survivor" then
		local exclusive = survivorCandidates(primary, secondary)
		if exclusive then
			-- Из шкафчика / капкана есть только одно действие
			return primary[1], secondary[1]
		end
	else
		killerCandidates(primary, secondary)
	end
	return nearest(pos, primary), nearest(pos, secondary)
end

return Interaction
