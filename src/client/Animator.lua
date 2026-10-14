-- Процедурные анимации R6 для всех персонажей.
-- Motor6D.Transform не реплицируется, поэтому каждый клиент анимирует всех сам,
-- по реплицированным атрибутам (состояние, действие, одноразовые анимации AnimSeq).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Rig = require(ReplicatedStorage.Shared.Anim.Rig)
local Poses = require(ReplicatedStorage.Shared.Anim.Poses)
local Util = require(ReplicatedStorage.Shared.Util)
local Audio = require(script.Parent.Audio)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local Animator = {}

type Entry = {
	Char: Model,
	Rig: Rig.RigData?,
	Current: { [string]: CFrame },
	Phase: number,
	Step: number,
	Seq: number,
	Shot: { Name: string, Start: number, Duration: number }?,
	LocalShot: { Name: string, At: number }?,
}

local entries = {} :: { [Model]: Entry }

local function register(char: Instance)
	if not char:IsA("Model") or entries[char] then
		return
	end
	local entry: Entry = {
		Char = char,
		Rig = nil,
		Current = {},
		Phase = 0,
		Step = 0,
		Seq = char:GetAttribute("AnimSeq") or 0,
		Shot = nil,
		LocalShot = nil,
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

local function startShot(entry: Entry, name: string)
	if name == "Cancel" then
		entry.Shot = nil
		return
	end
	local shot = Poses.OneShot[name]
	if shot then
		entry.Shot = { Name = name, Start = os.clock(), Duration = shot.Duration }
	end
end

-- Мгновенно проиграть анимацию у своего персонажа (не ждать сервер)
function Animator.playLocal(name: string)
	local char = player.Character
	local entry = char and entries[char]
	if entry then
		startShot(entry, name)
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

local function choosePose(entry: Entry, t: number, dt: number, killerRoot: BasePart?)
	local char = entry.Char
	local owner = Players:GetPlayerFromCharacter(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not root then
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
	local speed = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
	if root.Anchored then
		speed = 0
	end

	-- Фаза шага и звуки шагов
	local rate = Poses.stepRate(speed, crouching)
	entry.Phase += rate * dt
	local step = math.floor(entry.Phase / math.pi)
	if step ~= entry.Step then
		entry.Step = step
		local grounded = hum.FloorMaterial ~= Enum.Material.Air
		if speed > 1.5 and grounded and status ~= "Hooked" and status ~= "Carried" and health > 0 then
			Audio.footstep(char, isKiller, speed, crouching)
		end
	end

	-- Голова поворачивается к маньяку, рядом с ним выживший сжимается от страха
	local lookYaw = 0
	local fear = 0
	if not isKiller and killerRoot and status == "Playing" then
		local rel = root.CFrame:PointToObjectSpace(killerRoot.Position)
		if rel.Magnitude < 30 then
			lookYaw = math.clamp(math.deg(math.atan2(-rel.X, -rel.Z)), -70, 70)
		end
		fear = math.clamp(1 - rel.Magnitude / 32, 0, 1)
	end

	local p: Poses.Params = {
		Speed = speed,
		Phase = entry.Phase,
		Injured = health == 1 and not isKiller,
		Crouching = crouching,
		Killer = isKiller,
		Carrying = attr("Carrying") == true,
		Wiggle = attr("Wiggle"),
		Struggle = (attr("HookCount") or 0) >= 2,
		LookYaw = lookYaw,
		KillerType = char:GetAttribute("KillerType"),
		Fear = fear,
	}

	local pose
	local action = attr("ActionName")
	if status == "Hooked" then
		pose = Poses.State.Hooked(t, p)
	elseif status == "Carried" then
		pose = Poses.State.Carried(t, p)
	elseif attr("Hidden") then
		pose = Poses.State.Hidden(t, p)
	elseif attr("Trapped") and action ~= "EscapeTrap" then
		pose = Poses.State.Trapped(t, p)
	elseif not isKiller and status == "Playing" and health == 0 then
		pose = Poses.State.Crawl(t, p)
	elseif hum.Sit then
		pose = Poses.State.Sit(t, p)
	else
		pose = Poses.locomotion(t, p)
		local actionPose = action and Poses.Action[action]
		if actionPose then
			pose = Poses.merge(pose, actionPose(t, p))
		end
		if attr("Item") == "Flashlight" and attr("ItemActive") then
			pose.RArm = Poses.A(92 + math.sin(t * 3) * 2, 0, 4)
		end
	end

	-- Одноразовая анимация поверх
	local seq = char:GetAttribute("AnimSeq") or 0
	if seq ~= entry.Seq then
		entry.Seq = seq
		local name = char:GetAttribute("Anim")
		local loc = entry.LocalShot
		if not (loc and loc.Name == name and os.clock() - loc.At < 0.5) and typeof(name) == "string" then
			startShot(entry, name)
		end
	end
	local shot = entry.Shot
	if shot then
		local a = (t - shot.Start) / shot.Duration
		if a >= 1 or (shot.Name == "Windup" and attr("PowerCharge") == 0 and t - shot.Start > 0.3) then
			entry.Shot = nil
		else
			pose = Poses.merge(pose, Poses.OneShot[shot.Name].Fn(a, p))
		end
	end
	return pose
end

local ZERO = Vector3.zero

RunService.PreSimulation:Connect(function(dt)
	local t = os.clock()
	local camPos = camera.CFrame.Position
	local killerRoot = findKillerRoot()
	local alpha = 1 - math.exp(-16 * dt)
	for char, entry in entries do
		if not char.Parent then
			continue
		end
		local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or (root.Position - camPos).Magnitude > 260 then
			continue
		end
		if not entry.Rig then
			entry.Rig = Rig.find(char)
			if not entry.Rig then
				continue
			end
		end
		local rig = entry.Rig :: Rig.RigData
		local pose = choosePose(entry, t, dt, killerRoot)
		if not pose then
			continue
		end
		for _, name in Rig.JointNames do
			local joint = rig.Joints[name]
			if not joint.Motor.Parent then
				entry.Rig = nil
				break
			end
			local rot = pose[name] or CFrame.identity
			local offset = name == "Root" and (pose.RootPos or ZERO) * rig.Scale or nil
			local target = Rig.transform(joint, rot, offset)
			local current = entry.Current[name] or target
			current = current:Lerp(target, alpha)
			entry.Current[name] = current
			joint.Motor.Transform = current
		end
	end
end)

return Animator
