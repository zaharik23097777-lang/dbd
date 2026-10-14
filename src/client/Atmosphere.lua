-- Атмосфера ужаса (только на клиенте): освещение по ситуации (лобби у костра, ночь,
-- взгляд маньяка, обрушение Сущности, ранен/повержен/на крюке), молнии с громом,
-- мерцающие лампы (сильнее рядом с маньяком), свой тусклый свет вокруг персонажа,
-- внезапные «скримеры», когда маньяк неожиданно оказывается рядом, и пугающие звуки вдалеке.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Audio = require(script.Parent.Audio)
local CameraController = require(script.Parent.CameraController)
local Hud = require(script.Parent.UI.Hud)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local gameState = ReplicatedStorage:WaitForChild("GameState")

local Atmosphere = {}

local C = Color3.fromRGB
local BLACK = C(0, 0, 0)

-- Пресеты освещения: значения плавно перетекают друг в друга
local PRESETS = {
	Lobby = {
		Brightness = 0.9,
		Ambient = C(40, 27, 20),
		OutdoorAmbient = C(54, 38, 30),
		Density = 0.42,
		Haze = 2.4,
		AtmColor = C(70, 48, 40),
		Decay = C(24, 12, 10),
		Saturation = -0.25,
		Contrast = 0.22,
		Tint = C(255, 222, 196),
		Exposure = -0.02,
	},
	Night = {
		Brightness = 0.5,
		Ambient = C(15, 17, 24),
		OutdoorAmbient = C(36, 40, 55),
		Density = 0.6,
		Haze = 2.8,
		AtmColor = C(66, 74, 92),
		Decay = C(12, 14, 22),
		Saturation = -0.45,
		Contrast = 0.26,
		Tint = C(190, 208, 235),
		Exposure = -0.04,
	},
	Killer = {
		Brightness = 0.7,
		Ambient = C(34, 16, 16),
		OutdoorAmbient = C(66, 42, 42),
		Density = 0.46,
		Haze = 2.2,
		AtmColor = C(92, 60, 60),
		Decay = C(34, 10, 10),
		Saturation = -0.3,
		Contrast = 0.2,
		Tint = C(255, 205, 200),
		Exposure = 0,
	},
	Endgame = {
		Brightness = 0.6,
		Ambient = C(40, 9, 8),
		OutdoorAmbient = C(78, 22, 20),
		Density = 0.56,
		Haze = 3,
		AtmColor = C(125, 32, 26),
		Decay = C(64, 6, 5),
		Saturation = -0.2,
		Contrast = 0.36,
		Tint = C(255, 170, 160),
		Exposure = -0.02,
	},
}

local cur = table.clone(PRESETS.Lobby)
cur.Blur = 0

local function lerpValue(a: any, b: any, t: number): any
	if typeof(a) == "Color3" then
		return (a :: Color3):Lerp(b, t)
	end
	return a + (b - a) * t
end

local function scaleColor(c: Color3, k: number): Color3
	return Color3.new(math.min(c.R * k, 1), math.min(c.G * k, 1), math.min(c.B * k, 1))
end

------------------------------------------------------------------------
-- Локальные эффекты постобработки
------------------------------------------------------------------------

local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "DBDGrade"
grade.Parent = Lighting
local blur = Instance.new("BlurEffect")
blur.Name = "DBDBlur"
blur.Size = 0
blur.Parent = Lighting

-- Серверная цветокоррекция заменяется своей (иначе эффекты складываются)
local function disableServerGrade()
	for _, child in Lighting:GetChildren() do
		if child:IsA("ColorCorrectionEffect") and child ~= grade then
			child.Enabled = false
		end
	end
end
disableServerGrade()
Lighting.ChildAdded:Connect(function()
	task.defer(disableServerGrade)
end)

------------------------------------------------------------------------
-- Мерцающие лампы
------------------------------------------------------------------------

