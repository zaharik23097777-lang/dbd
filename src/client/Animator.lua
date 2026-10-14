-- Процедурные анимации R6 для всех персонажей.
-- Motor6D.Transform не реплицируется, поэтому каждый клиент анимирует всех сам,
-- по реплицированным атрибутам (состояние, действие, одноразовые анимации AnimSeq).
-- Поза (Anim/Poses) -> пружины суставов (Anim/Driver) -> Motor6D.Transform.
-- Здесь же считаются параметры движения для походки: ускорение, поворот, усталость, дыхание.
-- LOD: дальние персонажи обновляются реже, далеко за кадром — не обновляются вовсе
-- (пружины решаются точно при любом шаге, так что редкие обновления не ломают позу).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")

local Anim = ReplicatedStorage.Shared.Anim
local Rig = require(Anim.Rig)
local Poses = require(Anim.Poses)
local Clip = require(Anim.Clip)
local Driver = require(Anim.Driver)
local Util = require(ReplicatedStorage.Shared.Util)
local Audio = require(script.Parent.Audio)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local Animator = {}

local TAU = math.pi * 2
local exp, clamp = math.exp, math.clamp
local FLAT = Vector3.new(1, 0, 1)

-- Уровни детализации: до Full стадов — каждый кадр, дальше — с интервалом.
-- На телефонах (сенсор без клавиатуры) дистанции короче.
local MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local LOD_K = MOBILE and 0.6 or 1
local LOD = {
	MaxDistance = 260 * LOD_K, -- дальше не анимируем
	Full = 35 * LOD_K,
	Steps = { { 75 * LOD_K, 1 / 30 }, { 150 * LOD_K, 1 / 15 }, { math.huge, 1 / 8 } },
	OffscreenNear = 18, -- за кадром ближе этого — раз в 0.1 с (тени, край экрана)
	OffscreenInterval = 0.1,
	SnapAfter = 0.5, -- после такого перерыва поза ставится сразу, без пружин
}

type Shot = { Name: string, Def: any, Start: number }

type Entry = {
	Char: Model,
	Driver: Driver.Driver?,
	Phase: number,
	Breath: number,
	Step: number,
	Seq: number,
	Shot: Shot?,
	LocalShot: { Name: string, At: number }?,
	Vel: Vector3?,
	Yaw: number?,
	Fwd: Vector3,
	AccelF: number,
	AccelS: number,
	TurnRate: number,
	Exertion: number,
	Seed: number,
	Pending: number,
	Pose: { [string]: any },
	Concealed: boolean?,
}

-- Спрятавшийся в шкафчике шире шкафчика: другим игрокам его не видно (как в DBD)
local function conceal(entry: Entry, on: boolean)
	if (entry.Concealed or false) == on then
		return
	end
	entry.Concealed = on
	for _, d in entry.Char:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			(d :: any).LocalTransparencyModifier = on and 1 or 0
		end
	end
end

local entries = {} :: { [Model]: Entry }

local function register(char: Instance)
	if not char:IsA("Model") or entries[char] then
		return
	end
	local entry: Entry = {
		Char = char,
		Driver = nil,
		Phase = 0,
		Breath = math.random() * TAU,
		Step = 0,
		Seq = char:GetAttribute("AnimSeq") or 0,
		Shot = nil,
		LocalShot = nil,
		Vel = nil,
		Yaw = nil,
		Fwd = Vector3.new(0, 0, -1),
		AccelF = 0,
		AccelS = 0,
		TurnRate = 0,
		Exertion = 0,
		Seed = math.random(),
		-- случайный сдвиг, чтобы редко обновляемые персонажи не считались в одном кадре
		Pending = math.random() * 0.1,
		Pose = {},
	}
	entries[char] = entry
	char.Destroying:Connect(function()
		entries[char] = nil
	end)
end

CollectionService:GetInstanceAddedSignal("DBDChar"):Connect(register)
CollectionService:GetInstanceRemovedSignal("DBDChar"):Connect(function(char)
	entries[char :: Model] = nil
end)
for _, char in CollectionService:GetTagged("DBDChar") do
	register(char)
end

local function startShot(entry: Entry, name: string, t: number)
	if name == "Cancel" then
		entry.Shot = nil
		return
	end
	local def = Poses.OneShot[name]
	if def then
		entry.Shot = { Name = name, Def = def, Start = t }
	end
end

-- Мгновенно проиграть анимацию у своего персонажа (не ждать сервер)
function Animator.playLocal(name: string)
	local char = player.Character
	local entry = char and entries[char]
	if entry then
		startShot(entry, name, os.clock())
		entry.LocalShot = { Name = name, At = os.clock() }
	end
end

