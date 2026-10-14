--!nocheck
-- Мини-эмулятор движка Roblox для тестов в Lune.
-- Экземпляры, свойства, атрибуты, события, планировщик task.* с управляемым временем,
-- Raycast по коробкам деталей, заглушки сервисов. Скрипты берутся из собранного .rbxlx.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Vector3 = roblox.Vector3

-- В Lune CFrame.lookAt зеркалит Z (lookAt в сторону +Z даёт LookVector -Z).
-- Подменяем на реализацию, совпадающую с Roblox.
local RealCFrame = roblox.CFrame
local function lookAt(pos, target, up)
	local look = target - pos
	if look.Magnitude < 1e-9 then
		return RealCFrame.new(pos)
	end
	look = look.Unit
	up = up or Vector3.new(0, 1, 0)
	local right = look:Cross(up)
	if right.Magnitude < 1e-6 then
		right = look:Cross(Vector3.new(0, 0, 1))
	end
	right = right.Unit
	local newUp = right:Cross(look).Unit
	return RealCFrame.fromMatrix(pos, right, newUp, -look)
end
local CFrame = setmetatable({
	lookAt = lookAt,
	new = function(...)
		local n = select("#", ...)
		local a, b = ...
		if n == 0 then
			return RealCFrame.new()
		elseif n == 2 and typeof(a) == "Vector3" and typeof(b) == "Vector3" then
			return lookAt(a, b)
		end
		return RealCFrame.new(...)
	end,
}, { __index = RealCFrame })

local Fake = {}

------------------------------------------------------------------------
-- Планировщик со своим временем
------------------------------------------------------------------------

local Sched = { Time = 0, Queue = {}, Errors = {} }
Fake.Sched = Sched

local function report(err, where)
	table.insert(Sched.Errors, tostring(where or "") .. ": " .. tostring(err))
end

local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		report(err .. "\n" .. debug.traceback(co), "coroutine")
	end
end

local function runFn(fn, ...)
	local co = coroutine.create(fn)
	resume(co, ...)
	return co
end

local Task = {}
function Task.spawn(fn, ...)
	if type(fn) == "thread" then
		resume(fn, ...)
		return fn
	end
	return runFn(fn, ...)
end
function Task.defer(fn, ...)
	return Task.delay(0, fn, ...)
end
function Task.delay(t, fn, ...)
	local entry = { At = Sched.Time + (t or 0), Fn = fn, Args = table.pack(...) }
	table.insert(Sched.Queue, entry)
	return entry
end
function Task.wait(t)
	local co = coroutine.running()
	table.insert(Sched.Queue, { At = Sched.Time + (t or 0), Co = co, Args = table.pack() })
	coroutine.yield()
	return t or 0
end
function Task.cancel(entry)
	for i, e in Sched.Queue do
		if e == entry then
			table.remove(Sched.Queue, i)
			return
		end
	end
end

function Sched.advance(dt)
	Sched.Time += dt
	local guard = 0
	while true do
		guard += 1
		if guard > 10000 then
			error("scheduler runaway")
		end
		local due
		for i, e in Sched.Queue do
			if e.At <= Sched.Time then
				due = table.remove(Sched.Queue, i)
				break
			end
		end
		if not due then
			break
		end
		if due.Co then
			if coroutine.status(due.Co) == "suspended" then
				resume(due.Co, table.unpack(due.Args, 1, due.Args.n))
			end
		elseif type(due.Fn) == "thread" then
			resume(due.Fn, table.unpack(due.Args, 1, due.Args.n))
		else
			runFn(due.Fn, table.unpack(due.Args, 1, due.Args.n))
		end
	end
end

------------------------------------------------------------------------
-- Сигналы
------------------------------------------------------------------------

local Signal = {}
Signal.__index = Signal
function Signal.new()
	return setmetatable({ Handlers = {} }, Signal)
end
function Signal:Connect(fn)
	local conn = { Connected = true }
	local entry = { Fn = fn, Conn = conn }
	table.insert(self.Handlers, entry)
	function conn.Disconnect()
		conn.Connected = false
	end
	return conn
end
Signal.Once = Signal.Connect
function Signal:Fire(...)
	for _, h in table.clone(self.Handlers) do
		if h.Conn.Connected then
			runFn(h.Fn, ...)
		end
	end
end
function Signal:Wait()
	return nil -- для тестов не ждём
end
Fake.Signal = Signal

------------------------------------------------------------------------
-- Экземпляры
------------------------------------------------------------------------

