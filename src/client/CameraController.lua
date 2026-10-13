-- Камера: маньяк от первого лица с покачиванием, выживший от третьего,
-- ползание ниже, вид из шкафчика, тряска и наклон при оглушении.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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

local function setMode(newMode: string)
	if mode == newMode then
		return
	end
	mode = newMode
	if newMode == "Killer" then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		player.CameraMaxZoomDistance = 0.5
		player.CameraMinZoomDistance = 0.5
	elseif newMode == "Survivor" then
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMaxZoomDistance = 16
		player.CameraMinZoomDistance = 7
	else
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMaxZoomDistance = 30
		player.CameraMinZoomDistance = 0.5
	end
end

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
	if locker then
		local inside = locker:FindFirstChild("Inside") :: BasePart?
		if inside then
			if not lockerMode then
				lockerMode = true
				camera.CameraType = Enum.CameraType.Scriptable
			end
			local look = inside.CFrame * CFrame.new(0, 1.8, -0.4)
			local sway = CFrame.Angles(math.sin(os.clock() * 0.7) * 0.02, math.sin(os.clock() * 0.5) * 0.08, 0)
			camera.CFrame = camera.CFrame:Lerp(look * sway, math.min(dt * 6, 1))
		end
	elseif lockerMode then
		lockerMode = false
		camera.CameraType = Enum.CameraType.Custom
	end
end

-- После стандартной камеры: тряска и наклон
RunService:BindToRenderStep("DBDCameraFX", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local t = os.clock()
	local extra = CFrame.identity
	if shake > 0.01 then
		extra *= CFrame.Angles(
			(math.noise(t * 25, 0) * shake) * 0.08,
			(math.noise(0, t * 25) * shake) * 0.08,
			0
		)
		shake *= math.exp(-dt * 5)
	end
	if t < stunUntil then
		local a = (t - stunStart) / (stunUntil - stunStart)
		extra *= CFrame.Angles(math.rad(-12) * (1 - a), 0, math.rad(18) * math.sin(a * math.pi))
	end
	if extra ~= CFrame.identity then
		camera.CFrame *= extra
	end
end)

return CameraController
