-- Вся логика одного раунда: роли, удары, генераторы, крюки, паллеты, ворота.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local PhysicsService = game:GetService("PhysicsService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local MapBuilder = require(script.Parent.MapBuilder)

local Match = {}
Match.Active = false

local CARRIED_GROUP = "DBDCarried"
PhysicsService:RegisterCollisionGroup(CARRIED_GROUP)
PhysicsService:CollisionGroupSetCollidable(CARRIED_GROUP, "Default", false)
PhysicsService:CollisionGroupSetCollidable(CARRIED_GROUP, CARRIED_GROUP, false)

local CARRY_OFFSET = CFrame.new(0.9, 1.4, 0.3) * CFrame.Angles(0, 0, math.rad(90))

local TIMED_ACTIONS = {
	Unhook = Config.UnhookTime,
	Hook = Config.HookTime,
	Break = Config.BreakPalletTime,
	Kick = Config.KickGeneratorTime,
}

local SURVIVOR_ACTIONS = { Repair = true, Heal = true, Unhook = true, OpenGate = true, DropPallet = true, Vault = true }
local KILLER_ACTIONS = { Pickup = true, Hook = true, Break = true, Kick = true, Vault = true }

local gameState = ReplicatedStorage:FindFirstChild("GameState")
if not gameState then
	gameState = Instance.new("Folder")
	gameState.Name = "GameState"
	gameState.Parent = ReplicatedStorage
end

local map
local participants = {} -- [Player] = data
local killerData
local soloTest = false
local gensDone = 0
local gatesPowered = false
local endgameDeadline
local startTime = 0
local skillCheckCounter = 0
local rng = Random.new()

------------------------------------------------------------------------
-- Вспомогательные функции
------------------------------------------------------------------------

local function now()
	return os.clock()
end

local function getRoot(player)
	local char = player and player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid(player)
	local char = player and player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function flatDist(a, b)
	local d = a - b
	return Vector3.new(d.X, 0, d.Z).Magnitude
end

local function notifyAll(text, color)
	Remotes.Notify:FireAllClients(text, color)
end

local function notify(player, text, color)
	if player and player.Parent then
		Remotes.Notify:FireClient(player, text, color)
	end
end

local RED = Color3.fromRGB(255, 70, 70)
local YELLOW = Color3.fromRGB(255, 220, 90)
local GREEN = Color3.fromRGB(110, 255, 140)

local function setState(key, value)
	gameState:SetAttribute(key, value)
end
Match.SetState = setState

local function survivors()
	local list = {}
	for _, data in participants do
		if data.Role == "Survivor" then
			table.insert(list, data)
		end
	end
	return list
end

local function isInGame(data)
	return data.Status == "Playing" or data.Status == "Carried" or data.Status == "Hooked"
end

local function setDowned(data, downed)
	local hum = getHumanoid(data.Player)
	if hum and data.BaseHipHeight then
		hum.HipHeight = downed and data.BaseHipHeight * 0.3 or data.BaseHipHeight
	end
end

local function noise(position)
	if killerData and killerData.Player.Parent then
		Remotes.Noise:FireClient(killerData.Player, position)
	end
end

local function bloodBurst(part)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.fromRGB(150, 0, 0))
	emitter.Size = NumberSequence.new(0.4, 0)
	emitter.Speed = NumberRange.new(6, 12)
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.Lifetime = NumberRange.new(0.4, 0.8)
	emitter.Acceleration = Vector3.new(0, -30, 0)
	emitter.Enabled = false
	emitter.Parent = part
	emitter:Emit(30)
	Debris:AddItem(emitter, 2)
end

-- Позиция цели действия (для проверки расстояния)
local function targetPosition(target)
	if typeof(target) ~= "Instance" or not target.Parent then
		return nil
	end
	if target:IsA("Player") then
		local root = getRoot(target)
		return root and root.Position
	end
	local kind = target:GetAttribute("Kind")
	if kind == "Generator" then
		return target.PrimaryPart and target.PrimaryPart.Position
	elseif kind == "Hook" then
		local hp = target:FindFirstChild("HangPoint")
		return hp and hp.Position
	elseif kind == "Pallet" then
		local cf = target:GetAttribute("DropCFrame")
		return cf and cf.Position
	elseif kind == "Window" then
		return target.Position
	elseif kind == "ExitGate" then
		local sw = target:FindFirstChild("Switch")
		return sw and sw.Position
	end
	return nil
end

------------------------------------------------------------------------
-- Действия
------------------------------------------------------------------------

local function cancelAction(data)
	data.Action = nil
	data.PendingCheck = nil
	data.Player:SetAttribute("ActionName", nil)
	data.Player:SetAttribute("ActionProgress", nil)
end

local function canAct(data)
	if data.Status ~= "Playing" then
		return false
	end
	local t = now()
	if t < data.VaultUntil then
		return false
	end
	if data.Role == "Survivor" then
		return data.Health > 0
	end
	return t >= data.StunnedUntil and not data.Lunging
end