local PARENT_CLASS = {
	Part = "FormFactorPart",
	FormFactorPart = "BasePart",
	Seat = "Part",
	SpawnLocation = "Part",
	WedgePart = "FormFactorPart",
	MeshPart = "BasePart",
	BasePart = "PVInstance",
	Model = "PVInstance",
	Workspace = "WorldRoot",
	WorldRoot = "Model",
	PVInstance = "Instance",
	Frame = "GuiObject",
	ScrollingFrame = "GuiObject",
	TextLabel = "GuiObject",
	TextButton = "GuiButton",
	ImageButton = "GuiButton",
	ImageLabel = "GuiObject",
	GuiButton = "GuiObject",
	GuiObject = "GuiBase2d",
	ScreenGui = "LayerCollector",
	BillboardGui = "LayerCollector",
	SurfaceGui = "LayerCollector",
	LayerCollector = "GuiBase2d",
	GuiBase2d = "Instance",
	Script = "BaseScript",
	LocalScript = "Script",
	BaseScript = "LuaSourceContainer",
	ModuleScript = "LuaSourceContainer",
	LuaSourceContainer = "Instance",
	Motor6D = "Motor",
	Motor = "JointInstance",
	Weld = "JointInstance",
	JointInstance = "Instance",
	PointLight = "Light",
	SpotLight = "Light",
	Light = "Instance",
	Decal = "FaceInstance",
	FaceInstance = "Instance",
	Shirt = "Clothing",
	Pants = "Clothing",
	Clothing = "CharacterAppearance",
	ShirtGraphic = "CharacterAppearance",
	BodyColors = "CharacterAppearance",
	CharacterAppearance = "Instance",
	Accessory = "Accoutrement",
	Accoutrement = "Instance",
	NumberValue = "ValueBase",
	CFrameValue = "ValueBase",
	ValueBase = "Instance",
	Camera = "PVInstance",
}

local EVENTS = {
	Changed = true,
	Died = true,
	Touched = true,
	OnServerEvent = true,
	OnClientEvent = true,
	Activated = true,
	Ended = true,
	Destroying = true,
	ChildAdded = true,
	ChildRemoved = true,
	DescendantAdded = true,
	CharacterAdded = true,
	CharacterRemoving = true,
	PlayerAdded = true,
	PlayerRemoving = true,
	Heartbeat = true,
	PreSimulation = true,
	RenderStepped = true,
	Stepped = true,
	Event = true,
	MouseButton1Click = true,
}

local isFake = setmetatable({}, { __mode = "k" })
Fake.isFake = isFake

local Instance = {}
local methods = {}
local World -- текущий мир (для Raycast и т.п.)

local function defaultProp(self, key)
	local cls = self._class
	if key == "Name" then
		return cls
	elseif key == "ClassName" then
		return cls
	end
	if Instance.isA(cls, "BasePart") then
		if key == "Position" then
			return self._props.CFrame and self._props.CFrame.Position or Vector3.zero
		elseif key == "CFrame" then
			return CFrame.new()
		elseif key == "Size" then
			return Vector3.new(4, 1, 2)
		elseif key == "Anchored" or key == "Massless" then
			return false
		elseif key == "CanCollide" or key == "CanQuery" or key == "CanTouch" then
			return true
		elseif key == "Transparency" or key == "LocalTransparencyModifier" then
			return 0
		elseif key == "CollisionGroup" then
			return "Default"
		elseif key == "AssemblyLinearVelocity" then
			return Vector3.zero
		elseif key == "Orientation" then
			return Vector3.zero
		end
	end
	if cls == "Humanoid" then
		local d = {
			Health = 100,
			MaxHealth = 100,
			WalkSpeed = 16,
			JumpPower = 50,
			HipHeight = 0,
			Sit = false,
			PlatformStand = false,
			CameraOffset = Vector3.zero,
			FloorMaterial = roblox.Enum.Material.Plastic,
			MoveDirection = Vector3.zero,
		}
		if d[key] ~= nil then
			return d[key]
		end
	end
	if cls == "Sound" and key == "IsLoaded" then
		-- Звук «загружен», если тест не пометил его ID как битый (World.FailedAssets)
		return not (World and World.FailedAssets and World.FailedAssets[rawget(self, "_props").SoundId])
	end
	if key == "Enabled" or key == "Visible" then
		return true
	end
	if key == "Transform" then
		return CFrame.new()
	end
	return nil
end

local INSTANCE_MT = {}

function INSTANCE_MT.__index(self, key)
	local m = methods[key]
	if m then
		return m
	end
	local special = rawget(self, "_special")
	if special and special[key] ~= nil then
		return special[key]
	end
	local props = rawget(self, "_props")
	local v = props[key]
	if v ~= nil then
		return v
	end
	if EVENTS[key] or (type(key) == "string" and key:match("Changed$")) then
		local s = Signal.new()
		props[key] = s
		return s
	end
	local child = methods.FindFirstChild(self, key)
	if child then
		return child
	end
	return defaultProp(self, key)