type Flicker = { Light: Light, Base: number, Part: BasePart?, BaseColor: Color3?, Off: boolean, Timer: number, Burst: number }

local flickers = {} :: { Flicker }
local scannedMap: Instance? = nil

local function scanLights(map: Instance?)
	scannedMap = map
	table.clear(flickers)
	if not map then
		return
	end
	for _, d in map:GetDescendants() do
		if d:IsA("Light") and d:GetAttribute("Flicker") then
			local part = d.Parent
			local isPart = part and part:IsA("BasePart")
			table.insert(flickers, {
				Light = d :: Light,
				Base = (d :: Light).Brightness or 1,
				Part = if isPart then part :: BasePart else nil,
				BaseColor = if isPart then (part :: BasePart).Color else nil,
				Off = false,
				Timer = math.random() * 6,
				Burst = 0,
			})
		end
	end
end

local function updateFlicker(dt: number, killerPos: Vector3?)
	local camPos = camera.CFrame.Position
	for _, f in flickers do
		local light = f.Light
		if not light.Parent then
			continue
		end
		local part = f.Part
		local pos = part and part.Position or camPos
		if (pos - camPos).Magnitude > 140 then
			continue
		end
		-- Рядом с маньяком Сущность «дышит» на свет — лампы мигают чаще
		local nearKiller = killerPos ~= nil and (pos - killerPos).Magnitude < 30
		f.Timer -= dt
		if f.Timer <= 0 then
			if f.Burst > 0 then
				f.Burst -= 1
				f.Off = not f.Off
				f.Timer = 0.03 + math.random() * 0.12
			else
				f.Off = false
				f.Timer = (nearKiller and 0.6 or 3) + math.random() * (nearKiller and 2 or 10)
				f.Burst = math.random(1, nearKiller and 6 or 3) * 2
			end
			if part and f.BaseColor then
				part.Color = f.Off and (f.BaseColor :: Color3):Lerp(BLACK, 0.8) or f.BaseColor :: Color3
			end
		end
		light.Brightness = f.Off and f.Base * 0.06 or f.Base * (0.85 + math.random() * 0.15)
	end
end

------------------------------------------------------------------------
-- Свой тусклый свет (чтобы в темноте было видно хоть что-то рядом)
------------------------------------------------------------------------

local ownLight: PointLight? = nil

local function updateOwnLight(want: string?)
	local root = Util.getRoot(player)
	if ownLight and (not want or not root or ownLight.Parent ~= root) then
		ownLight:Destroy()
		ownLight = nil
	end
	if not want or not root then
		return
	end
	if not ownLight then
		local l = Instance.new("PointLight")
		l.Name = "DBDOwnLight"
		l.Shadows = false
		l.Parent = root
		ownLight = l
	end
	local l = ownLight :: PointLight
	if want == "Killer" then
		l.Color = C(255, 110, 100)
		l.Range = 24
		l.Brightness = 0.45
	else
		l.Color = C(170, 182, 215)
		l.Range = 15
		l.Brightness = 0.35
	end
end

------------------------------------------------------------------------
-- Состояние
------------------------------------------------------------------------

local lightningTimer = 30
local lightningAt = -100
local scareTimer = 15
local lastFar = 0
local lastScare = -100
local lastTerrorStinger = -100
local prevIntensity = 0
local prevStatus: string? = nil
local prevHealth: number? = nil
local prevPowerState: string? = nil

local function range(r: { number }?, default: number): number
	if not r then
		return default
	end
	return r[1] + math.random() * (r[2] - r[1])
end

local function findKiller(): Player?
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("Role") == "Killer" then
			return p
		end
	end
	return nil
end

function Atmosphere.scare(strength: number?)
	local s = strength or 1
	lastScare = os.clock()
	Audio.play("Stinger", nil, s)
	Audio.play("StingerScreech", nil, s)
	CameraController.shake(0.9 * s)
	CameraController.punch(-12 * s)
	Hud.flash(C(120, 0, 0), 0.55 * s)
