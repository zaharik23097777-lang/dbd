-- Клиент: управление, поиск ближайшего действия, HUD, ауры, звук сердцебиения.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local gameState = ReplicatedStorage:WaitForChild("GameState")
local ui = UI.new(player:WaitForChild("PlayerGui"))

local VAULT_RANGE = 4.5

local currentPrimary -- { Kind, Target, Text }
local currentSecondary
local holding = false
local sprinting = false
local spectating = false
local spectateIndex = 0

------------------------------------------------------------------------
-- Вспомогательное
------------------------------------------------------------------------

local function getRoot(p)
	local char = p and p.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function flatDist(a, b)
	local d = a - b
	return Vector3.new(d.X, 0, d.Z).Magnitude
end

local function myRole()
	return player:GetAttribute("Role")
end

local function myStatus()
	return player:GetAttribute("Status")
end

local function getMap()
	return workspace:FindFirstChild("Map")
end

local function objectPosition(obj)
	if obj:IsA("Player") then
		local r = getRoot(obj)
		return r and r.Position
	end
	local kind = obj:GetAttribute("Kind")
	if kind == "Generator" then
		return obj.PrimaryPart and obj.PrimaryPart.Position
	elseif kind == "Hook" then
		local hp = obj:FindFirstChild("HangPoint")
		return hp and hp.Position
	elseif kind == "Pallet" then
		local cf = obj:GetAttribute("DropCFrame")
		return cf and cf.Position
	elseif kind == "Window" then
		return obj.Position
	elseif kind == "ExitGate" then
		local sw = obj:FindFirstChild("Switch")
		return sw and sw.Position
	end
	return nil
end

-- Выбирает ближайший вариант из списка кандидатов
local function nearest(rootPos, candidates)
	local best, bestDist
	for _, c in candidates do
		local pos = objectPosition(c.Target)
		if pos then
			local d = flatDist(rootPos, pos)
			if d <= (c.Range or Config.InteractRange) and (not bestDist or d < bestDist) then
				best, bestDist = c, d
			end
		end
	end
	return best
end

local function folderChildren(name)
	local map = getMap()
	local f = map and map:FindFirstChild(name)
	return f and f:GetChildren() or {}
end

------------------------------------------------------------------------
-- Поиск доступных действий
------------------------------------------------------------------------

local function findActions()
	local root = getRoot(player)
	local role = myRole()
	if not root or not role or myStatus() ~= "Playing" then
		return nil, nil
	end
	local pos = root.Position
	local primary, secondary = {}, {}

	if role == "Survivor" then
		if (player:GetAttribute("Health") or 0) <= 0 then
			return nil, nil
		end
		for _, p in Players:GetPlayers() do
			if p ~= player and p:GetAttribute("Role") == "Survivor" then
				local status = p:GetAttribute("Status")
				local health = p:GetAttribute("Health") or 2
				if status == "Hooked" then
					table.insert(primary, { Kind = "Unhook", Target = p, Text = "Снять " .. p.DisplayName .. " с крюка" })
				elseif status == "Playing" and health < 2 then
					local text = health == 0 and ("Поднять " .. p.DisplayName) or ("Лечить " .. p.DisplayName)
					table.insert(primary, { Kind = "Heal", Target = p, Text = text })
				end
			end
		end
		if (gameState:GetAttribute("GensLeft") or 0) > 0 then
			for _, gen in folderChildren("Generators") do
				if not gen:GetAttribute("Done") then
					table.insert(primary, { Kind = "Repair", Target = gen, Text = "Чинить генератор" })
				end
			end
		end
		for _, gate in folderChildren("ExitGates") do
			if gate:GetAttribute("Powered") and not gate:GetAttribute("Open") then
				table.insert(primary, { Kind = "OpenGate", Target = gate, Text = "Открыть ворота" })
			end
		end
		for _, pallet in folderChildren("Pallets") do
			local state = pallet:GetAttribute("State")
			if state == "Up" then
				table.insert(secondary, { Kind = "DropPallet", Target = pallet, Text = "Опустить паллету" })
			elseif state == "Dropped" then
				table.insert(secondary, { Kind = "Vault", Target = pallet, Text = "Перепрыгнуть", Range = VAULT_RANGE })
			end
		end
		for _, window in folderChildren("Windows") do
			table.insert(secondary, { Kind = "Vault", Target = window, Text = "Перелезть", Range = VAULT_RANGE })
		end
	else
		if player:GetAttribute("Stunned") then
			return nil, nil
		end
		if player:GetAttribute("Carrying") then
			for _, hook in folderChildren("Hooks") do
				if hook:GetAttribute("Occupant") == 0 then
					table.insert(primary, { Kind = "Hook", Target = hook, Text = "Повесить на крюк" })
				end
			end
		else
			for _, p in Players:GetPlayers() do
				if p:GetAttribute("Role") == "Survivor" and p:GetAttribute("Status") == "Playing" and p:GetAttribute("Health") == 0 then
					table.insert(primary, { Kind = "Pickup", Target = p, Text = "Поднять " .. p.DisplayName })
				end
			end
			for _, pallet in folderChildren("Pallets") do
				if pallet:GetAttribute("State") == "Dropped" then
					table.insert(primary, { Kind = "Break", Target = pallet, Text = "Сломать паллету" })
				end
			end
			for _, gen in folderChildren("Generators") do
				if
					not gen:GetAttribute("Done")
					and (gen:GetAttribute("Progress") or 0) > 0
					and not gen:GetAttribute("Regressing")
					and (gameState:GetAttribute("GensLeft") or 0) > 0
				then
					table.insert(primary, { Kind = "Kick", Target = gen, Text = "Повредить генератор" })
				end
			end
			for _, window in folderChildren("Windows") do
				table.insert(secondary, { Kind = "Vault", Target = window, Text = "Перелезть", Range = VAULT_RANGE })
			end
		end
	end
	return nearest(pos, primary), nearest(pos, secondary)