end

function INSTANCE_MT.__newindex(self, key, value)
	local props = rawget(self, "_props")
	if key == "Parent" then
		methods._setParent(self, value)
		return
	end
	if key == "Position" and Instance.isA(self._class, "BasePart") then
		local cf = props.CFrame or CFrame.new()
		props.CFrame = cf.Rotation + value
		return
	end
	if key == "CFrame" and value == nil then
		error("CFrame = nil")
	end
	if World and World.Strict and type(key) == "string" and key:sub(1, 1) ~= "_" then
		Fake.validate(self, key, value)
	end
	local old = props[key]
	props[key] = value
	if key == "Value" and old ~= value and props.Changed then
		props.Changed:Fire(value)
	elseif key == "Character" and self._class == "Player" and value and old ~= value then
		if props.CharacterAdded then
			props.CharacterAdded:Fire(value)
		end
	end
	if key == "CFrame" or key == "Size" or key == "CanCollide" or key == "CanQuery" then
		if World then
			World.PartsDirty = true
		end
	end
end

INSTANCE_MT.__tostring = function(self)
	return "Fake<" .. self._class .. ":" .. tostring(rawget(self, "_props").Name or self._class) .. ">"
end

-- Строгий режим: проверяем имя и тип свойства на настоящем экземпляре Lune (база свойств Roblox)
local shadowCache = setmetatable({}, { __mode = "k" })
local NO_SHADOW = { DataModel = true }
function Fake.validate(self, key, value)
	if isFake[value] or EVENTS[key] then
		return
	end
	local cls = self._class
	if NO_SHADOW[cls] then
		return
	end
	local shadow = shadowCache[self]
	if shadow == nil then
		local ok, inst = pcall(roblox.Instance.new, cls)
		shadow = ok and inst or false
		shadowCache[self] = shadow
	end
	if not shadow then
		return
	end
	local ok, err = pcall(function()
		shadow[key] = value
	end)
	if not ok then
		report(("%s.%s = %s: %s"):format(cls, key, tostring(value), tostring(err):match("^[^\n]*") or tostring(err)), "property")
	end
end

function Instance.isA(cls, target)
	while cls do
		if cls == target then
			return true
		end
		cls = PARENT_CLASS[cls]
	end
	return target == "Instance"
end

function Instance.new(className, parent)
	local self = setmetatable({ _class = className, _props = {}, _children = {}, _attrs = {} }, INSTANCE_MT)
	isFake[self] = true
	if parent then
		self.Parent = parent
	end
	return self
end
Fake.Instance = Instance

function methods._setParent(self, parent)
	local props = rawget(self, "_props")
	local old = props.Parent
	if old == parent then
		return
	end
	if parent ~= nil and not isFake[parent] then
		error("Parent must be a fake Instance, got " .. tostring(parent))
	end
	if old then
		local list = rawget(old, "_children")
		for i, c in list do
			if c == self then
				table.remove(list, i)
				break
			end
		end
	end
	props.Parent = parent
	if parent then
		table.insert(rawget(parent, "_children"), self)
	end
	if World then
		World.PartsDirty = true
	end
end

function methods.IsA(self, cls)
	return Instance.isA(self._class, cls)
end
function methods.GetChildren(self)
	return table.clone(rawget(self, "_children"))
end
function methods.GetDescendants(self)
	local out = {}
	local function walk(n)
		for _, c in rawget(n, "_children") do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(self)
	return out
end
function methods.FindFirstChild(self, name, recursive)
	for _, c in rawget(self, "_children") do
		if rawget(c, "_props").Name == name or (rawget(c, "_props").Name == nil and c._class == name) then
			return c
		end
	end
	if recursive then
		for _, c in rawget(self, "_children") do
			local r = methods.FindFirstChild(c, name, true)
			if r then
				return r
			end
		end
	end
	return nil
end
function methods.WaitForChild(self, name)
	return methods.FindFirstChild(self, name)
end
function methods.FindFirstChildOfClass(self, cls)
	for _, c in rawget(self, "_children") do
		if c._class == cls then
			return c
		end
	end
	return nil
end
function methods.FindFirstChildWhichIsA(self, cls)
	for _, c in rawget(self, "_children") do
		if Instance.isA(c._class, cls) then
			return c
		end
	end
	return nil
end
function methods.FindFirstAncestorOfClass(self, cls)
	local p = self.Parent
	while p do
		if p._class == cls then
			return p
		end
		p = p.Parent
	end
	return nil