local function findKillerRoot(): BasePart?
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("Role") == "Killer" then
			return Util.getRoot(p)
		end
	end
	return nil
end

local function wrapAngle(a: number): number
	return (a + math.pi) % TAU - math.pi
end

-- Скорость, ускорение, поворот, усталость, дыхание
local function trackMotion(entry: Entry, root: BasePart, dt: number, vel: Vector3, isKiller: boolean, injured: boolean)
	local look = root.CFrame.LookVector * FLAT
	if look.Magnitude > 0.2 then
		entry.Fwd = look.Unit
	end
	local fwd = entry.Fwd
	local yaw = math.atan2(-fwd.X, -fwd.Z)
	local h = math.max(dt, 1 / 240)
	if entry.Vel and entry.Yaw and dt < LOD.SnapAfter then
		local acc = (vel - entry.Vel) / h
		local right = Vector3.new(-fwd.Z, 0, fwd.X)
		local k = 1 - exp(-dt / 0.15)
		entry.AccelF += (clamp(acc:Dot(fwd), -150, 150) - entry.AccelF) * k
		entry.AccelS += (clamp(acc:Dot(right), -150, 150) - entry.AccelS) * k
		local turn = clamp(wrapAngle(yaw - entry.Yaw) / h, -12, 12)
		entry.TurnRate += (turn - entry.TurnRate) * (1 - exp(-dt / 0.12))
	else
		entry.AccelF, entry.AccelS, entry.TurnRate = 0, 0, 0
	end
	entry.Vel, entry.Yaw = vel, yaw
	local speed = vel.Magnitude
	entry.Exertion = clamp(entry.Exertion + (speed > 12 and dt / 8 or -dt / 14), 0, 1)
	local hz = (0.28 + 0.45 * entry.Exertion + (injured and 0.2 or 0)) * (isKiller and 0.8 or 1)
	entry.Breath = (entry.Breath + TAU * hz * dt) % (TAU * 64)
end