end

------------------------------------------------------------------------
-- Ввод
------------------------------------------------------------------------

local function onInteract(_, state)
	if state == Enum.UserInputState.Begin then
		if currentPrimary then
			holding = true
			Remotes.BeginAction:FireServer(currentPrimary.Kind, currentPrimary.Target)
		end
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		if holding then
			holding = false
			Remotes.EndAction:FireServer()
		end
	end
	return Enum.ContextActionResult.Sink
end

local function onSecondary(_, state)
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Sink
	end
	local check = ui.GetSkillCheck()
	if check then
		check.Press()
	elseif currentSecondary then
		Remotes.BeginAction:FireServer(currentSecondary.Kind, currentSecondary.Target)
	end
	return Enum.ContextActionResult.Sink
end

local function onSprint(_, state, input)
	if input.UserInputType == Enum.UserInputType.Touch then
		if state == Enum.UserInputState.Begin then
			sprinting = not sprinting
			Remotes.Sprint:FireServer(sprinting)
		end
	elseif state == Enum.UserInputState.Begin then
		sprinting = true
		Remotes.Sprint:FireServer(true)
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		sprinting = false
		Remotes.Sprint:FireServer(false)
	end
	return Enum.ContextActionResult.Pass
end

local function onAttack(_, state)
	if state == Enum.UserInputState.Begin then
		Remotes.Attack:FireServer()
	end
	return Enum.ContextActionResult.Pass
end