end
function methods.FindFirstAncestor(self, name)
	local p = self.Parent
	while p do
		if p.Name == name then
			return p
		end
		p = p.Parent
	end
	return nil
end
function methods.IsDescendantOf(self, other)
	local p = self.Parent
	while p do
		if p == other then
			return true
		end
		p = p.Parent
	end
	return false
end
function methods.GetFullName(self)
	local parts = {}
	local n = self
	while n and n._class ~= "DataModel" do
		table.insert(parts, 1, n.Name)
		n = n.Parent
	end
	return table.concat(parts, ".")
end
function methods.Destroy(self)
	local props = rawget(self, "_props")
	if props.Destroying then
		props.Destroying:Fire()
	end
	for _, c in methods.GetChildren(self) do
		methods.Destroy(c)
	end
	methods._setParent(self, nil)
	rawget(self, "_props").__destroyed = true
end
function methods.ClearAllChildren(self)
	for _, c in methods.GetChildren(self) do
		methods.Destroy(c)
	end
end
function methods.Clone(self)
	-- 1) копируем дерево, запоминая соответствие оригинал -> копия
	local map = {}
	local function copyTree(node)
		local c = Instance.new(node._class)
		map[node] = c
		for k, v in rawget(node, "_attrs") do
			rawget(c, "_attrs")[k] = v
		end
		for _, child in rawget(node, "_children") do
			local cc = copyTree(child)
			rawget(cc, "_props").Parent = c
			table.insert(rawget(c, "_children"), cc)
		end
		return c
	end
	local root = copyTree(self)
	-- 2) свойства: ссылки внутрь дерева -> на копии, сигналы не копируем
	for orig, copy in map do
		for k, v in rawget(orig, "_props") do
			if k == "Parent" then
				continue
			end
			if isFake[v] then
				rawget(copy, "_props")[k] = map[v] or v
			elseif type(v) == "table" and getmetatable(v) == Signal then
				continue
			else
				rawget(copy, "_props")[k] = v
			end
		end
	end
	if World then
		World.PartsDirty = true
	end
	return root
end
function methods.SetAttribute(self, name, value)
	local attrs = rawget(self, "_attrs")
	local old = attrs[name]
	attrs[name] = value
	if old ~= value then
		local sigs = rawget(self, "_attrSignals")
		if sigs and sigs[name] then
			sigs[name]:Fire()
		end
	end
end
function methods.GetAttribute(self, name)
	return rawget(self, "_attrs")[name]
end
function methods.GetAttributes(self)
	return table.clone(rawget(self, "_attrs"))
end
function methods.GetAttributeChangedSignal(self, name)
	local sigs = rawget(self, "_attrSignals")
	if not sigs then
		sigs = {}
		rawset(self, "_attrSignals", sigs)
	end
	sigs[name] = sigs[name] or Signal.new()
	return sigs[name]
end
function methods.GetPropertyChangedSignal(_self, _name)
	return Signal.new()
end

-- PVInstance
function methods.GetPivot(self)
	if Instance.isA(self._class, "BasePart") then
		return self.CFrame
	end
	local pp = self.PrimaryPart
	if pp then
		local off = rawget(pp, "_props").PivotOffset
		return off and pp.CFrame * off or pp.CFrame
	end
	for _, d in methods.GetDescendants(self) do
		if Instance.isA(d._class, "BasePart") then
			return d.CFrame
		end
	end
	return CFrame.new()
end
function methods.PivotTo(self, cf)
	if Instance.isA(self._class, "BasePart") then
		self.CFrame = cf
		return
	end
	local delta = cf * methods.GetPivot(self):Inverse()
	for _, d in methods.GetDescendants(self) do
		if Instance.isA(d._class, "BasePart") then
			d.CFrame = delta * d.CFrame
		end
	end
end
function methods.ScaleTo(self, s)
	rawget(self, "_props").__scale = s
end
function methods.GetScale(self)
	return rawget(self, "_props").__scale or 1
end
function methods.SetNetworkOwner(_self, _p) end
function methods.Emit(_self, _n) end
function methods.Play(self)
	rawget(self, "_props").IsPlaying = true
end
function methods.Stop(self)
	rawget(self, "_props").IsPlaying = false
end
function methods.SetStateEnabled() end
function methods.ChangeState() end
function methods.LoadCharacter() end
function methods.Kick() end

-- Удалённые события: сервер и клиент в одном мире
function methods.FireServer(self, ...)
	local from = World and World.LocalPlayer
	assert(from, "FireServer без LocalPlayer")
	self.OnServerEvent:Fire(from, ...)
end
function methods.FireClient(self, player, ...)
	World:recordRemote(self, player, ...)
	if World.LocalPlayer == player then
		self.OnClientEvent:Fire(...)
	end