local function validateAction(data)
	local a = data.Action
	if not a or not canAct(data) then
		return false
	end
	local root = getRoot(data.Player)
	local pos = targetPosition(a.Target)
	if not root or not pos or flatDist(root.Position, pos) > Config.InteractRange + 2 then
		return false
	end
	local target = a.Target
	local kind = a.Kind
	if kind == "Repair" then
		return target:GetAttribute("Kind") == "Generator" and not target:GetAttribute("Done") and not gatesPowered
	elseif kind == "Kick" then
		return target:GetAttribute("Kind") == "Generator"
			and not target:GetAttribute("Done")
			and not gatesPowered
			and target:GetAttribute("Progress") > 0
			and not target:GetAttribute("Regressing")
			and not data.Carrying
	elseif kind == "Heal" then
		local td = participants[target]
		return td ~= nil and td ~= data and td.Status == "Playing" and td.Health < 2 and now() >= td.VaultUntil
	elseif kind == "Unhook" then
		local td = participants[target]
		return td ~= nil and td.Status == "Hooked"
	elseif kind == "OpenGate" then
		return target:GetAttribute("Kind") == "ExitGate"
			and target:GetAttribute("Powered")
			and not target:GetAttribute("Open")
	elseif kind == "Hook" then
		return data.Carrying ~= nil and target:GetAttribute("Kind") == "Hook" and target:GetAttribute("Occupant") == 0
	elseif kind == "Break" then
		return target:GetAttribute("Kind") == "Pallet" and target:GetAttribute("State") == "Dropped" and not data.Carrying
	end
	return false
end

------------------------------------------------------------------------
-- Персонажи: нести / вешать / убивать
------------------------------------------------------------------------

local function releaseCarry(sdata)
	local kdata = sdata.CarriedBy
	if kdata then
		kdata.Carrying = nil
	end
	sdata.CarriedBy = nil
	if sdata.CarryWeld then
		sdata.CarryWeld:Destroy()
		sdata.CarryWeld = nil
	end
	local char = sdata.Player.Character
	if char then
		for part, massless in sdata.SavedMassless or {} do
			if part.Parent then
				part.Massless = massless
				part.CollisionGroup = "Default"
			end
		end
		sdata.SavedMassless = nil
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.PlatformStand = false
		end
		local sroot = char:FindFirstChild("HumanoidRootPart")
		local kroot = kdata and getRoot(kdata.Player)
		if sroot and kroot then
			sroot.CFrame = kroot.CFrame * CFrame.new(0, 0, -3)
		end
		if sroot then
			pcall(function()
				sroot:SetNetworkOwner(sdata.Player)
			end)
		end
	end
end

local function startCarry(kdata, sdata)
	local kroot = getRoot(kdata.Player)
	local sroot = getRoot(sdata.Player)
	local shum = getHumanoid(sdata.Player)
	if not kroot or not sroot or not shum then
		return
	end
	cancelAction(sdata)
	sdata.Status = "Carried"
	sdata.CarriedBy = kdata
	sdata.Wiggle = 0
	kdata.Carrying = sdata
	sdata.SavedMassless = {}
	for _, d in sdata.Player.Character:GetDescendants() do
		if d:IsA("BasePart") then
			sdata.SavedMassless[d] = d.Massless
			d.Massless = true
			d.CollisionGroup = CARRIED_GROUP
		end
	end
	shum.PlatformStand = true
	sroot.CFrame = kroot.CFrame * CARRY_OFFSET
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = kroot
	weld.Part1 = sroot
	weld.Parent = sroot
	sdata.CarryWeld = weld
	pcall(function()
		sroot:SetNetworkOwner(kdata.Player)
	end)
	notifyAll(sdata.Player.DisplayName .. " схвачен маньяком!", RED)
end

local function disconnectCharacter(data)
	for _, c in data.Connections do
		c:Disconnect()
	end
	data.Connections = {}
end

local function removeFromGame(data, status, text, color)
	if not isInGame(data) then
		return
	end
	if data.CarriedBy then
		releaseCarry(data)
	end
	if data.Hook then
		data.Hook:SetAttribute("Occupant", 0)
		data.Hook = nil
	end
	cancelAction(data)
	data.Status = status
	disconnectCharacter(data)
	if text then
		notifyAll(text, color)
	end
	local player = data.Player
	-- небольшая пауза для эффекта, потом обратно в лобби
	task.delay(status == "Dead" and 1.5 or 0.2, function()
		if player.Parent and participants[player] == data then
			player:LoadCharacter()
		end
	end)
end

local function sacrifice(data, text)
	local root = getRoot(data.Player)
	if root and data.Status == "Hooked" then
		local fx = Instance.new("Part")
		fx.Anchored = true
		fx.CanCollide = false
		fx.Shape = Enum.PartType.Ball
		fx.Material = Enum.Material.Neon
		fx.Color = Color3.fromRGB(255, 60, 20)
		fx.Size = Vector3.new(2, 2, 2)
		fx.CFrame = root.CFrame
		fx.Parent = workspace
		TweenService:Create(fx, TweenInfo.new(1.4), { Size = Vector3.new(12, 12, 12), Transparency = 1 }):Play()
		Debris:AddItem(fx, 1.5)
	end
	removeFromGame(data, "Dead", text or (data.Player.DisplayName .. " принесён в жертву Сущности"), RED)