end

-- Пугающий звук где-то в темноте вокруг
local SCARES = { "Whisper", "Whisper", "Creak", "Creak", "Creak", "DistantScream", "MetalScrape" }

local function ambientScare(center: Vector3)
	local name = SCARES[math.random(1, #SCARES)]
	local a = math.random() * math.pi * 2
	local r = 25 + math.random() * 35
	Audio.play(name, center + Vector3.new(math.cos(a) * r, 3, math.sin(a) * r), 0.7 + math.random() * 0.4, 0.85 + math.random() * 0.3)
end

local function onStatusChanged(status: string?, old: string?)
	if not old or not Util.isInGameStatus(old) then
		return
	end
	if status == "Hooked" then
		Hud.flash(C(160, 0, 0), 0.6)
		Audio.play("EntityWhisper", nil, 0.6)
	elseif status == "Carried" then
		Hud.flash(C(90, 0, 0), 0.4)
	elseif status == "Dead" then
		Audio.play("Stinger")
		Audio.play("EntityWhisper")
		Hud.fate("ТЫ ПРИНЕСЁН В ЖЕРТВУ", "Сущность забрала тебя...", C(200, 20, 20))
	elseif status == "Escaped" then
		Hud.fate("ТЫ СБЕЖАЛ", "Но ночь ещё не закончилась", C(200, 200, 190))
	end
end

function Atmosphere.update(dt: number)
	local now = os.clock()
	local role = player:GetAttribute("Role")
	local status = player:GetAttribute("Status")
	local health = player:GetAttribute("Health")
	local phase = gameState:GetAttribute("Phase")
	local inMatch = role ~= nil and Util.isInGameStatus(status)
	local spectating = CameraController.getSpectateTarget() ~= nil
	local onMap = phase == "InGame" and (inMatch or spectating)

	if status ~= prevStatus then
		onStatusChanged(status, prevStatus)
		prevStatus = status
	end
	if inMatch and role == "Survivor" and prevHealth and health and health < prevHealth then
		Hud.flash(C(140, 0, 0), health == 0 and 0.6 or 0.4)
	end
	prevHealth = health

	-- Выбор пресета
	local mode = "Lobby"
	if onMap then
		if gameState:GetAttribute("EndGame") then
			mode = "Endgame"
		elseif role == "Killer" and inMatch then
			mode = "Killer"
		else
			mode = "Night"
		end
	end
	local target = table.clone(PRESETS[mode])
	target.Blur = 0
	if mode ~= "Lobby" then
		local k = math.clamp(2 - (Config.Darkness or 1), 0.4, 2)
		target.Ambient = scaleColor(target.Ambient, k)
		target.OutdoorAmbient = scaleColor(target.OutdoorAmbient, k)
		target.Brightness *= k
	end

	-- Модификаторы состояния выжившего
	local intensity = Audio.terrorIntensity()
	local darkness = mode == "Lobby" and 0.35 or 0.55
	local blood, bloodPulse = 0, false
	if inMatch and role == "Survivor" then
		target.Saturation -= 0.3 * intensity
		target.Contrast += 0.15 * intensity
		target.Tint = target.Tint:Lerp(C(255, 185, 185), 0.3 * intensity)
		darkness += 0.25 * intensity
		if status == "Hooked" then
			target.Tint = target.Tint:Lerp(C(255, 110, 100), 0.5)
			target.Saturation = math.min(target.Saturation, -0.7)
			target.Blur = 2
			blood, bloodPulse = 0.5, true
		elseif status == "Carried" then
			target.Blur = 3
			blood = 0.35
		elseif health == 0 then
			target.Saturation = math.min(target.Saturation, -0.85)
			target.Exposure -= 0.1
			target.Blur = 5
			darkness += 0.2
			blood, bloodPulse = 0.6, true
		elseif health == 1 then
			target.Tint = target.Tint:Lerp(C(255, 150, 150), 0.12)
			blood, bloodPulse = 0.22, true
		end
		if intensity > 0.4 then
			CameraController.shake(0.07 * intensity * intensity)
		end
	elseif onMap and not inMatch then
		-- Мёртвые наблюдают за раундом в серых тонах
		target.Saturation = status == "Dead" and -1 or target.Saturation
	end

	-- Молния
	local lightning = 0
	if onMap and Config.LightningInterval then
		lightningTimer -= dt
		if lightningTimer <= 0 then
			lightningTimer = range(Config.LightningInterval, 60)
			lightningAt = now
			local delayTime = 0.6 + math.random() * 1.6
			task.delay(delayTime, function()
				Audio.play("Thunder", nil, 0.6 + math.random() * 0.4, 0.9 + math.random() * 0.2)
			end)
		end
		local lt = now - lightningAt
		if lt < 1 then
			lightning = math.exp(-lt * 9) + (lt > 0.18 and 0.7 * math.exp(-(lt - 0.18) * 7) or 0)
		end
	end
	if lightning > 0.01 then
		target.Brightness += lightning * 2.5
		target.OutdoorAmbient = target.OutdoorAmbient:Lerp(C(175, 185, 225), math.min(lightning * 0.7, 1))
		target.Exposure += lightning * 0.35
	end

	-- Плавный переход (молния — мгновенно)
	local alpha = lightning > 0.01 and 1 or 1 - math.exp(-dt * 1.4)
	for key, value in target do
		cur[key] = lerpValue(cur[key] ~= nil and cur[key] or value, value, alpha)
	end
	Lighting.ClockTime = 0
	Lighting.Brightness = cur.Brightness
	Lighting.Ambient = cur.Ambient
	Lighting.OutdoorAmbient = cur.OutdoorAmbient
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if atm then
		atm.Density = cur.Density
		atm.Haze = cur.Haze
		atm.Color = cur.AtmColor
		atm.Decay = cur.Decay
	end
	grade.Saturation = cur.Saturation
	grade.Contrast = cur.Contrast
	grade.TintColor = cur.Tint
	grade.Brightness = cur.Exposure
	blur.Size = cur.Blur

	Hud.setDarkness(darkness)
	Hud.setBlood(blood, bloodPulse)

	-- Лампы и свой свет
	local map = workspace:FindFirstChild("Map")
	if map ~= scannedMap then
		scanLights(map)
	end
	local killer = findKiller()
	local kroot = Util.getRoot(killer)
	updateFlicker(dt, kroot and kroot.Position or nil)
	updateOwnLight(inMatch and status == "Playing" and (role == "Killer" and "Killer" or "Survivor") or nil)

	-- Скримеры и вход в радиус ужаса
	local myRoot = Util.getRoot(player)
	if inMatch and role == "Survivor" and status == "Playing" and kroot and myRoot and killer then
		local d = Util.flatDist(kroot.Position, myRoot.Position)
		local powerState = killer:GetAttribute("PowerState")
		if d > 26 then
			lastFar = now
		end
		if Config.JumpScares and now - lastScare > 25 then
			local sudden = d < 10 and now - lastFar < 3.5
			local uncloaked = prevPowerState == "Uncloaking" and powerState == "Visible" and d < 16
			if sudden or uncloaked then
				Atmosphere.scare(1)
			end
		end
		prevPowerState = powerState
		if prevIntensity <= 0 and intensity > 0 and now - lastTerrorStinger > 30 then
			lastTerrorStinger = now
			Audio.play("TerrorStinger")
		end
	end
	prevIntensity = intensity

	-- Звуки в темноте
	if onMap then
		scareTimer -= dt
		if scareTimer <= 0 then
			scareTimer = range(Config.AmbientScareInterval, 20)
			ambientScare(myRoot and inMatch and myRoot.Position or camera.CFrame.Position)
		end
	end
end

return Atmosphere