end
function methods.FireAllClients(self, ...)
	World:recordRemote(self, "all", ...)
	if World.LocalPlayer then
		self.OnClientEvent:Fire(...)
	end
end

-- Сервисы
function methods.GetService(self, name)
	return World:service(name)
end
function methods.IsServer()
	return World.IsServerContext
end
function methods.IsClient()
	return not World.IsServerContext
end
function methods.IsStudio()
	return true
end
function methods.BindToRenderStep(_self, name, _prio, fn)
	World.RenderSteps[name] = fn
end
function methods.UnbindFromRenderStep(_self, name)
	World.RenderSteps[name] = nil
end
function methods.RegisterCollisionGroup(_self, name)
	World.Groups[name] = World.Groups[name] or {}
end
function methods.CollisionGroupSetCollidable(_self, a, b, value)
	World.Groups[a] = World.Groups[a] or {}
	World.Groups[b] = World.Groups[b] or {}
	World.Groups[a][b] = value
	World.Groups[b][a] = value
end
function methods.AddTag(_self, inst, tag)
	World.Tags[tag] = World.Tags[tag] or {}
	World.Tags[tag][inst] = true
	World:tagSignal(tag, "Added"):Fire(inst)
end
function methods.RemoveTag(_self, inst, tag)
	if World.Tags[tag] then
		World.Tags[tag][inst] = nil
	end
end
function methods.GetTagged(_self, tag)
	local out = {}
	for inst in World.Tags[tag] or {} do
		table.insert(out, inst)
	end
	return out
end
function methods.GetInstanceAddedSignal(_self, tag)
	return World:tagSignal(tag, "Added")
end
function methods.GetInstanceRemovedSignal(_self, tag)
	return World:tagSignal(tag, "Removed")
end
function methods.AddItem(_self, inst, t)
	Task.delay(t or 10, function()
		if inst.Parent then
			inst:Destroy()
		end
	end)
end
function methods.Create(_self, inst, _info, goals)
	local tween = { Completed = Signal.new() }
	function tween.Play()
		for k, v in goals do
			inst[k] = v
		end
		tween.Completed:Fire(roblox.Enum.PlaybackState.Completed)
	end
	function tween.Cancel() end
	function tween.Pause() end
	return tween
end
function methods.GetDataStore()
	error("DataStore недоступен в тестах")
end
function methods.GetPlayers(_self)
	local out = {}
	for _, c in methods.GetChildren(World:service("Players")) do
		if c._class == "Player" then
			table.insert(out, c)
		end
	end
	return out
end
function methods.GetPlayerFromCharacter(_self, char)
	for _, p in methods.GetPlayers() do
		if p.Character == char then
			return p
		end
	end
	return nil
end
function methods.GetHumanoidDescriptionFromUserId()
	error("нет сети")
end
function methods.CreateHumanoidModelFromDescription(_self, _desc, _rig)
	return Fake.buildR6()
end
function methods.BindAction(_self, name, fn, _touch, ...)
	World.Actions[name] = { Fn = fn, Keys = { ... } }
end
function methods.BindActionAtPriority(_self, name, fn, _touch, _prio, ...)
	World.Actions[name] = { Fn = fn, Keys = { ... } }
end
function methods.UnbindAction(_self, name)
	World.Actions[name] = nil
end
-- Поиск звуков Creator Store: без World.AudioSearch (функция params -> pages) — как без сети
function methods.SearchAudioAsync(_self, params)
	if World.AudioSearch then
		return World.AudioSearch(params)
	end
	error("HTTP 403 (Forbidden): поиск звуков недоступен в эмуляторе")
end
-- Загрузка ресурсов: ID из World.FailedAssets не загружаются
function methods.PreloadAsync(_self, list, callback)
	for _, item in list do
		local id = isFake[item] and item.SoundId or item
		local failed = World.FailedAssets and World.FailedAssets[id]
		if callback then
			callback(id, failed and roblox.Enum.AssetFetchStatus.Failure or roblox.Enum.AssetFetchStatus.Success)
		end
	end
end
-- Terrain: записываем заливки (для превью и тестов)
local function terrainFill(kind)
	return function(_self, ...)
		World.TerrainFills = World.TerrainFills or {}
		table.insert(World.TerrainFills, { Kind = kind, Args = table.pack(...) })
	end
end
methods.FillBlock = terrainFill("Block")
methods.FillBall = terrainFill("Ball")
methods.FillCylinder = terrainFill("Cylinder")
methods.FillWedge = terrainFill("Wedge")
function methods.Clear(self)
	if self._class == "Terrain" then
		World.TerrainFills = {}
	end
