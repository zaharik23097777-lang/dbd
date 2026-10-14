-- Камера: маньяк от первого лица с покачиванием, выживший от третьего,
-- ползание ниже, вид из шкафчика, наблюдение, тряска и наклон при оглушении.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local CameraController = {}

local shake = 0
local stunUntil = 0
local stunStart = 0
local fovPunch = 0
local mode = ""
local bob = 0
local lockerMode = false
local lockerDoor: Model? = nil
local lockerDoorParts: { BasePart } = {}
local spectateTarget: Player? = nil
local appliedFX = CFrame.identity

-- Детали снаряжения маньяков, которые видны от первого лица (имена — из Art/KillerGear)
local VIEWMODEL = {
	-- оружие: тесак Траппера, топор Охотницы, дубина и колокол Призрака
	Handle = true,
	Blade = true,
	BladeBlood = true,
	AxeHead = true,
	Club = true,
	Skull = true,
	Bell = true,
	-- снаряжение кистей и предплечий
	Glove = true,
	Wrap = true,
	Bracer = true,
	ArmWrap = true,
	ArmRag = true,
}

function CameraController.shake(amount: number)
	shake = math.max(shake, amount)
end

function CameraController.stun(duration: number)
	stunStart = os.clock()
	stunUntil = stunStart + duration
	shake = math.max(shake, 0.4)
end

function CameraController.punch(amount: number)
	fovPunch = amount
end

------------------------------------------------------------------------
-- Режимы
------------------------------------------------------------------------

local function setMode(newMode: string)
	if mode == newMode then
		return
	end
	local wasKiller = mode == "Killer"
	mode = newMode
	if newMode == "Killer" then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		player.CameraMaxZoomDistance = 0.5
		player.CameraMinZoomDistance = 0.5
		return
	end
	player.CameraMode = Enum.CameraMode.Classic
	-- Сначала максимум, потом минимум: минимум больше 0.5 «выталкивает» камеру
	-- из вида от первого лица, иначе после раунда за маньяка мышь остаётся
	-- заблокированной по центру и по меню нельзя кликнуть.
	if newMode == "Survivor" then
		player.CameraMaxZoomDistance = 16
		player.CameraMinZoomDistance = 7
	else
		player.CameraMaxZoomDistance = 30
		player.CameraMinZoomDistance = 6
	end
	if wasKiller then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end
end

------------------------------------------------------------------------
-- Наблюдение
------------------------------------------------------------------------

local function isSpectatable(p: Player): boolean
	return p ~= player
		and p.Parent ~= nil
		and p:GetAttribute("Role") ~= nil
		and Util.isInGameStatus(p:GetAttribute("Status") :: string?)
		and Util.getHumanoid(p) ~= nil
end

function CameraController.spectateCandidates(): { Player }
	local list = {}
	for _, p in Players:GetPlayers() do
		if isSpectatable(p) then
			table.insert(list, p)
		end
	end
	return list
end

-- nil — вернуться к своему персонажу
function CameraController.spectate(target: Player?)
	spectateTarget = target
end

function CameraController.getSpectateTarget(): Player?
	return spectateTarget
end

------------------------------------------------------------------------
-- Шкафчик
------------------------------------------------------------------------

local function findLocker(): Model?
	local map = workspace:FindFirstChild("Map")
	local lockers = map and map:FindFirstChild("Lockers")
	if not lockers then
		return nil
	end
	for _, l in lockers:GetChildren() do
		if l:GetAttribute("Occupant") == player.UserId then
			return l :: Model
		end
	end
	return nil
end

-- Все детали двери шкафчика (группа LockerDoor), сквозь которые смотрит спрятавшийся
local function setLockerDoor(locker: Model?)
	if lockerDoor == locker then
		return
	end
	if lockerDoor then
		for _, part in lockerDoorParts do
			if part.Parent then
				part.LocalTransparencyModifier = 0
			end
		end
	end
	lockerDoor = locker
	lockerDoorParts = {}
	if locker then
		-- Изнутри видно сквозь щели
		for _, d in locker:GetDescendants() do
			if d:IsA("BasePart") and (d:GetAttribute("FX") == "LockerDoor" or d.Name == "Door") then
				d.LocalTransparencyModifier = 0.7
				table.insert(lockerDoorParts, d)
			end
		end
	end
end

------------------------------------------------------------------------
-- Каждый кадр
------------------------------------------------------------------------

