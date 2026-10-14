-- Клиент: связывает интерфейс, управление, анимации, камеру, звук и эффекты.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local KillerDefs = require(ReplicatedStorage.Shared.KillerDefs)
local Util = require(ReplicatedStorage.Shared.Util)

local Hud = require(script.Parent.UI.Hud)
local SkillCheck = require(script.Parent.UI.SkillCheck)
local LobbyUI = require(script.Parent.UI.LobbyUI)
local Results = require(script.Parent.UI.Results)
local Widgets = require(script.Parent.UI.Widgets)
require(script.Parent.Animator)
local Audio = require(script.Parent.Audio)
local CameraController = require(script.Parent.CameraController)
local Effects = require(script.Parent.Effects)
local Auras = require(script.Parent.Auras)
local Atmosphere = require(script.Parent.Atmosphere)
local Interaction = require(script.Parent.Interaction)
local Input = require(script.Parent.Input)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local gameState = ReplicatedStorage:WaitForChild("GameState")

Hud.mount(player:WaitForChild("PlayerGui") :: PlayerGui)
LobbyUI.mount(Hud.Gui)
Results.mount(Hud.Gui)

------------------------------------------------------------------------
-- События сервера
------------------------------------------------------------------------

Remotes.Notify.OnClientEvent:Connect(function(text, color)
	Hud.notify(text, color)
end)

Remotes.Score.OnClientEvent:Connect(function(text, amount)
	Hud.score(text, amount)
end)

Remotes.SkillCheck.OnClientEvent:Connect(function(id, zone)
	Audio.play("SkillWarn")
	SkillCheck.start(zone, Config.SkillCheckDuration, function(result)
		Remotes.SkillCheck:FireServer(id, result)
		if result == "great" then
			Audio.play("SkillGood", nil, 1, 1.2)
			Hud.notify("Отлично!", Color3.new(1, 1, 1))
		elseif result == "good" then
			Audio.play("SkillGood")
		else
			Hud.notify("Провал!", Color3.fromRGB(255, 70, 70))
			CameraController.shake(0.5)
		end
	end)
end)

Remotes.Noise.OnClientEvent:Connect(function(position)
	Effects.noise(position)
end)

Remotes.Results.OnClientEvent:Connect(function(title, reason, rows)
	Results.show(title, reason, rows, Config.ResultsTime)
end)

local INTRO_QUOTES = {
	"Сущность голодна. Туман не выпустит никого.",
	"Здесь нет рассвета. Только ночь, крюки и крики.",
	"Кто-то уже смотрит на тебя из темноты.",
	"Не беги слишком громко. Он слышит.",
	"Генераторы — единственная надежда. Если успеешь.",
}