end
function methods.SetMaterialColor() end
function methods.ReplaceMaterial() end
function methods.SetTitle() end
function methods.SetPosition() end

-- Raycast по коробкам
local function collidable(a, b)
	if a == b and a == "Default" then
		return true
	end
	local g = World.Groups[a]
	if g and g[b] ~= nil then
		return g[b]
	end
	return true
end

function methods.Raycast(self, origin, dir, params)
	if World.PartsDirty or not World.PartCache then
		World.PartCache = {}
		for _, d in methods.GetDescendants(self) do
			if Instance.isA(d._class, "BasePart") then
				table.insert(World.PartCache, d)
			end
		end
		World.PartsDirty = false
	end
	local exclude = params and params.FilterDescendantsInstances or {}
	local group = params and params.CollisionGroup or "Default"
	local best, bestT, bestPart = nil, math.huge, nil
	for _, part in World.PartCache do
		if part.CanQuery == false then
			continue
		end
		if params and params.RespectCanCollide and not part.CanCollide then
			continue
		end
		if not collidable(group, part.CollisionGroup) then
			continue
		end
		local skip = false
		for _, ex in exclude do
			if part == ex or methods.IsDescendantOf(part, ex) then
				skip = true
				break
			end
		end
		if skip then
			continue
		end
		local cf = part.CFrame
		local half = part.Size / 2
		local o = cf:PointToObjectSpace(origin)
		local d = cf:VectorToObjectSpace(dir)
		local tmin, tmax = 0, 1
		local ok = true
		for _, axis in { "X", "Y", "Z" } do
			local oa, da, h = o[axis], d[axis], half[axis]
			if math.abs(da) < 1e-9 then
				if oa < -h or oa > h then
					ok = false
					break
				end
			else
				local t1, t2 = (-h - oa) / da, (h - oa) / da
				if t1 > t2 then
					t1, t2 = t2, t1
				end
				tmin = math.max(tmin, t1)
				tmax = math.min(tmax, t2)
				if tmin > tmax then
					ok = false
					break
				end
			end
		end
		if ok and tmin < bestT then
			bestT, bestPart = tmin, part
		end
	end
	-- Блоки Terrain (кроме воздуха) тоже твёрдые
	if not (params and params.IgnoreWater == "terrain-off") then
		for _, fill in World.TerrainFills or {} do
			if fill.Kind == "Block" and fill.Args[3] ~= roblox.Enum.Material.Air then
				local cf, size = fill.Args[1], fill.Args[2]
				local half = size / 2
				local o = cf:PointToObjectSpace(origin)
				local d = cf:VectorToObjectSpace(dir)
				local tmin, tmax = 0, 1
				local ok = true
				for _, axis in { "X", "Y", "Z" } do
					local oa, da, h = o[axis], d[axis], half[axis]
					if math.abs(da) < 1e-9 then
						if oa < -h or oa > h then
							ok = false
							break
						end
					else
						local t1, t2 = (-h - oa) / da, (h - oa) / da
						if t1 > t2 then
							t1, t2 = t2, t1
						end
						tmin = math.max(tmin, t1)
						tmax = math.min(tmax, t2)
						if tmin > tmax then
							ok = false
							break
						end
					end
				end
				if ok and tmin < bestT then
					bestT, bestPart = tmin, World:service("Workspace").Terrain
				end
			end
		end
	end
	if bestPart then
		best = {
			Instance = bestPart,
			Position = origin + dir * bestT,
			Normal = Vector3.new(0, 1, 0),
			Distance = dir.Magnitude * bestT,
		}
	end
	return best
end

------------------------------------------------------------------------
-- Персонаж R6
------------------------------------------------------------------------

local R_RIGHT = { 0, 0, 1, 0, 1, 0, -1, 0, 0 }
local R_LEFT = { 0, 0, -1, 0, 1, 0, 1, 0, 0 }
local R_NECK = { -1, 0, 0, 0, 0, 1, 0, 1, 0 }
local function cf(x, y, z, r)
	return CFrame.new(x, y, z, table.unpack(r))
end