function CameraController.update(dt: number)
	local role = player:GetAttribute("Role")
	local status = player:GetAttribute("Status")
	local inGame = Util.isInGameStatus(status)
	local hum = Util.getHumanoid(player)

	if role == "Killer" and status == "Playing" and Config.KillerFirstPerson then
		setMode("Killer")
	elseif role == "Survivor" and inGame then
		setMode("Survivor")
	else
		setMode("Lobby")
	end

	-- Смещение камеры: ползание, приседание, покачивание головы маньяка
	if hum then
		local target = Vector3.zero
		local root = Util.getRoot(player)
		local speed = root and (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude or 0
		if role == "Survivor" and status == "Playing" then
			if (player:GetAttribute("Health") or 2) == 0 then
				target = Vector3.new(0, -2.2, 0)
			elseif player:GetAttribute("Crouching") or player:GetAttribute("ActionName") then
				target = Vector3.new(0, -1, 0)
			end
		elseif mode == "Killer" then
			bob += dt * speed * 0.6
			local amp = math.clamp(speed / 18, 0, 1)
			target = Vector3.new(math.cos(bob) * 0.08 * amp, math.abs(math.sin(bob)) * 0.15 * amp, 0)
		end
		hum.CameraOffset = hum.CameraOffset:Lerp(target, math.min(dt * 8, 1))
	end

	local wantFov = mode == "Killer" and 85 or 70
	camera.FieldOfView += (wantFov + fovPunch - camera.FieldOfView) * math.min(dt * 10, 1)
	fovPunch *= math.exp(-dt * 6)

	-- Шкафчик: камера внутри, смотрит наружу через щели
	local locker = player:GetAttribute("Hidden") and findLocker()
	local inside = locker and locker:FindFirstChild("Inside") :: BasePart?
	if locker and inside then
		if not lockerMode then
			lockerMode = true
			camera.CameraType = Enum.CameraType.Scriptable
		end
		setLockerDoor(locker)
		local look = inside.CFrame * CFrame.new(0, 1.8, -0.4)
		local sway = CFrame.Angles(math.sin(os.clock() * 0.7) * 0.02, math.sin(os.clock() * 0.5) * 0.08, 0)
		camera.CFrame = camera.CFrame:Lerp(look * sway, math.min(dt * 6, 1))
		return
	end
	if lockerMode then
		lockerMode = false
		setLockerDoor(nil)
	end

	-- Камера всегда должна быть обычной и смотреть на живого персонажа.
	-- Персонажи создаются вручную, поэтому привязываем её сами.
	if camera.CameraType ~= Enum.CameraType.Custom then
		camera.CameraType = Enum.CameraType.Custom
	end
	local subject: Humanoid? = hum
	if spectateTarget then
		if isSpectatable(spectateTarget) then
			subject = Util.getHumanoid(spectateTarget)
		else
			-- Тот, за кем смотрели, сбежал или погиб — переключаемся на следующего
			local list = CameraController.spectateCandidates()
			spectateTarget = list[1]
			subject = spectateTarget and Util.getHumanoid(spectateTarget) or hum
		end
	end
	if subject and camera.CameraSubject ~= subject then
		camera.CameraSubject = subject
	end
end

------------------------------------------------------------------------
-- Тряска и наклон
-- Стандартная камера Roblox берёт направление взгляда из прошлого кадра, поэтому
-- эффект нужно убирать перед её обновлением и добавлять заново после — иначе
-- наклон накапливается и камера «уезжает» в землю.
------------------------------------------------------------------------

RunService:BindToRenderStep("DBDCameraFXRemove", Enum.RenderPriority.Camera.Value - 1, function()
	if appliedFX ~= CFrame.identity then
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CFrame *= appliedFX:Inverse()
		end
		appliedFX = CFrame.identity
	end
end)

RunService:BindToRenderStep("DBDCameraFXApply", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local t = os.clock()
	local extra = CFrame.identity
	if shake > 0.01 then
		extra *= CFrame.Angles(math.noise(t * 25, 0) * shake * 0.08, math.noise(0, t * 25) * shake * 0.08, 0)
		shake *= math.exp(-dt * 5)
	else
		shake = 0
	end
	if t < stunUntil then
		local a = (t - stunStart) / (stunUntil - stunStart)
		extra *= CFrame.Angles(math.rad(-12) * (1 - a), 0, math.rad(18) * math.sin(a * math.pi))
	end
	if extra ~= CFrame.identity and camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CFrame *= extra
		appliedFX = extra
	end

	-- От первого лица Roblox прячет всё тело. Маньяку оставляем руки и оружие,
	-- чтобы был виден замах, как в DBD.
	if mode == "Killer" then
		local char = player.Character
		if char then
			for _, d in char:GetChildren() do
				if d:IsA("BasePart") and (VIEWMODEL[d.Name] or d.Name == "Left Arm" or d.Name == "Right Arm") then
					d.LocalTransparencyModifier = 0
				end
			end
		end
	end
end)

------------------------------------------------------------------------
-- Персонаж: никаких падений и лазания по стенам (сталкивается только HumanoidRootPart)
------------------------------------------------------------------------

local function onCharacter(char: Model)
	local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
	if not hum then
		return
	end
	for _, state in
		{ Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.Climbing }
	do
		hum:SetStateEnabled(state, false)
	end
	camera.CameraType = Enum.CameraType.Custom
	if not spectateTarget then
		camera.CameraSubject = hum
	end
end

player.CharacterAdded:Connect(onCharacter)
if player.Character then
	task.spawn(onCharacter, player.Character)
end

return CameraController