Remotes.Effect.OnClientEvent:Connect(function(name, value)
	if name == "Shake" then
		CameraController.shake(tonumber(value) or 0.5)
	elseif name == "Stun" then
		CameraController.stun(tonumber(value) or 2)
	elseif name == "Blind" then
		Hud.blind(tonumber(value) or 2)
		CameraController.shake(0.3)
	elseif name == "Intro" and typeof(value) == "table" then
		Audio.play("EntityDrone")
		Audio.play("TerrorStinger", nil, 0.7)
		local quote = INTRO_QUOTES[math.random(1, #INTRO_QUOTES)]
		if value.Role == "Killer" then
			Hud.intro("Ты — " .. tostring(value.KillerName), "Принеси их в жертву Сущности", quote)
		else
			Hud.intro("Выживи", "Маньяк: " .. tostring(value.KillerName), quote)
		end
	elseif name == "Scare" then
		Atmosphere.scare(tonumber(value) or 1)
	end
end)

------------------------------------------------------------------------
-- Наблюдение за раундом (после смерти / побега)
------------------------------------------------------------------------

local spectateButton = Widgets.button({
	Parent = Hud.Gui,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -24),
	Size = UDim2.fromOffset(240, 40),
	Text = "Наблюдать",
	Visible = false,
})
local spectateIndex = 0

spectateButton.Activated:Connect(function()
	local list = CameraController.spectateCandidates()
	if #list == 0 then
		CameraController.spectate(nil)
		return
	end
	spectateIndex = spectateIndex % #list + 1
	CameraController.spectate(list[spectateIndex])
end)

------------------------------------------------------------------------
-- Главный цикл
------------------------------------------------------------------------

local ACTION_TEXT = {
	Repair = "Ремонт генератора",
	Heal = "Лечение",
	SelfHeal = "Лечение аптечкой",
	Unhook = "Снятие с крюка",
	OpenGate = "Открытие ворот",
	Cleanse = "Очищение тотема",
	OpenChest = "Открытие сундука",
	EscapeTrap = "Попытка вырваться",
	FreeTrap = "Освобождение из капкана",
	DisarmTrap = "Обезвреживание капкана",
	Hook = "Вешаем на крюк",
	Break = "Ломаем паллету",
	Kick = "Повреждаем генератор",
	SearchLocker = "Обыскиваем шкафчик",
	CloseHatch = "Закрываем люк",
	PickupTrap = "Забираем капкан",
	ResetTrap = "Взводим капкан",
	SetTrap = "Ставим капкан",
}

local CONTROLS_SURVIVOR = "Shift — бег   •   Ctrl/C — присесть\n"
	.. "E (держать) — чинить, лечить, снять с крюка, сундук, тотем\n"
	.. "Пробел — паллета, окно, шкафчик, проверка навыка\n"
	.. "R — использовать предмет"
local CONTROLS_LOBBY = "Dead by Daylight в Roblox\nВыжившие чинят генераторы и сбегают,\nманьяк вешает их на крюки.\nСядь на бревно у костра и жди раунда."

local pulse = 0

RunService.RenderStepped:Connect(function(dt)
	local role = player:GetAttribute("Role")
	local status = player:GetAttribute("Status")
	local phase = gameState:GetAttribute("Phase")
	local timer = gameState:GetAttribute("Timer") or 0
	local inMatch = role ~= nil and Util.isInGameStatus(status)

	Input.bind(inMatch and role or nil)

	-- Верхние надписи
	if phase == "InGame" then
		local gens = gameState:GetAttribute("GensLeft") or 0
		local sub
		if gameState:GetAttribute("EndGame") then
			sub = "ОБРУШЕНИЕ: " .. (gameState:GetAttribute("EndGameTimer") or 0) .. " с"
		elseif gameState:GetAttribute("HexRuin") and role then
			sub = "Проклятие: Руина"
		end
		Hud.setGenerators(role ~= nil, gens > 0 and ("Генераторы: " .. gens) or "Ворота запитаны!", sub)
		Hud.setTop(not role and "Идёт раунд — подожди следующего" or nil, nil)
	else
		Hud.setGenerators(false)
		if phase == "Starting" then
			Hud.setTop("Раунд начнётся через " .. timer, "Маньяк выбирается среди желающих")
		elseif phase == "Loading" then
			Hud.setTop("Загрузка карты...")
		elseif phase == "Results" then
			Hud.setTop("Новый раунд через " .. timer)
		else
			local need = gameState:GetAttribute("NeedPlayers") or Config.MinPlayers
			Hud.setTop("Ожидание игроков (" .. #Players:GetPlayers() .. "/" .. need .. ")")
		end
	end

	LobbyUI.setVisible(role == nil and phase ~= "InGame" and phase ~= "Loading")
	Hud.updatePortraits(phase == "InGame")
	Hud.updatePower()

	if role == "Killer" then
		local def = KillerDefs.get(player:GetAttribute("KillerType"))
		Hud.setControls("ЛКМ — удар   •   " .. def.PowerHint .. "\nE — поднять, повесить, сломать, обыскать\nПробел — перелезть через окно")
	elseif role == "Survivor" then
		Hud.setControls(CONTROLS_SURVIVOR)
	else
		Hud.setControls(CONTROLS_LOBBY)
	end

	-- Действия и подсказки
	local primary, secondary = nil, nil
	if inMatch then
		primary, secondary = Interaction.find()
	end
	Input.Primary, Input.Secondary = primary, secondary
	local actionName = player:GetAttribute("ActionName")
	if actionName then
		Hud.setHints(nil, nil)
		Hud.setAction(ACTION_TEXT[actionName] or actionName, player:GetAttribute("ActionProgress") or 0)
	else
		Hud.setAction(nil, nil)
		Hud.setHints(
			primary and ("[E] " .. primary.Text) or nil,
			secondary and ("[Пробел] " .. secondary.Text) or nil
		)
		local check = SkillCheck.get()
		if check then
			check.Cancel()
		end
	end
	local check = SkillCheck.get()
	if check then
		check.Update()
	end

	-- Личный статус
	if player:GetAttribute("HookProgress") then
		local stage = player:GetAttribute("HookCount") or 1
		Hud.setStatus("На крюке — стадия " .. stage .. ". Жди помощи!", 1 - player:GetAttribute("HookProgress"))
	elseif player:GetAttribute("Wiggle") then
		Hud.setStatus("Вырываешься из рук маньяка...", player:GetAttribute("Wiggle"))
	elseif player:GetAttribute("BleedOut") then
		Hud.setStatus("Ты повержен — истекаешь кровью. Жди помощи!", 1 - player:GetAttribute("BleedOut"))
	elseif player:GetAttribute("Trapped") then
		Hud.setStatus("Ты в капкане! Держи E, чтобы вырваться", 1)
	elseif player:GetAttribute("Stunned") then
		Hud.setStatus("Оглушён!", 1)
	elseif player:GetAttribute("Hidden") then
		Hud.setStatus("Ты прячешься в шкафчике. Пробел — выйти", 1)
	else
		Hud.setStatus(nil, nil)
	end

	-- Пульсирующая красная виньетка радиуса ужаса
	local intensity = Audio.terrorIntensity()
	if intensity > 0 then
		pulse += dt * (1 + intensity * 2.5)
		Hud.setTerror(intensity * (0.35 + 0.65 * math.abs(math.sin(pulse * math.pi))))
	else
		Hud.setTerror(0)
	end

	-- Наблюдение
	local canSpectate = phase == "InGame" and not inMatch
	spectateButton.Visible = canSpectate
	local target = CameraController.getSpectateTarget()
	if target and not canSpectate then
		CameraController.spectate(nil)
		target = nil
	end
	spectateButton.Text = target and ("Следующий (" .. target.DisplayName .. ")") or "Наблюдать"

	Auras.update()
	Atmosphere.update(dt)
	Effects.update(dt)
	Audio.update(dt)
	CameraController.update(dt)
	Input.update(dt)
end)