function Fake.buildR6()
	local char = Instance.new("Model")
	char.Name = "R6"
	local function part(name, size, pos)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = CFrame.new(pos)
		p.Parent = char
		return p
	end
	local hrp = part("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 0, 0))
	hrp.Transparency = 1
	hrp.CanCollide = false
	local torso = part("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 0, 0))
	local head = part("Head", Vector3.new(2, 1, 1), Vector3.new(0, 1.5, 0))
	local la = part("Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0))
	local ra = part("Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0))
	local ll = part("Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0))
	local rl = part("Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0))
	ll.CanCollide = false
	rl.CanCollide = false
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Parent = head
	local function motor(name, parent, p0, p1, c0, c1)
		local m = Instance.new("Motor6D")
		m.Name = name
		m.Part0 = p0
		m.Part1 = p1
		m.C0 = c0
		m.C1 = c1
		m.Parent = parent
	end
	motor("RootJoint", hrp, hrp, torso, cf(0, 0, 0, R_NECK), cf(0, 0, 0, R_NECK))
	motor("Neck", torso, torso, head, cf(0, 1, 0, R_NECK), cf(0, -0.5, 0, R_NECK))
	motor("Right Shoulder", torso, torso, ra, cf(1, 0.5, 0, R_RIGHT), cf(-0.5, 0.5, 0, R_RIGHT))
	motor("Left Shoulder", torso, torso, la, cf(-1, 0.5, 0, R_LEFT), cf(0.5, 0.5, 0, R_LEFT))
	motor("Right Hip", torso, torso, rl, cf(1, -1, 0, R_RIGHT), cf(0.5, 1, 0, R_RIGHT))
	motor("Left Hip", torso, torso, ll, cf(-1, -1, 0, R_LEFT), cf(-0.5, 1, 0, R_LEFT))
	local hum = Instance.new("Humanoid")
	hum.Parent = char
	local animator = Instance.new("Animator")
	animator.Parent = hum
	local animate = Instance.new("LocalScript")
	animate.Name = "Animate"
	animate.Parent = char
	char.PrimaryPart = hrp
	return char
end

------------------------------------------------------------------------
-- Мир
------------------------------------------------------------------------

local WorldMT = {}
WorldMT.__index = WorldMT

local RandomShim = {}
RandomShim.__index = RandomShim
-- Умножение по модулю 2^32 без потери точности (частичные произведения < 2^53)
local function mul32(a, b)
	local alo, ahi = a % 65536, math.floor(a / 65536)
	local blo, bhi = b % 65536, math.floor(b / 65536)
	return ((alo * bhi + ahi * blo) % 65536 * 65536 + alo * blo) % 4294967296
end
-- Нелинейное перемешивание сида (fmix32 из MurmurHash3): у MINSTD первые числа почти линейно
-- зависят от сида, и при сидах 1, 2, 3... в превью и тестах выбирался один и тот же вариант
local function fmix32(h)
	h = bit32.bxor(h, bit32.rshift(h, 16))
	h = mul32(h, 0x85ebca6b)
	h = bit32.bxor(h, bit32.rshift(h, 13))
	h = mul32(h, 0xc2b2ae35)
	return bit32.bxor(h, bit32.rshift(h, 16))
end
function RandomShim.new(seed)
	local self = setmetatable({}, RandomShim)
	local s = fmix32(math.floor(seed or 12345) % 4294967296) % 2147483647
	self.state = s > 0 and s or 12345
	return self
end
function RandomShim:_next()
	self.state = (self.state * 48271) % 2147483647
	return self.state / 2147483647
end
function RandomShim:NextNumber(a, b)
	a = a or 0
	b = b or 1
	return a + (b - a) * self:_next()
end
function RandomShim:NextInteger(a, b)
	return math.floor(a + (b - a + 1) * self:_next())
end

function Fake.newWorld(placePath)
	-- Новый мир: старые корутины и ошибки выбрасываем
	table.clear(Sched.Queue)
	table.clear(Sched.Errors)
	local w = setmetatable({}, WorldMT)
	World = w
	w.Services = {}
	w.Groups = { Default = {} }
	w.Tags = {}
	w.TagSignals = {}
	w.RenderSteps = {}
	w.Actions = {}
	w.Remotes = {}
	w.IsServerContext = true
	w.Cache = {}
	w.Game = Instance.new("DataModel")
	w.Game.Name = "Game"
	-- Скрипты из собранного места
	local place = roblox.deserializePlace(fs.readFile(placePath))
	local function copy(src, dst)
		for _, c in src:GetChildren() do
			local cls = c.ClassName
			local f = Instance.new(cls)
			f.Name = c.Name
			if cls == "ModuleScript" or cls == "Script" or cls == "LocalScript" then
				f.Source = c.Source
			end
			f.Parent = dst
			copy(c, f)
		end
	end
	for _, name in { "ReplicatedStorage", "ServerScriptService", "StarterPlayer" } do
		copy(place:GetService(name), w:service(name))
	end
	local workspace = w:service("Workspace")
	local cam = Instance.new("Camera")
	cam.Name = "Camera"
	cam.CFrame = CFrame.new()
	cam.FieldOfView = 70
	cam.CameraType = roblox.Enum.CameraType.Custom
	cam.Parent = workspace
	workspace.CurrentCamera = cam
	local terrain = Instance.new("Terrain")
	terrain.Name = "Terrain"
	terrain.Parent = workspace
	workspace.Terrain = terrain
	return w
end

function WorldMT:service(name)
	local s = self.Services[name]
	if not s then
		local cls = name
		s = Instance.new(cls)
		s.Name = name
		s.Parent = self.Game
		self.Services[name] = s
	end
	return s
end

function WorldMT:tagSignal(tag, kind)
	local key = tag .. kind
	self.TagSignals[key] = self.TagSignals[key] or Signal.new()
	return self.TagSignals[key]
end

function WorldMT:recordRemote(remote, target, ...)
	table.insert(self.Remotes, { Name = remote.Name, Target = target, Args = table.pack(...) })
	local hook = self.RemoteHooks and self.RemoteHooks[remote.Name]
	if hook then
		hook(target, ...)
	end
end

function WorldMT:env(isClient)
	local w = self
	local osProxy = table.clone(os)
	osProxy.clock = function()
		return Sched.Time
	end
	local env = {
		game = w.Game,
		workspace = w:service("Workspace"),
		Instance = Instance,
		Vector3 = Vector3,
		Vector2 = roblox.Vector2,
		CFrame = CFrame,
		Color3 = roblox.Color3,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		Enum = roblox.Enum,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		NumberRange = roblox.NumberRange,
		Random = RandomShim,
		TweenInfo = {
			new = function()
				return {}
			end,
		},
		RaycastParams = {
			new = function()
				return { FilterDescendantsInstances = {}, CollisionGroup = "Default", RespectCanCollide = false }
			end,
		},
		task = Task,
		os = osProxy,
		typeof = function(v)
			if isFake[v] then
				return "Instance"
			end
			return roblox.typeof and roblox.typeof(v) or typeof(v)
		end,
		warn = function(...)
			report(table.concat({ ... }, " "), "warn")
		end,
		print = print,
		tick = function()
			return Sched.Time
		end,
	}
	local mathProxy = table.clone(math)
	-- Детерминированный math.random, чтобы прогоны повторялись
	local rng = RandomShim.new(777)
	mathProxy.random = function(a, b)
		if a == nil then
			return rng:NextNumber()
		elseif b == nil then
			return rng:NextInteger(1, a)
		end
		return rng:NextInteger(a, b)
	end
	mathProxy.noise = mathProxy.noise or function()
		return 0
	end
	env.math = mathProxy
	env.require = function(module)
		return w:require(module)
	end
	return env
end

-- Клиентские скрипты (внутри StarterPlayer) получают клиентское окружение
local function isClientScript(module)
	local p = module
	while p do
		if p.Name == "StarterPlayer" then
			return true
		end
		p = p.Parent
	end
	return false
end

function WorldMT:load(scriptInst)
	local client = isClientScript(scriptInst)
	local env = self:env(client)
	env.script = scriptInst
	local prev = self.IsServerContext
	self.IsServerContext = not client
	local chunk = luau.load(scriptInst.Source, { debugName = scriptInst:GetFullName(), environment = env })
	return chunk, prev
end

function WorldMT:require(module)
	if self.Cache[module] ~= nil then
		return self.Cache[module]
	end
	assert(module._class == "ModuleScript", "require() ожидает ModuleScript: " .. tostring(module))
	local chunk, prev = self:load(module)
	local result = chunk()
	self.IsServerContext = prev
	self.Cache[module] = result
	return result
end

-- Запустить Script/LocalScript в отдельной корутине
function WorldMT:run(scriptInst)
	local chunk, prev = self:load(scriptInst)
	self.IsServerContext = prev
	return Task.spawn(chunk)
end

function WorldMT:addPlayer(name, userId)
	local p = Instance.new("Player")
	p.Name = name
	p.DisplayName = name
	p.UserId = userId
	p.Parent = self:service("Players")
	self:service("Players").PlayerAdded:Fire(p)
	return p
end

-- Прогон времени: каждый кадр — планировщик и Heartbeat
function WorldMT:step(seconds, dt)
	dt = dt or 1 / 30
	local n = math.max(1, math.floor(seconds / dt + 0.5))
	local rs = self:service("RunService")
	for _ = 1, n do
		Sched.advance(dt)
		rs.PreSimulation:Fire(dt)
		rs.Heartbeat:Fire(dt)
		if self.LocalPlayer then
			rs.RenderStepped:Fire(dt)
			for _, fn in self.RenderSteps do
				runFn(fn, dt)
			end
		end
		if #Sched.Errors > 0 then
			return
		end
	end
end

Fake.CFrame = CFrame
Fake.Vector3 = Vector3
return Fake
