-- Управление (клавиатура, геймпад, сенсорные кнопки на телефоне).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SkillCheck = require(script.Parent.UI.SkillCheck)
local CameraController = require(script.Parent.CameraController)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local Input = {}

Input.Primary = nil :: any
Input.Secondary = nil :: any

local holding = false
local sprinting = false
local crouching = false
local itemHeld = false
local boundRole: string? = nil

local Sink = Enum.ContextActionResult.Sink
local Pass = Enum.ContextActionResult.Pass
local Begin = Enum.UserInputState.Begin

local function isEnd(state: Enum.UserInputState): boolean
	return state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel
end

local function onInteract(_, state)
	if state == Begin then
		if Input.Primary then
			holding = true
			Remotes.BeginAction:FireServer(Input.Primary.Kind, Input.Primary.Target)
		end
	elseif isEnd(state) and holding then
		holding = false
		Remotes.EndAction:FireServer()
	end
	return Sink
end

local function onSecondary(_, state)
	if state ~= Begin then
		return Sink
	end
	local check = SkillCheck.get()
	if check then
		check.Press()
	elseif Input.Secondary then
		Remotes.BeginAction:FireServer(Input.Secondary.Kind, Input.Secondary.Target)
	end
	return Sink
end

local function onSprint(_, state, input)
	if input.UserInputType == Enum.UserInputType.Touch then
		if state == Begin then
			sprinting = not sprinting
			Remotes.Sprint:FireServer(sprinting)
		end
	elseif state == Begin then
		sprinting = true
		Remotes.Sprint:FireServer(true)
	elseif isEnd(state) then
		sprinting = false
		Remotes.Sprint:FireServer(false)
	end
	-- Sink: иначе Shift заодно включает Shift Lock и камера «залипает»
	return Sink
end

local function onCrouch(_, state, input)
	if input.UserInputType == Enum.UserInputType.Touch then
		if state == Begin then
			crouching = not crouching
			Remotes.Crouch:FireServer(crouching)
		end
	elseif state == Begin then
		crouching = true
		Remotes.Crouch:FireServer(true)
	elseif isEnd(state) then
		crouching = false
		Remotes.Crouch:FireServer(false)
	end
	return Sink
end

local function onItem(_, state)
	if state == Begin then
		itemHeld = true
		Remotes.UseItem:FireServer(true, camera.CFrame.LookVector)
	elseif isEnd(state) then
		itemHeld = false
		Remotes.UseItem:FireServer(false, camera.CFrame.LookVector)
	end
	return Sink
end

local function onAttack(_, state)
	if state == Begin then
		Remotes.Attack:FireServer()
		if player:GetAttribute("Status") == "Playing" and not player:GetAttribute("Carrying") then
			CameraController.punch(-6)
		end
	end
	return Pass
end

local function onPower(_, state)
	if state == Begin then
		Remotes.UsePower:FireServer(true, camera.CFrame.LookVector)
	elseif isEnd(state) then
		Remotes.UsePower:FireServer(false, camera.CFrame.LookVector)
	end
	return Sink
end

local ACTIONS = { "DBDInteract", "DBDSecondary", "DBDSprint", "DBDCrouch", "DBDItem", "DBDAttack", "DBDPower" }

function Input.bind(role: string?)
	if boundRole == role then
		return
	end
	boundRole = role
	for _, name in ACTIONS do
		ContextActionService:UnbindAction(name)
	end
	if holding then
		holding = false
	end
	sprinting, crouching, itemHeld = false, false, false
	if not role then
		return
	end
	ContextActionService:BindActionAtPriority("DBDInteract", onInteract, true, 3000, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
	ContextActionService:SetTitle("DBDInteract", "E")
	ContextActionService:SetPosition("DBDInteract", UDim2.new(1, -170, 1, -150))
	ContextActionService:BindActionAtPriority("DBDSecondary", onSecondary, true, 3000, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
	ContextActionService:SetTitle("DBDSecondary", "Прыг")
	ContextActionService:SetPosition("DBDSecondary", UDim2.new(1, -95, 1, -95))
	if role == "Survivor" then
		ContextActionService:BindActionAtPriority(
			"DBDSprint",
			onSprint,
			true,
			3000,
			Enum.KeyCode.LeftShift,
			Enum.KeyCode.RightShift,
			Enum.KeyCode.ButtonL3
		)
		ContextActionService:SetTitle("DBDSprint", "Бег")
		ContextActionService:SetPosition("DBDSprint", UDim2.new(1, -170, 1, -80))
		ContextActionService:BindActionAtPriority("DBDCrouch", onCrouch, true, 3000, Enum.KeyCode.LeftControl, Enum.KeyCode.C, Enum.KeyCode.ButtonB)
		ContextActionService:SetTitle("DBDCrouch", "Присесть")
		ContextActionService:SetPosition("DBDCrouch", UDim2.new(1, -245, 1, -80))
		ContextActionService:BindActionAtPriority("DBDItem", onItem, true, 3000, Enum.KeyCode.R, Enum.KeyCode.ButtonL2)
		ContextActionService:SetTitle("DBDItem", "Предмет")
		ContextActionService:SetPosition("DBDItem", UDim2.new(1, -245, 1, -150))
	else
		ContextActionService:BindAction("DBDAttack", onAttack, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
		ContextActionService:SetTitle("DBDAttack", "Удар")
		ContextActionService:SetPosition("DBDAttack", UDim2.new(1, -245, 1, -110))
		ContextActionService:BindActionAtPriority(
			"DBDPower",
			onPower,
			true,
			3000,
			Enum.UserInputType.MouseButton2,
			Enum.KeyCode.Q,
			Enum.KeyCode.ButtonL2
		)
		ContextActionService:SetTitle("DBDPower", "Сила")
		ContextActionService:SetPosition("DBDPower", UDim2.new(1, -245, 1, -180))
	end
end

-- Пока светим фонариком, отправляем направление камеры
local aimTimer = 0
function Input.update(dt: number)
	if itemHeld and player:GetAttribute("Item") == "Flashlight" then
		aimTimer -= dt
		if aimTimer <= 0 then
			aimTimer = 0.1
			Remotes.UseItem:FireServer(true, camera.CFrame.LookVector)
		end
	end
end

return Input