end

local function hang(kdata, hook)
	local sdata = kdata.Carrying
	if not sdata then
		return
	end
	releaseCarry(sdata)
	local sroot = getRoot(sdata.Player)
	local hp = hook:FindFirstChild("HangPoint")
	if not sroot or not hp then
		return
	end
	sdata.Status = "Hooked"
	sdata.Hook = hook
	sdata.HookTimer = 0
	sdata.HookCount += 1
	sdata.BleedOut = 0
	setDowned(sdata, false)
	hook:SetAttribute("Occupant", sdata.Player.UserId)
	sroot.Anchored = true
	sroot.CFrame = hp.CFrame
	if sdata.HookCount >= Config.MaxHooks then
		sacrifice(sdata)
	else
		notifyAll(
			string.format("%s на крюке! (стадия %d)", sdata.Player.DisplayName, sdata.HookCount),
			RED
		)
	end
end

local function unhook(sdata, rescuer)
	local hook = sdata.Hook
	local sroot = getRoot(sdata.Player)
	if hook then
		hook:SetAttribute("Occupant", 0)
	end
	sdata.Hook = nil
	sdata.Status = "Playing"
	sdata.Health = 1
	sdata.HealProgress = 0
	sdata.HookTimer = 0
	sdata.BoostUntil = now() + 1.5
	if sroot then
		sroot.Anchored = false
		local hp = hook and hook:FindFirstChild("HangPoint")
		if hp then
			sroot.CFrame = hp.CFrame * CFrame.new(0, -4, -3)
		end
	end
	notifyAll(rescuer.DisplayName .. " снял(а) " .. sdata.Player.DisplayName .. " с крюка", GREEN)
end

local function stunKiller(duration)
	local kdata = killerData
	if not kdata or kdata.Status ~= "Playing" then
		return
	end
	kdata.StunnedUntil = now() + duration
	kdata.Lunging = false
	kdata.AttackReadyAt = now() + duration
	cancelAction(kdata)
	local carried = kdata.Carrying
	if carried then
		releaseCarry(carried)
		carried.Status = "Playing"
		carried.Health = 1
		carried.BoostUntil = now() + Config.SurvivorHitBoostTime
		setDowned(carried, false)
		notifyAll(carried.Player.DisplayName .. " вырвался из рук маньяка!", GREEN)
	end
	notify(kdata.Player, "Оглушён!", YELLOW)
end

local function hitSurvivor(sdata)
	cancelAction(sdata)
	sdata.Health -= 1
	sdata.HealProgress = 0
	local root = getRoot(sdata.Player)
	if root then
		bloodBurst(root)
	end
	if sdata.Health >= 1 then
		sdata.BoostUntil = now() + Config.SurvivorHitBoostTime
		notify(sdata.Player, "Тебя ранили! Беги!", RED)
	else
		sdata.Health = 0
		sdata.BleedOut = 0
		setDowned(sdata, true)
		notifyAll(sdata.Player.DisplayName .. " повержен!", RED)
	end
end

------------------------------------------------------------------------
-- Генераторы и ворота
------------------------------------------------------------------------

local function powerGates()
	gatesPowered = true
	for _, gate in map.ExitGates:GetChildren() do
		gate:SetAttribute("Powered", true)
		local sw = gate:FindFirstChild("Switch")
		if sw then
			sw.Color = Color3.fromRGB(150, 130, 40)
		end
	end
	setState("GensLeft", 0)
	notifyAll("Все генераторы починены! Ворота запитаны — открывайте их!", YELLOW)
end

local function completeGenerator(gen)
	gen:SetAttribute("Progress", 1)
	gen:SetAttribute("Done", true)
	gen:SetAttribute("Regressing", false)
	local bulb = gen:FindFirstChild("Bulb")
	if bulb then
		bulb.Color = Color3.fromRGB(255, 230, 140)
		bulb.Material = Enum.Material.Neon
		local light = bulb:FindFirstChildOfClass("PointLight")
		if light then
			light.Enabled = true
		end
	end
	gensDone += 1
	local left = math.max(Config.GeneratorsRequired - gensDone, 0)
	setState("GensLeft", left)
	if left > 0 then
		notifyAll("Генератор починен! Осталось: " .. left, YELLOW)
	else
		powerGates()
	end
end

local function openGate(gate)
	gate:SetAttribute("Progress", 1)
	gate:SetAttribute("Open", true)
	local door = gate:FindFirstChild("Door")
	if door then
		door.CanCollide = false
		TweenService:Create(door, TweenInfo.new(2), { CFrame = door.CFrame + Vector3.new(0, 11.5, 0) }):Play()
	end
	if not endgameDeadline then
		endgameDeadline = now() + Config.EndGameCollapseTime
		setState("EndGame", true)
		notifyAll("Ворота открыты! Обрушение Сущности началось — бегите!", YELLOW)
	else
		notifyAll("Вторые ворота открыты!", YELLOW)
	end
end