local boundRole
local function bindControls(role)
	if boundRole == role then
		return
	end
	boundRole = role
	for _, name in { "DBDInteract", "DBDSecondary", "DBDSprint", "DBDAttack" } do
		ContextActionService:UnbindAction(name)
	end
	if not role then
		return
	end
	ContextActionService:BindActionAtPriority("DBDInteract", onInteract, true, 3000, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
	ContextActionService:SetTitle("DBDInteract", "E")
	ContextActionService:SetPosition("DBDInteract", UDim2.new(1, -170, 1, -150))
	ContextActionService:BindActionAtPriority(
		"DBDSecondary",
		onSecondary,
		true,
		3000,
		Enum.KeyCode.Space,
		Enum.KeyCode.ButtonA
	)
	ContextActionService:SetTitle("DBDSecondary", "␣")
	ContextActionService:SetPosition("DBDSecondary", UDim2.new(1, -100, 1, -100))
	if role == "Survivor" then
		ContextActionService:BindAction("DBDSprint", onSprint, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
		ContextActionService:SetTitle("DBDSprint", "Бег")
		ContextActionService:SetPosition("DBDSprint", UDim2.new(1, -170, 1, -80))
	else
		ContextActionService:BindAction("DBDAttack", onAttack, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
		ContextActionService:SetTitle("DBDAttack", "Удар")
		ContextActionService:SetPosition("DBDAttack", UDim2.new(1, -240, 1, -110))
	end
end

------------------------------------------------------------------------
-- События сервера
------------------------------------------------------------------------

Remotes.Notify.OnClientEvent:Connect(function(text, color)
	ui.Notify(text, color)
end)

Remotes.SkillCheck.OnClientEvent:Connect(function(id, zone)
	ui.StartSkillCheck(zone, Config.SkillCheckDuration, function(result)
		Remotes.SkillCheck:FireServer(id, result)
		if result == "great" then
			ui.Notify("Отлично!", Color3.fromRGB(255, 255, 255))
		elseif result == "fail" then
			ui.Notify("Провал!", Color3.fromRGB(255, 70, 70))
		end
	end)
end)

Remotes.Noise.OnClientEvent:Connect(function(position)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.Position = position + Vector3.new(0, 4, 0)
	p.Parent = camera
	local bb = Instance.new("BillboardGui")
	bb.AlwaysOnTop = true
	bb.Size = UDim2.new(0, 60, 0, 60)
	bb.Parent = p
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Text = "!"
	l.TextScaled = true
	l.Font = Enum.Font.GothamBlack
	l.TextColor3 = Color3.fromRGB(255, 200, 40)
	l.Parent = bb
	Debris:AddItem(p, 4)
	ui.Notify("Ты слышишь шум!", Color3.fromRGB(255, 200, 40))
end)

Remotes.Results.OnClientEvent:Connect(function(title, reason, rows)
	ui.ShowResults(title, reason, rows, Config.ResultsTime)
end)

------------------------------------------------------------------------
-- Ауры (подсветка сквозь стены)
------------------------------------------------------------------------

local auras = {} -- [Instance] = Highlight

local function updateAuras()
	local wanted = {}
	local role = myRole()
	local status = myStatus()
	if role == "Survivor" then
		for _, p in Players:GetPlayers() do
			if p ~= player and p:GetAttribute("Role") == "Survivor" and p.Character then
				local s = p:GetAttribute("Status")
				if s == "Hooked" or (s == "Playing" and p:GetAttribute("Health") == 0) then
					wanted[p.Character] = Color3.fromRGB(255, 50, 50)
				end
			end
		end
		for _, gate in folderChildren("ExitGates") do
			if gate:GetAttribute("Powered") then
				wanted[gate] = Color3.fromRGB(255, 220, 90)
			end
		end
	elseif role == "Killer" and status == "Playing" then
		if player:GetAttribute("Carrying") then
			for _, hook in folderChildren("Hooks") do
				if hook:GetAttribute("Occupant") == 0 then
					wanted[hook] = Color3.fromRGB(255, 255, 255)
				end
			end
		end
		for _, gen in folderChildren("Generators") do
			if gen:GetAttribute("Done") then
				continue
			end
			if (gameState:GetAttribute("GensLeft") or 0) > 0 then
				wanted[gen] = Color3.fromRGB(230, 230, 230)
			end
		end
	end

	for inst, h in auras do
		if not wanted[inst] or not inst.Parent then
			h:Destroy()
			auras[inst] = nil
		end
	end
	for inst, color in wanted do
		local h = auras[inst]
		if not h then
			h = Instance.new("Highlight")
			h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			h.FillTransparency = 0.8
			h.Adornee = inst
			h.Parent = camera
			auras[inst] = h
		end
		h.OutlineColor = color
		h.FillColor = color
	end
end

------------------------------------------------------------------------
-- Звук сердцебиения
------------------------------------------------------------------------

local heartbeat
if Config.HeartbeatSoundId ~= "" then
	heartbeat = Instance.new("Sound")
	heartbeat.SoundId = Config.HeartbeatSoundId
	heartbeat.Looped = true
	heartbeat.Volume = 0
	heartbeat.Parent = SoundService
	heartbeat:Play()
end

local function getKiller()
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("Role") == "Killer" then
			return p
		end
	end
	return nil
end

------------------------------------------------------------------------
-- Наблюдение
------------------------------------------------------------------------

local function aliveParticipants()
	local list = {}
	for _, p in Players:GetPlayers() do
		local s = p:GetAttribute("Status")
		if p ~= player and p:GetAttribute("Role") and (s == "Playing" or s == "Hooked" or s == "Carried") then
			table.insert(list, p)
		end
	end
	return list
end

local function stopSpectating()
	spectating = false
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		camera.CameraSubject = hum
	end
	ui.SpectateButton.Text = "Наблюдать"
end

ui.SpectateButton.Activated:Connect(function()
	local list = aliveParticipants()
	if #list == 0 then
		stopSpectating()
		return
	end
	spectating = true
	spectateIndex = spectateIndex % #list + 1
	local target = list[spectateIndex]
	local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		camera.CameraSubject = hum
	end
	ui.SpectateButton.Text = "Следующий (" .. target.DisplayName .. ")"
end)

------------------------------------------------------------------------
-- Главный цикл
------------------------------------------------------------------------

local STATUS_TEXT = {
	Playing = { "Здоров", Color3.fromRGB(230, 230, 230) },
	Injured = { "Ранен", Color3.fromRGB(255, 170, 60) },
	Downed = { "Повержен", Color3.fromRGB(255, 80, 80) },
	Carried = { "В руках маньяка", Color3.fromRGB(255, 80, 80) },
	Hooked = { "На крюке", Color3.fromRGB(255, 50, 50) },
	Dead = { "Погиб", Color3.fromRGB(120, 120, 120) },
	Left = { "Вышел", Color3.fromRGB(120, 120, 120) },
	Escaped = { "Сбежал", Color3.fromRGB(110, 255, 140) },
}

local ACTION_TEXT = {
	Repair = "Ремонт генератора",
	Heal = "Лечение",
	Unhook = "Снятие с крюка",
	OpenGate = "Открытие ворот",
	Hook = "Вешаем на крюк",
	Break = "Ломаем паллету",
	Kick = "Повреждаем генератор",
}

local pulseTime = 0
local lastFirstPerson = false

RunService.RenderStepped:Connect(function(dt)
	local role = myRole()
	local status = myStatus()
	local phase = gameState:GetAttribute("Phase")
	local timer = gameState:GetAttribute("Timer") or 0
	local inMatch = role ~= nil and status ~= "Dead" and status ~= "Escaped" and status ~= "Left"

	bindControls(inMatch and role or nil)

	-- Верхняя строка
	if phase == "InGame" then
		local gens = gameState:GetAttribute("GensLeft") or 0
		local main = gens > 0 and ("Генераторов осталось: " .. gens) or "Ворота запитаны!"
		local subText
		if gameState:GetAttribute("EndGame") then
			subText = "Обрушение Сущности: " .. (gameState:GetAttribute("EndGameTimer") or 0) .. " с"
		elseif not role then
			subText = "Идёт раунд — подожди следующего"
		end
		ui.SetTop(main, subText)
	elseif phase == "Starting" then
		ui.SetTop("Раунд начнётся через " .. timer, "Маньяк будет выбран случайно")
	elseif phase == "Results" then
		ui.SetTop("Новый раунд через " .. timer)
	else
		local need = RunService:IsStudio() and Config.StudioMinPlayers or Config.MinPlayers
		ui.SetTop("Ожидание игроков (" .. #Players:GetPlayers() .. "/" .. need .. ")")
	end

	if role == "Killer" then
		ui.SetControls("ЛКМ — удар\nE — поднять / повесить / сломать\nПробел — перелезть через окно")
	elseif role == "Survivor" then
		ui.SetControls("Shift — бег\nE (держать) — чинить / лечить / снять с крюка\nПробел — паллета / прыжок через окно / проверка навыка")
	else
		ui.SetControls("Dead by Daylight в Roblox\nВыжившие чинят генераторы и сбегают,\nманьяк вешает их на крюки.")
	end

	-- Список выживших
	local rows = {}
	if phase == "InGame" then
		for _, p in Players:GetPlayers() do
			if p:GetAttribute("Role") == "Survivor" then
				local s = p:GetAttribute("Status") or "Playing"
				local key = s
				if s == "Playing" then
					local h = p:GetAttribute("Health") or 2
					key = h == 2 and "Playing" or (h == 1 and "Injured" or "Downed")
				end
				local info = STATUS_TEXT[key] or { s, Color3.new(1, 1, 1) }
				local text = p.DisplayName .. " — " .. info[1]
				if s == "Hooked" then
					text ..= " (" .. (p:GetAttribute("HookCount") or 1) .. "/2)"
				end
				table.insert(rows, { Text = text, Color = info[2] })
			end
		end
		local k = getKiller()
		if k then
			table.insert(rows, { Text = "Маньяк: " .. k.DisplayName, Color = Color3.fromRGB(255, 60, 60) })
		end
	end
	ui.SetSurvivors(rows)

	-- Действия
	if inMatch then
		currentPrimary, currentSecondary = findActions()
	else
		currentPrimary, currentSecondary = nil, nil
	end
	local actionName = player:GetAttribute("ActionName")
	if actionName then
		ui.SetHints(nil, nil)
		ui.SetAction(ACTION_TEXT[actionName] or actionName, player:GetAttribute("ActionProgress") or 0)
	else
		ui.SetAction(nil, nil)
		ui.SetHints(
			currentPrimary and ("[E] " .. currentPrimary.Text) or nil,
			currentSecondary and ("[Пробел] " .. currentSecondary.Text) or nil
		)
		local check = ui.GetSkillCheck()
		if check then
			check.Cancel()
		end
	end
	local check = ui.GetSkillCheck()
	if check then
		check.Update()
	end

	-- Личный статус
	if player:GetAttribute("HookProgress") then
		local stage = player:GetAttribute("HookCount") or 1
		ui.SetStatus("На крюке — стадия " .. stage .. ". Жди помощи!", 1 - player:GetAttribute("HookProgress"))
	elseif player:GetAttribute("Wiggle") then
		ui.SetStatus("Вырываешься из рук маньяка...", player:GetAttribute("Wiggle"))
	elseif player:GetAttribute("BleedOut") then
		ui.SetStatus("Ты повержен — истекаешь кровью", 1 - player:GetAttribute("BleedOut"))
	elseif player:GetAttribute("Stunned") then
		ui.SetStatus("Оглушён!", 1)
	else
		ui.SetStatus(nil, nil)
	end

	-- Радиус ужаса
	local intensity = 0
	local killer = getKiller()
	local myRoot = getRoot(player)
	if role == "Survivor" and inMatch and killer and myRoot then
		local kroot = getRoot(killer)
		if kroot then
			local d = flatDist(kroot.Position, myRoot.Position)
			intensity = math.clamp(1 - d / Config.TerrorRadius, 0, 1)
		end
	end
	if intensity > 0 then
		pulseTime += dt * (1 + intensity * 2.5)
		local beat = math.abs(math.sin(pulseTime * math.pi))
		ui.SetTerror(intensity * (0.4 + 0.6 * beat))
	else
		ui.SetTerror(0)
	end
	if heartbeat then
		heartbeat.Volume = intensity
		heartbeat.PlaybackSpeed = 0.9 + intensity * 0.6
	end

	-- Вид от первого лица для маньяка
	local firstPerson = Config.KillerFirstPerson and role == "Killer" and status == "Playing"
	if firstPerson ~= lastFirstPerson then
		lastFirstPerson = firstPerson
		if firstPerson then
			player.CameraMode = Enum.CameraMode.LockFirstPerson
		else
			player.CameraMode = Enum.CameraMode.Classic
			player.CameraMinZoomDistance = 0.5
		end
	end

	-- Наблюдение
	local canSpectate = phase == "InGame" and not inMatch
	ui.SpectateButton.Visible = canSpectate
	if spectating and not canSpectate then
		stopSpectating()
	end

	updateAuras()
end)

player.CharacterAdded:Connect(function()
	holding = false
	sprinting = false
	if spectating then
		task.defer(stopSpectating)
	end
end)
