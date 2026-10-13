-- Персонажи R6: появление, внешний вид маньяков, группы столкновений.
-- Персонажи создаются вручную (CharacterAutoLoads = false), чтобы гарантировать R6
-- и полностью управлять анимациями (стандартный Animate удаляется).
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KillerDefs = require(ReplicatedStorage.Shared.KillerDefs)
local Util = require(ReplicatedStorage.Shared.Util)
local MapBuilder = require(script.Parent.Parent.Map.MapBuilder)
local KillerGear = require(script.Parent.Parent.Map.Art.KillerGear)

local Characters = {}

Characters.GROUP_ROOT = "DBDChars"
Characters.GROUP_LIMBS = "DBDLimbs"
Characters.GROUP_CARRIED = "DBDCarried"
Characters.GROUP_SEATS = "DBDSeats"

local function setupGroups()
	for _, g in { Characters.GROUP_ROOT, Characters.GROUP_LIMBS, Characters.GROUP_CARRIED, Characters.GROUP_SEATS } do
		PhysicsService:RegisterCollisionGroup(g)
	end
	-- Конечности не сталкиваются ни с чем: позы (ползание, крюк, перелезание) двигают их свободно.
	-- Сталкивается только HumanoidRootPart.
	for _, other in { "Default", Characters.GROUP_ROOT, Characters.GROUP_LIMBS, Characters.GROUP_CARRIED } do
		PhysicsService:CollisionGroupSetCollidable(Characters.GROUP_LIMBS, other, false)
		PhysicsService:CollisionGroupSetCollidable(Characters.GROUP_CARRIED, other, false)
	end
	-- Брёвна-сиденья в лобби «касаются» ног (у ног CanCollide = false, так что они не толкаются),
	-- иначе Seat не сработает: HumanoidRootPart висит выше бревна.
	PhysicsService:CollisionGroupSetCollidable(Characters.GROUP_SEATS, Characters.GROUP_LIMBS, true)
end
setupGroups()

-- Вызывается при смерти персонажа (Match подставляет свой обработчик)
Characters.OnDied = nil :: ((Player, Model) -> boolean)?

local descriptionCache = {}

local SKIN = {
	Color3.fromRGB(234, 184, 146),
	Color3.fromRGB(204, 142, 105),
	Color3.fromRGB(160, 110, 80),
	Color3.fromRGB(105, 70, 50),
}
local CLOTH = {
	Color3.fromRGB(60, 80, 110),
	Color3.fromRGB(110, 50, 45),
	Color3.fromRGB(70, 90, 60),
	Color3.fromRGB(120, 110, 90),
	Color3.fromRGB(50, 50, 55),
}

local function randomDescription(): HumanoidDescription
	local d = Instance.new("HumanoidDescription")
	local skin = SKIN[math.random(#SKIN)]
	local shirt = CLOTH[math.random(#CLOTH)]
	local pants = CLOTH[math.random(#CLOTH)]:Lerp(Color3.new(0, 0, 0), 0.3)
	d.HeadColor = skin
	d.LeftArmColor = skin
	d.RightArmColor = skin
	d.TorsoColor = shirt
	d.LeftLegColor = pants
	d.RightLegColor = pants
	return d
end

function Characters.getDescription(player: Player): HumanoidDescription
	local cached = descriptionCache[player]
	if cached then
		return cached:Clone()
	end
	local desc
	if player.UserId > 0 then
		local ok, result = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(player.UserId)
		end)
		if ok then
			desc = result
		end
	end
	desc = desc or randomDescription()
	descriptionCache[player] = desc
	return desc:Clone()
end

------------------------------------------------------------------------
-- Создание и появление
------------------------------------------------------------------------

local function stripDefaults(char: Model)
	for _, d in char:GetDescendants() do
		if d:IsA("Animator") or ((d:IsA("LocalScript") or d:IsA("Script")) and d.Name == "Animate") then
			d:Destroy()
		end
	end
end

function Characters.setCollision(char: Model, group: string?)
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") then
			if group then
				d.CollisionGroup = group
			elseif d.Name == "HumanoidRootPart" then
				d.CollisionGroup = Characters.GROUP_ROOT
				d.CanCollide = true
			else
				d.CollisionGroup = Characters.GROUP_LIMBS
			end
		end
	end
end

function Characters.build(player: Player, role: string?, killerType: string?): Model
	local desc
	local def
	if role == "Killer" then
		def = KillerDefs.get(killerType)
		desc = Instance.new("HumanoidDescription")
	else
		desc = Characters.getDescription(player)
	end
	local ok, char = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6)
	end)
	if not ok or not char then
		warn("[DBD] Не удалось создать персонажа из описания: " .. tostring(char))
		char = Players:CreateHumanoidModelFromDescription(randomDescription(), Enum.HumanoidRigType.R6)
	end
	char.Name = player.Name
	stripDefaults(char)
	if def then
		KillerGear.dress(char, def)
		if def.Scale ~= 1 then
			pcall(function()
				char:ScaleTo(def.Scale)
			end)
		end
	end
	Characters.setCollision(char)
	char:SetAttribute("Role", role)
	char:SetAttribute("KillerType", def and def.Id or nil)
	char:SetAttribute("AnimSeq", 0)
	CollectionService:AddTag(char, "DBDChar")
	return char
end

function Characters.spawn(player: Player, cframe: CFrame, role: string?, killerType: string?): Model?
	if not player.Parent then
		return nil
	end
	local old = player.Character
	local char = Characters.build(player, role, killerType)
	if not player.Parent then
		char:Destroy()
		return nil
	end
	if old then
		old:Destroy()
	end
	char:PivotTo(cframe)
	char.Parent = workspace
	player.Character = char

	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.BreakJointsOnDeath = false
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		hum.UseJumpPower = true
		if role then
			hum.JumpPower = 0
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		else
			hum.JumpPower = 40
			hum.WalkSpeed = 14
		end
		hum.Died:Connect(function()
			local handled = Characters.OnDied and Characters.OnDied(player, char)
			if not handled then
				task.wait(3)
				if player.Parent and player.Character == char then
					Characters.spawnLobby(player)
				end
			end
		end)
	end
	return char
end

function Characters.spawnLobby(player: Player): Model?
	return Characters.spawn(player, MapBuilder.LobbySpawn(), nil, nil)
end

Players.PlayerRemoving:Connect(function(player)
	descriptionCache[player] = nil
end)

return Characters