local function updateGateLamps(gate)
	local progress = gate:GetAttribute("Progress")
	for i = 1, 3 do
		local lamp = gate:FindFirstChild("Lamp" .. i)
		if lamp then
			lamp.Color = progress >= i / 3 and Color3.fromRGB(255, 40, 40) or Color3.fromRGB(40, 0, 0)
		end
	end
end

------------------------------------------------------------------------
-- Проверки навыка
------------------------------------------------------------------------

local function applySkillCheck(data, result)
	data.PendingCheck = nil
	local a = data.Action
	if not a then
		return
	end
	if a.Kind == "Repair" then
		local gen = a.Target
		local p = gen:GetAttribute("Progress")
		if result == "great" then
			gen:SetAttribute("Progress", math.min(p + Config.SkillCheckGreatBonus, 0.999))
		elseif result == "fail" then
			gen:SetAttribute("Progress", math.max(p - Config.SkillCheckFailPenalty, 0))
			noise(gen.PrimaryPart.Position)
			notify(data.Player, "Генератор взорвался! Маньяк услышал шум.", RED)
			local body = gen.PrimaryPart
			if body then
				local sparks = Instance.new("Sparkles")
				sparks.SparkleColor = Color3.fromRGB(255, 120, 40)
				sparks.Parent = body
				Debris:AddItem(sparks, 1.5)
			end
		end
	elseif a.Kind == "Heal" then
		local td = participants[a.Target]
		if not td then
			return
		end
		if result == "great" then
			td.HealProgress = math.min(td.HealProgress + Config.SkillCheckGreatBonus, 0.999)
		elseif result == "fail" then
			td.HealProgress = math.max(td.HealProgress - Config.SkillCheckFailPenalty, 0)
			local root = getRoot(data.Player)
			if root then
				noise(root.Position)
			end
			notify(data.Player, "Провал! Маньяк услышал крик.", RED)
		end
	end
end

local function tickSkillChecks(data, t)
	local a = data.Action
	if data.PendingCheck then
		if t > data.PendingCheck.Deadline then
			applySkillCheck(data, "fail")
		end
		return
	end
	if not a or (a.Kind ~= "Repair" and a.Kind ~= "Heal") then
		return
	end
	if t < data.NextCheckRoll then
		return
	end
	data.NextCheckRoll = t + 1
	if rng:NextNumber() < Config.SkillCheckChancePerSecond then
		skillCheckCounter += 1
		local zone = rng:NextNumber(0.45, 0.8)
		data.PendingCheck = { Id = skillCheckCounter, Deadline = t + Config.SkillCheckDuration + 1.5 }
		Remotes.SkillCheck:FireClient(data.Player, skillCheckCounter, zone)
	end
end

------------------------------------------------------------------------
-- Мгновенные действия
------------------------------------------------------------------------

local function doVault(data, obstacle)
	local root = getRoot(data.Player)
	if not root then
		return
	end
	local ocf = obstacle.CFrame
	if flatDist(root.Position, ocf.Position) > 5 then
		return
	end
	local rel = ocf:PointToObjectSpace(root.Position)
	local side = rel.Z >= 0 and 1 or -1
	local x = math.clamp(rel.X, -1.2, 1.2)
	local y = root.Position.Y
	local function at(z)
		local w = ocf:PointToWorldSpace(Vector3.new(x, 0, z))
		return Vector3.new(w.X, y, w.Z)
	end
	local mid = at(0) + Vector3.new(0, 2.5, 0)
	local finish = at(-side * 3.4)
	local dir = (finish - root.Position) * Vector3.new(1, 0, 1)
	if dir.Magnitude < 0.1 then
		return
	end
	dir = dir.Unit
	local duration
	if data.Role == "Killer" then
		duration = 1.6
	else
		duration = data.Sprinting and 0.55 or 0.95
		if data.Sprinting and killerData then
			local kroot = getRoot(killerData.Player)
			if kroot and flatDist(kroot.Position, root.Position) < Config.TerrorRadius then
				noise(root.Position)
			end
		end
	end
	data.VaultUntil = now() + duration
	cancelAction(data)
	root.Anchored = true
	task.spawn(function()
		local info = TweenInfo.new(duration / 2, Enum.EasingStyle.Linear)
		local t1 = TweenService:Create(root, info, { CFrame = CFrame.lookAt(mid, mid + dir) })
		t1:Play()
		t1.Completed:Wait()
		local t2 = TweenService:Create(root, info, { CFrame = CFrame.lookAt(finish, finish + dir) })
		t2:Play()
		t2.Completed:Wait()
		if root.Parent and data.Status == "Playing" then
			root.Anchored = false
		end
	end)
end

