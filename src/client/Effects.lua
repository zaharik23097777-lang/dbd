-- Визуальные эффекты на клиенте: следы бега и кровь (видит только маньяк),
-- полёт топоров, невидимость Призрака, поршни генераторов, шумы.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Util = require(ReplicatedStorage.Shared.Util)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local Effects = {}

local folder = Instance.new("Folder")
folder.Name = "DBDLocalFX"
folder.Parent = workspace

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.RespectCanCollide = true

local function groundBelow(pos: Vector3): (Vector3?, Vector3?)
	local exclude = { folder }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	groundParams.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(pos, Vector3.new(0, -8, 0), groundParams)
	if hit then
		return hit.Position, hit.Normal
	end
	return nil, nil
end

local function fxPart(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = folder
	return p
end

local function fadeOut(part: BasePart, delayTime: number, duration: number)
	task.delay(delayTime, function()
		if part.Parent then
			TweenService:Create(part, TweenInfo.new(duration), { Transparency = 1 }):Play()
			Debris:AddItem(part, duration + 0.1)
		end
	end)
end

------------------------------------------------------------------------
-- Следы и кровь (только для маньяка)
------------------------------------------------------------------------

local trackTimers = {} :: { [Player]: { Scratch: number, Blood: number } }

local function scratchMark(pos: Vector3)
	local ground = groundBelow(pos)
	if not ground then
		return
	end
	local yaw = math.random() * math.pi * 2
	for i = 1, 3 do
		local p = fxPart({
			Name = "Scratch",
			Size = Vector3.new(0.12, 0.05, 1.6 + math.random()),
			CFrame = CFrame.new(ground + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, yaw, 0) * CFrame.new((i - 2) * 0.35, 0, 0) * CFrame.Angles(
				0,
				(math.random() - 0.5) * 0.4,
				0
			),
			Color = Color3.fromRGB(255, 80, 40),
			Material = Enum.Material.Neon,
			Transparency = 0.15,
		})
		fadeOut(p, 5, 3)
	end
end

local function bloodPool(pos: Vector3)
	local ground = groundBelow(pos)
	if not ground then
		return
	end
	local r = 0.8 + math.random() * 1.2
	local p = fxPart({
		Name = "Blood",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.05, r, r),
		CFrame = CFrame.new(ground + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(110, 0, 0),
		Material = Enum.Material.Glass,
		Transparency = 0.1,
	})
	fadeOut(p, 7, 3)
end

local function updateTracks(dt: number)
	local isKiller = player:GetAttribute("Role") == "Killer" and player:GetAttribute("Status") == "Playing"
	if not isKiller then
		return
	end
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("Role") ~= "Survivor" or p:GetAttribute("Status") ~= "Playing" or p:GetAttribute("Hidden") then
			continue
		end
		local root = Util.getRoot(p)
		if not root then
			continue
		end
		local timers = trackTimers[p] or { Scratch = 0, Blood = 0 }
		trackTimers[p] = timers
		timers.Scratch -= dt
		timers.Blood -= dt
		if p:GetAttribute("Running") and timers.Scratch <= 0 then
			timers.Scratch = 0.3
			scratchMark(root.Position + Vector3.new(math.random() * 2 - 1, 0, math.random() * 2 - 1))
		end
		local health = p:GetAttribute("Health") or 2
		local moving = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude > 1
		if health < 2 and moving and timers.Blood <= 0 then
			timers.Blood = 1.4
			bloodPool(root.Position)
		end
	end
end

------------------------------------------------------------------------
-- Топоры Охотницы
------------------------------------------------------------------------

local projectiles = {} :: { [number]: any }

local function hatchetModel(): Model
	local m = Instance.new("Model")
	m.Name = "Hatchet"
	local handle = fxPart({
		Name = "Handle",
		Size = Vector3.new(0.18, 0.18, 1.8),
		Color = Color3.fromRGB(80, 55, 35),
		Material = Enum.Material.Wood,
	})
	handle.Parent = m
	local head = fxPart({
		Name = "Head",
		Size = Vector3.new(0.1, 0.8, 0.6),
		Color = Color3.fromRGB(170, 165, 160),
		Material = Enum.Material.Metal,
	})
	head.CFrame = handle.CFrame * CFrame.new(0, 0.3, -0.8)
	head.Parent = m
	m.PrimaryPart = handle
	m.Parent = folder
	return m
end

Remotes.Projectile.OnClientEvent:Connect(function(id, origin, velocity, gravity)
	projectiles[id] = {
		Model = hatchetModel(),
		Pos = origin,
		Vel = velocity,
		Gravity = Vector3.new(0, -gravity, 0),
		Spin = 0,
		Stuck = false,
	}
end)

Remotes.ProjectileEnd.OnClientEvent:Connect(function(id, pos, hitPlayer)
	local p = projectiles[id]
	if not p then
		return
	end
	projectiles[id] = nil
	if hitPlayer then
		p.Model:Destroy()
		return
	end
	-- Воткнулся
	local dir = p.Vel.Magnitude > 0.1 and p.Vel.Unit or Vector3.new(0, 0, -1)
	p.Model:PivotTo(CFrame.lookAt(pos - dir * 0.6, pos))
	task.delay(4, function()
		if p.Model.Parent then
			p.Model:Destroy()
		end
	end)
end)

local function updateProjectiles(dt: number)
	for _, p in projectiles do
		local newVel = p.Vel + p.Gravity * dt
		p.Pos += (p.Vel + newVel) * 0.5 * dt
		p.Vel = newVel
		p.Spin += dt * 25
		if p.Vel.Magnitude > 0.1 then
			p.Model:PivotTo(CFrame.lookAt(p.Pos, p.Pos + p.Vel) * CFrame.Angles(-p.Spin, 0, 0))
		end
	end
end

------------------------------------------------------------------------
-- Невидимость Призрака и красное пятно
------------------------------------------------------------------------

local cloakCache = {} :: { [Model]: number }

local function setModifier(char: Model, value: number)
	if cloakCache[char] == value then
		return
	end
	cloakCache[char] = value
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = value
		end
	end
end

local function updateCloak()
	for _, p in Players:GetPlayers() do
		local char = p.Character
		if not char or p:GetAttribute("Role") ~= "Killer" then
			continue
		end
		local state = p:GetAttribute("PowerState")
		if p ~= player then
			local value = 0
			if state == "Cloaked" then
				value = 0.93 + math.sin(os.clock() * 3) * 0.03
			elseif state == "Cloaking" or state == "Uncloaking" then
				value = 0.5 + math.sin(os.clock() * 20) * 0.3
			end
			setModifier(char, value)
		else
			-- Своё красное пятно маньяк не видит
			local head = char:FindFirstChild("Head")
			local stain = head and head:FindFirstChild("RedStain") :: SpotLight?
			if stain and stain.Enabled then
				stain.Enabled = false
			end
		end
	end
end

------------------------------------------------------------------------
-- Поршни генераторов
------------------------------------------------------------------------

local genState = {} :: { [Instance]: { Last: number, Active: number, Base: { [BasePart]: CFrame } } }

local function updateGenerators(dt: number)
	local map = workspace:FindFirstChild("Map")
	local gens = map and map:FindFirstChild("Generators")
	if not gens then
		table.clear(genState)
		return
	end
	local camPos = camera.CFrame.Position
	for _, gen in gens:GetChildren() do
		local body = (gen :: Model).PrimaryPart
		if not body or (body.Position - camPos).Magnitude > 90 then
			continue
		end
		local st = genState[gen]
		if not st then
			st = { Last = gen:GetAttribute("Progress") or 0, Active = 0, Base = {} }
			for i = 1, 2 do
				local piston = gen:FindFirstChild("Piston" .. i) :: BasePart?
				if piston then
					st.Base[piston] = piston.CFrame
				end
			end
			genState[gen] = st
		end
		local p = gen:GetAttribute("Progress") or 0
		if p > st.Last + 1e-5 then
			st.Active = 0.4
		end
		st.Last = p
		st.Active -= dt
		local running = st.Active > 0 or gen:GetAttribute("Done")
		local i = 0
		for piston, base in st.Base do
			i += 1
			local offset = running and math.sin(os.clock() * 22 + i * math.pi) * 0.22 or 0
			piston.CFrame = base * CFrame.new(offset, 0, 0)
		end
	end
end

------------------------------------------------------------------------
-- Шум (видит маньяк)
------------------------------------------------------------------------

function Effects.noise(position: Vector3)
	local p = fxPart({
		Name = "Noise",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(position + Vector3.new(0, 4, 0)),
		Transparency = 1,
	})
	local bb = Instance.new("BillboardGui")
	bb.AlwaysOnTop = true
	bb.Size = UDim2.fromOffset(70, 70)
	bb.Parent = p
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Text = "!"
	l.TextScaled = true
	l.Font = Enum.Font.GothamBlack
	l.TextColor3 = Color3.fromRGB(255, 200, 40)
	l.TextStrokeTransparency = 0.3
	l.Parent = bb
	TweenService:Create(l, TweenInfo.new(4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(p, 4)
end

function Effects.update(dt: number)
	updateTracks(dt)
	updateProjectiles(dt)
	updateCloak()
	updateGenerators(dt)
end

return Effects