local function choosePose(entry: Entry, t: number, dt: number, killerRoot: BasePart?)
	local char = entry.Char
	local owner = Players:GetPlayerFromCharacter(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local driver = entry.Driver
	if not hum or not root or not driver then
		return nil
	end
	local function attr(name: string): any
		return owner and owner:GetAttribute(name)
	end
	local role = char:GetAttribute("Role")
	local isKiller = role == "Killer"
	local status = attr("Status")
	local health = attr("Health") or 2
	local crouching = attr("Crouching") == true
	local vel = root.Anchored and Vector3.zero or root.AssemblyLinearVelocity * FLAT
	local speed = vel.Magnitude
	local injured = health == 1 and not isKiller
	trackMotion(entry, root, dt, vel, isKiller, injured)

	-- Голова поворачивается к маньяку
	local lookYaw = 0
	if not isKiller and killerRoot and status == "Playing" then
		local rel = root.CFrame:PointToObjectSpace(killerRoot.Position)
		if rel.Magnitude < 30 then
			lookYaw = clamp(math.deg(math.atan2(-rel.X, -rel.Z)), -70, 70)
		end
	end

	local fwd, side = 1, 0
	if speed > 0.5 then
		local dir = vel / speed
		fwd = dir:Dot(entry.Fwd)
		side = dir:Dot(Vector3.new(-entry.Fwd.Z, 0, entry.Fwd.X))
	end
	local p: Poses.Params = {
		Speed = speed,
		Phase = entry.Phase,
		Injured = injured,
		Crouching = crouching,
		Killer = isKiller,
		Carrying = attr("Carrying") == true,
		Wiggle = attr("Wiggle"),
		Struggle = (attr("HookCount") or 0) >= 2,
		LookYaw = lookYaw,
		KillerType = char:GetAttribute("KillerType"),
		Scale = driver.Rig.Scale,
		Forward = fwd,
		Strafe = side,
		AccelForward = entry.AccelF,
		AccelSide = entry.AccelS,
		TurnRate = entry.TurnRate,
		Exertion = entry.Exertion,
		Breath = entry.Breath,
		Seed = entry.Seed,
	}

	-- Фаза шага и звуки шагов (касание стопы — каждые π)
	entry.Phase += Poses.stepRate(speed, crouching, p) * dt
	p.Phase = entry.Phase
	local step = math.floor(entry.Phase / math.pi)
	if step ~= entry.Step then
		entry.Step = step
		local grounded = hum.FloorMaterial ~= Enum.Material.Air
		if speed > 1.5 and grounded and status ~= "Hooked" and status ~= "Carried" and health > 0 then
			Audio.footstep(char, isKiller, speed, crouching)
		end
	end

	conceal(entry, char ~= player.Character and attr("Hidden") == true)

	local base
	local action = attr("ActionName")
	local locomotion = false
	if status == "Hooked" then
		base = Poses.State.Hooked(t, p)
	elseif status == "Carried" then
		base = Poses.State.Carried(t, p)
	elseif attr("Hidden") then
		base = Poses.State.Hidden(t, p)
	elseif attr("Trapped") and action ~= "EscapeTrap" then
		base = Poses.State.Trapped(t, p)
	elseif not isKiller and status == "Playing" and health == 0 then
		base = Poses.State.Crawl(t, p)
	elseif hum.Sit then
		base = Poses.State.Sit(t, p)
	else
		base = Poses.locomotion(t, p)
		locomotion = true
	end
	-- своя таблица позы: слои кладутся в неё, не трогая возвращённые позы
	local pose = Clip.copy(base, entry.Pose)
	if locomotion then
		local actionPose = action and Poses.Action[action]
		if actionPose then
			Clip.layer(pose, actionPose(t, p), 1)
		end
		if attr("Item") == "Flashlight" and attr("ItemActive") then
			pose.RArm = Poses.A(92 + math.sin(t * 3) * 2, 0, 4)
		end
	end

	-- Одноразовая анимация поверх (с плавным входом/выходом, если они заданы)
	local seq = char:GetAttribute("AnimSeq") or 0
	if seq ~= entry.Seq then
		entry.Seq = seq
		local name = char:GetAttribute("Anim")
		local loc = entry.LocalShot
		if not (loc and loc.Name == name and os.clock() - loc.At < 0.5) and typeof(name) == "string" then
			startShot(entry, name, t)
		end
	end
	local stiffness = 1
	local shot = entry.Shot
	if shot then
		local def = shot.Def
		local elapsed = t - shot.Start
		if elapsed >= def.Duration or (shot.Name == "Windup" and attr("PowerCharge") == 0 and elapsed > 0.3) then
			entry.Shot = nil
		else
			local w = Clip.weight(def, elapsed)
			Clip.layer(pose, def.Fn(elapsed / def.Duration, p), w, def.Additive)
			stiffness = 1 + ((def.Stiffness or 1) - 1) * w
		end
	end
	return pose, stiffness
end

-- Как часто обновлять персонажа: 0 — каждый кадр, nil — не обновлять
local function lodInterval(pos: Vector3, scale: number, camCF: CFrame, halfFov: number): number?
	local rel = pos - camCF.Position
	local dist = rel.Magnitude
	if dist > LOD.MaxDistance then
		return nil
	end
	local radius = 4 * scale
	if dist > radius then
		local angle = math.acos(clamp(rel:Dot(camCF.LookVector) / dist, -1, 1))
		if angle > halfFov + math.asin(radius / dist) then
			return dist < LOD.OffscreenNear and LOD.OffscreenInterval or nil
		end
	end
	if dist < LOD.Full then
		return 0
	end
	for _, s in LOD.Steps do
		if dist < s[1] then
			return s[2]
		end
	end
	return nil
end

-- Половина угла обзора по диагонали экрана (с запасом — персонаж «у края» тоже виден)
local function halfFov(): number
	local vp = camera.ViewportSize
	local aspect = (vp and vp.Y > 0) and vp.X / vp.Y or 16 / 9
	local tanV = math.tan(math.rad(camera.FieldOfView) / 2)
	return math.atan(tanV * math.sqrt(1 + aspect * aspect))
end

local function update(entry: Entry, t: number, dt: number, killerRoot: BasePart?)
	if not entry.Driver then
		local rig = Rig.find(entry.Char)
		if not rig then
			return
		end
		entry.Driver = Driver.new(rig)
	end
	local driver = entry.Driver :: Driver.Driver
	local pose, stiffness = choosePose(entry, t, dt, killerRoot)
	if not pose then
		return
	end
	if dt > LOD.SnapAfter then
		Driver.snap(driver)
	end
	if not Driver.apply(driver, pose, dt, stiffness) then
		entry.Driver = nil
	end
end

RunService.PreSimulation:Connect(function(dt)
	local t = os.clock()
	local camCF = camera.CFrame
	local fov = halfFov()
	local killerRoot = findKillerRoot()
	local own = player.Character
	for char, entry in entries do
		if not char.Parent then
			continue
		end
		local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			continue
		end
		entry.Pending += dt
		local scale = entry.Driver and entry.Driver.Rig.Scale or 1
		local interval = if char == own then 0 else lodInterval(root.Position, scale, camCF, fov)
		if interval and entry.Pending >= interval then
			local edt = entry.Pending
			entry.Pending = 0
			update(entry, t, edt, killerRoot)
		end
	end
end)

return Animator