local function dropPallet(data, pallet)
	local root = getRoot(data.Player)
	local dropCF = pallet:GetAttribute("DropCFrame")
	if not root or not dropCF or pallet:GetAttribute("State") ~= "Up" then
		return
	end
	if flatDist(root.Position, dropCF.Position) > Config.InteractRange then
		return
	end
	pallet:SetAttribute("State", "Dropped")
	pallet.CFrame = dropCF
	pallet.CanCollide = true
	if killerData and killerData.Status == "Playing" then
		local kroot = getRoot(killerData.Player)
		if kroot then
			local rel = dropCF:PointToObjectSpace(kroot.Position)
			if math.abs(rel.X) < 3.5 and math.abs(rel.Z) < 2.2 then
				-- маньяк стоял прямо под паллетой — отталкиваем на его сторону
				local side = rel.Z >= 0 and 1 or -1
				local w = dropCF:PointToWorldSpace(Vector3.new(rel.X, 0, side * 2.6))
				kroot.CFrame = CFrame.new(w.X, kroot.Position.Y, w.Z) * kroot.CFrame.Rotation
			end
			if flatDist(kroot.Position, dropCF.Position) <= Config.PalletStunRange then
				stunKiller(Config.PalletStunTime)
			end
		end
	end
end

------------------------------------------------------------------------
-- Обработчики клиентских событий
------------------------------------------------------------------------

local function onBeginAction(player, kind, target)
	local data = participants[player]
	if not Match.Active or not data or typeof(kind) ~= "string" or typeof(target) ~= "Instance" then
		return
	end
	local allowed = (data.Role == "Survivor" and SURVIVOR_ACTIONS or KILLER_ACTIONS)[kind]
	if not allowed or data.Action or not canAct(data) then
		return
	end

	if kind == "Vault" then
		local okind = target:GetAttribute("Kind")
		if okind == "Window" or (okind == "Pallet" and data.Role == "Survivor" and target:GetAttribute("State") == "Dropped") then
			if not data.Carrying then
				doVault(data, target)
			end
		end
		return
	elseif kind == "DropPallet" then
		if target:GetAttribute("Kind") == "Pallet" then
			dropPallet(data, target)
		end
		return
	elseif kind == "Pickup" then
		local td = target:IsA("Player") and participants[target]
		local root = getRoot(player)
		local tpos = targetPosition(target)
		if
			td
			and not data.Carrying
			and td.Status == "Playing"
			and td.Health == 0
			and now() >= td.VaultUntil
			and root
			and tpos
			and flatDist(root.Position, tpos) <= Config.InteractRange
		then
			startCarry(data, td)
		end
		return
	end

	data.Action = { Kind = kind, Target = target, Time = 0 }
	if not validateAction(data) then
		data.Action = nil
		return
	end
	data.NextCheckRoll = now() + 1
	if kind == "Repair" then
		target:SetAttribute("Regressing", false)
	end
end

local function onEndAction(player)
	local data = participants[player]
	if data and data.Action then
		cancelAction(data)
	end
end

local function onAttack(player)
	local data = participants[player]
	if not Match.Active or not data or data.Role ~= "Killer" then
		return
	end
	local t = now()
	if not canAct(data) or data.Carrying or data.Action or t < data.AttackReadyAt then
		return
	end
	data.Lunging = true
	data.LungeUntil = t + Config.KillerLungeTime
	data.AttackReadyAt = math.huge
end

local function onSprint(player, value)
	local data = participants[player]
	if data then
		data.Sprinting = value == true
	end
end

local function onSkillCheck(player, id, result)
	local data = participants[player]
	if not data or not data.PendingCheck or data.PendingCheck.Id ~= id then
		return
	end
	if result ~= "great" and result ~= "good" then
		result = "fail"
	end
	applySkillCheck(data, result)
end

Remotes.BeginAction.OnServerEvent:Connect(onBeginAction)
Remotes.EndAction.OnServerEvent:Connect(onEndAction)
Remotes.Attack.OnServerEvent:Connect(onAttack)
Remotes.Sprint.OnServerEvent:Connect(onSprint)
Remotes.SkillCheck.OnServerEvent:Connect(onSkillCheck)

------------------------------------------------------------------------
-- Подготовка персонажей
------------------------------------------------------------------------

local function dressKiller(char)
	for _, d in char:GetDescendants() do
		if d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then
			d:Destroy()
		elseif d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			d.Color = Color3.fromRGB(45, 25, 25)
		end
	end
	local head = char:FindFirstChild("Head")
	if head then
		local face = head:FindFirstChildOfClass("Decal")
		if face then
			face:Destroy()
		end
		local mask = Instance.new("Part")
		mask.Name = "KillerMask"
		mask.Size = Vector3.new(1.1, 1.2, 0.25)
		mask.Color = Color3.fromRGB(230, 225, 210)
		mask.Material = Enum.Material.SmoothPlastic
		mask.CanCollide = false
		mask.Massless = true
		mask.CFrame = head.CFrame * CFrame.new(0, 0, -0.62)
		local w = Instance.new("WeldConstraint")
		w.Part0 = head
		w.Part1 = mask
		w.Parent = mask
		mask.Parent = char
	end
	local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
	if hand then
		local blade = Instance.new("Part")
		blade.Name = "Cleaver"
		blade.Size = Vector3.new(0.2, 1, 3)
		blade.Color = Color3.fromRGB(170, 170, 175)
		blade.Material = Enum.Material.Metal
		blade.CanCollide = false
		blade.Massless = true
		blade.CFrame = hand.CFrame * CFrame.new(0, -hand.Size.Y / 2 - 0.2, -1.2)
		local w = Instance.new("WeldConstraint")
		w.Part0 = hand
		w.Part1 = blade
		w.Parent = blade
		blade.Parent = char
	end
end

local function setupCharacter(data, spawnCF)
	local player = data.Player
	local hum = getHumanoid(player)
	if not hum or hum.Health <= 0 then
		player:LoadCharacter()
		hum = getHumanoid(player)
	end
	local char = player.Character
	if not char or not hum then
		return false
	end
	disconnectCharacter(data)
	char:PivotTo(spawnCF)
	hum.UseJumpPower = true
	hum.JumpPower = 0
	hum.JumpHeight = 0
	data.BaseHipHeight = hum.HipHeight
	if data.Role == "Killer" then
		dressKiller(char)
	end
	table.insert(
		data.Connections,
		hum.Died:Connect(function()
			if data.Role == "Killer" then
				data.Status = "Dead"
			else
				removeFromGame(data, "Dead", player.DisplayName .. " погиб", RED)
			end
		end)
	)
	return true
end

------------------------------------------------------------------------
-- Старт / конец
------------------------------------------------------------------------

local function newData(player, role)
	return {
		Player = player,
		Role = role,
		Health = 2,
		Status = "Playing",
		HookCount = 0,
		HookTimer = 0,
		BleedOut = 0,
		Wiggle = 0,
		HealProgress = 0,
		Sprinting = false,
		BoostUntil = 0,
		StunnedUntil = 0,
		AttackReadyAt = 0,
		LungeUntil = 0,
		Lunging = false,
		SlowUntil = 0,
		VaultUntil = 0,
		NextCheckRoll = 0,
		Connections = {},
	}
end

function Match.Start(playerList)
	map = MapBuilder.BuildMap()
	participants = {}
	killerData = nil
	gensDone = 0
	gatesPowered = false
	endgameDeadline = nil
	startTime = now()
	soloTest = #playerList == 1

	local killerIndex = soloTest and 0 or rng:NextInteger(1, #playerList)
	for i, player in playerList do
		local data = newData(player, i == killerIndex and "Killer" or "Survivor")
		participants[player] = data
		if data.Role == "Killer" then
			killerData = data
		end
	end

	setState("GensLeft", Config.GeneratorsRequired)
	setState("EndGame", false)
	setState("EndGameTimer", Config.EndGameCollapseTime)
	setState("KillerName", killerData and killerData.Player.DisplayName or "—")
	setState("Phase", "InGame")
	Match.Active = true

	local sIndex = 0
	for player, data in participants do
		player:SetAttribute("Role", data.Role)
		player:SetAttribute("Status", data.Status)
		player:SetAttribute("Health", data.Health)
		local cf
		if data.Role == "Killer" then
			cf = CFrame.new(map.KillerSpawn)
		else
			sIndex += 1
			local angle = sIndex * math.pi / 2
			cf = CFrame.new(map.SurvivorSpawn + Vector3.new(math.cos(angle) * 4, 0, math.sin(angle) * 4))
		end
		if not setupCharacter(data, cf) then
			data.Status = "Dead"
		end
	end
	for player, data in participants do
		Remotes.Notify:FireClient(
			player,
			data.Role == "Killer" and "Ты — МАНЬЯК. Принеси всех в жертву!" or "Ты — ВЫЖИВШИЙ. Почини генераторы и сбеги!",
			data.Role == "Killer" and RED or GREEN
		)
	end
end

function Match.End(reason)
	if not Match.Active then
		return
	end
	Match.Active = false

	local results = {}
	local escaped, dead = 0, 0
	for player, data in participants do
		if data.Role == "Survivor" then
			if data.Status == "Escaped" then
				escaped += 1
			elseif data.Status == "Dead" or data.Status == "Left" then
				dead += 1
			end
		end
		table.insert(results, { Name = player.DisplayName, Role = data.Role, Status = data.Status })
	end
	local title
	if soloTest then
		title = escaped > 0 and "Тестовый раунд: ты сбежал!" or "Тестовый раунд окончен"
	elseif escaped > dead then
		title = "Победа выживших!"
	elseif dead > escaped then
		title = "Победа маньяка!"
	else
		title = "Ничья"
	end
	Remotes.Results:FireAllClients(title, reason or "", results)

	for player, data in participants do
		if data.CarriedBy then
			releaseCarry(data)
		end
		local root = getRoot(player)
		if root then
			root.Anchored = false
		end
		disconnectCharacter(data)
		for _, attr in
			{ "Role", "Status", "Health", "HookCount", "HookProgress", "BleedOut", "Wiggle", "ActionName", "ActionProgress", "Stunned", "Carrying" }
		do
			player:SetAttribute(attr, nil)
		end
		if player.Parent then
			task.spawn(function()
				player:LoadCharacter()
			end)
		end
	end
	participants = {}
	killerData = nil
	setState("EndGame", false)
	if map then
		map.Model:Destroy()
		map = nil
	end
end

function Match.OnPlayerRemoving(player)
	local data = participants[player]
	if not data then
		return
	end
	if data.Carrying then
		releaseCarry(data.Carrying)
		data.Carrying.Status = "Playing"
	end
	if data.CarriedBy then
		releaseCarry(data)
	end
	if data.Hook then
		data.Hook:SetAttribute("Occupant", 0)
		data.Hook = nil
	end
	disconnectCharacter(data)
	if data.Status ~= "Dead" and data.Status ~= "Escaped" then
		data.Status = "Left"
		notifyAll(player.DisplayName .. " покинул игру", YELLOW)
	end
end

------------------------------------------------------------------------
-- Главный цикл раунда (каждый кадр)
------------------------------------------------------------------------

local function survivorSpeed(data, t)
	if data.Action or t < data.VaultUntil then
		return 0
	end
	if data.Health == 0 then
		return Config.SurvivorCrawlSpeed
	end
	if t < data.BoostUntil then
		return Config.SurvivorHitBoostSpeed
	end
	return data.Sprinting and Config.SurvivorSprintSpeed or Config.SurvivorWalkSpeed
end

local function killerSpeed(data, t)
	if t < data.StunnedUntil or data.Action or t < data.VaultUntil then
		return 0
	end
	if data.Lunging then
		return Config.KillerLungeSpeed
	end
	if t < data.SlowUntil then
		return Config.AttackSlowSpeed
	end
	if data.Carrying then
		return Config.KillerCarrySpeed
	end
	return Config.KillerSpeed
end

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

local function tryHit(kdata)
	local kroot = getRoot(kdata.Player)
	if not kroot then
		return false
	end
	local forward = kroot.CFrame.LookVector * Vector3.new(1, 0, 1)
	if forward.Magnitude < 0.01 then
		return false
	end
	forward = forward.Unit
	local exclude = {}
	for p in participants do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	raycastParams.FilterDescendantsInstances = exclude
	for _, sdata in survivors() do
		local sroot = getRoot(sdata.Player)
		if sdata.Status == "Playing" and sdata.Health > 0 and sroot then
			local offset = sroot.Position - kroot.Position
			local flat = offset * Vector3.new(1, 0, 1)
			if flat.Magnitude <= Config.AttackRange and (flat.Magnitude < 1 or forward:Dot(flat.Unit) >= 0.3) then
				if not workspace:Raycast(kroot.Position, offset, raycastParams) then
					hitSurvivor(sdata)
					return true
				end
			end
		end
	end
	return false
end

function Match.Update(dt)
	if not Match.Active then
		return
	end
	local t = now()

	-- Действия
	local repairers = {}
	local healers = {}
	local gateOpeners = {}
	for _, data in participants do
		local a = data.Action
		if a then
			if not validateAction(data) then
				cancelAction(data)
			else
				a.Time += dt
				if a.Kind == "Repair" then
					repairers[a.Target] = (repairers[a.Target] or 0) + 1
				elseif a.Kind == "Heal" then
					healers[a.Target] = (healers[a.Target] or 0) + 1
				elseif a.Kind == "OpenGate" then
					gateOpeners[a.Target] = true
				end
			end
		end
	end

	for gen, count in repairers do
		local p = gen:GetAttribute("Progress") + dt / Config.GeneratorRepairTime * count
		if p >= 1 then
			completeGenerator(gen)
		else
			gen:SetAttribute("Progress", p)
		end
	end
	if map then
		for _, gen in map.Generators:GetChildren() do
			if gen:GetAttribute("Regressing") and not repairers[gen] then
				local p = gen:GetAttribute("Progress") - Config.GeneratorRegressPerSecond * dt
				if p <= 0 then
					gen:SetAttribute("Progress", 0)
					gen:SetAttribute("Regressing", false)
				else
					gen:SetAttribute("Progress", p)
				end
			end
		end
	end
	for target, count in healers do
		local td = participants[target]
		td.HealProgress += dt / Config.HealTime * count
		if td.HealProgress >= 1 then
			td.HealProgress = 0
			td.Health += 1
			if td.Health == 1 then
				setDowned(td, false)
			end
			notify(target, td.Health == 2 and "Ты полностью вылечен" or "Тебя подняли!", GREEN)
		end
	end
	for gate in gateOpeners do
		local p = gate:GetAttribute("Progress") + dt / Config.OpenGateTime
		if p >= 1 then
			openGate(gate)
		else
			gate:SetAttribute("Progress", p)
		end
		updateGateLamps(gate)
	end

	-- Завершение действий с фиксированной длительностью + прогресс для UI
	for _, data in participants do
		local a = data.Action
		if a then
			local duration = TIMED_ACTIONS[a.Kind]
			local progress
			if duration then
				progress = a.Time / duration
				if progress >= 1 then
					cancelAction(data)
					if a.Kind == "Unhook" then
						local td = participants[a.Target]
						if td and td.Status == "Hooked" then
							unhook(td, data.Player)
						end
					elseif a.Kind == "Hook" then
						hang(data, a.Target)
					elseif a.Kind == "Break" then
						a.Target:SetAttribute("State", "Broken")
						a.Target:Destroy()
					elseif a.Kind == "Kick" then
						local gen = a.Target
						gen:SetAttribute("Progress", math.max(gen:GetAttribute("Progress") - Config.GeneratorKickRegression, 0))
						gen:SetAttribute("Regressing", gen:GetAttribute("Progress") > 0)
						notifyAll("Маньяк повредил генератор", RED)
					end
					progress = nil
				end
			elseif a.Kind == "Repair" or a.Kind == "OpenGate" then
				progress = a.Target:GetAttribute("Progress")
			elseif a.Kind == "Heal" then
				local td = participants[a.Target]
				progress = td and td.HealProgress
			end
			if data.Action then
				data.Player:SetAttribute("ActionName", a.Kind)
				data.Player:SetAttribute("ActionProgress", progress)
				tickSkillChecks(data, t)
			end
		elseif data.PendingCheck then
			data.PendingCheck = nil
		end
	end

	-- Атака маньяка
	if killerData and killerData.Lunging then
		if tryHit(killerData) then
			killerData.Lunging = false
			killerData.SlowUntil = t + Config.AttackCooldownHit
			killerData.AttackReadyAt = t + Config.AttackCooldownHit
		elseif t >= killerData.LungeUntil then
			killerData.Lunging = false
			killerData.SlowUntil = t + Config.AttackCooldownMiss
			killerData.AttackReadyAt = t + Config.AttackCooldownMiss
		end
	end

	-- Состояния выживших
	for _, data in survivors() do
		if data.Status == "Hooked" then
			data.HookTimer += dt
			if data.HookTimer >= Config.HookStageTime then
				data.HookTimer = 0
				data.HookCount += 1
				if data.HookCount >= Config.MaxHooks then
					sacrifice(data)
				else
					notifyAll(data.Player.DisplayName .. " борется с Сущностью!", RED)
				end
			end
		elseif data.Status == "Carried" then
			data.Wiggle += dt / Config.WiggleTime
			if data.Wiggle >= 1 then
				data.Wiggle = 0
				local kdata = data.CarriedBy
				releaseCarry(data)
				data.Status = "Playing"
				data.Health = 1
				data.BoostUntil = t + Config.SurvivorHitBoostTime
				setDowned(data, false)
				if kdata then
					kdata.StunnedUntil = t + 3
				end
				notifyAll(data.Player.DisplayName .. " вырвался из рук маньяка!", GREEN)
			end
		elseif data.Status == "Playing" and data.Health == 0 and not healers[data.Player] then
			data.BleedOut += dt
			if data.BleedOut >= Config.BleedOutTime then
				removeFromGame(data, "Dead", data.Player.DisplayName .. " истёк кровью", RED)
			end
		end

		-- Побег через открытые ворота
		if data.Status == "Playing" and map then
			local root = getRoot(data.Player)
			if root then
				for _, gate in map.ExitGates:GetChildren() do
					local zone = gate:FindFirstChild("EscapeZone")
					if gate:GetAttribute("Open") and zone then
						local rel = zone.CFrame:PointToObjectSpace(root.Position)
						local half = zone.Size / 2
						if math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z then
							removeFromGame(data, "Escaped", data.Player.DisplayName .. " сбежал!", GREEN)
							break
						end
					end
				end
			end
		end
	end

	-- Скорость и атрибуты для клиентов
	for player, data in participants do
		local hum = getHumanoid(player)
		if hum and isInGame(data) then
			hum.WalkSpeed = data.Role == "Killer" and killerSpeed(data, t) or survivorSpeed(data, t)
		end
		player:SetAttribute("Status", data.Status)
		player:SetAttribute("Health", data.Health)
		player:SetAttribute("HookCount", data.HookCount)
		player:SetAttribute("HookProgress", data.Status == "Hooked" and data.HookTimer / Config.HookStageTime or nil)
		player:SetAttribute(
			"BleedOut",
			(data.Status == "Playing" and data.Health == 0) and data.BleedOut / Config.BleedOutTime or nil
		)
		player:SetAttribute("Wiggle", data.Status == "Carried" and data.Wiggle or nil)
		player:SetAttribute("Stunned", t < data.StunnedUntil)
		player:SetAttribute("Carrying", data.Carrying ~= nil)
	end

	-- Обрушение (эндгейм)
	if endgameDeadline then
		local left = endgameDeadline - t
		setState("EndGameTimer", math.max(math.ceil(left), 0))
		if left <= 0 then
			for _, data in survivors() do
				if isInGame(data) then
					removeFromGame(data, "Dead", data.Player.DisplayName .. " забран Сущностью", RED)
				end
			end
		end
	end

	-- Условия окончания раунда
	local remaining = 0
	for _, data in survivors() do
		if isInGame(data) then
			remaining += 1
		end
	end
	if remaining == 0 then
		Match.End()
	elseif not soloTest and (not killerData or killerData.Status ~= "Playing" or not killerData.Player.Parent) then
		Match.End("Маньяк выбыл из игры")
	elseif t - startTime > Config.MaxRoundTime then
		Match.End("Время вышло")
	end
end

return Match
