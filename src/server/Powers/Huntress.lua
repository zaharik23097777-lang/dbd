-- Охотница: метательные топоры (сервер считает полёт, клиенты рисуют).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KillerDefs = require(ReplicatedStorage.Shared.KillerDefs)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Server = script.Parent.Parent
local State = require(Server.Core.State)
local Scoring = require(Server.Core.Scoring)
local Health = require(Server.Systems.Health)

local DEF = KillerDefs.Huntress
local Huntress = {}

local projectiles = {}
local nextId = 0
local GRAVITY = Vector3.new(0, -DEF.Gravity, 0)

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = true

local function setAttrs(kdata)
	kdata.Player:SetAttribute("PowerCount", kdata.Power.Hatchets)
	local charge = 0
	if kdata.Power.WindupStart then
		charge = math.clamp((State.now() - kdata.Power.WindupStart) / DEF.FullWindup, 0, 1)
	end
	kdata.Player:SetAttribute("PowerCharge", charge)
end

function Huntress.Setup(kdata)
	kdata.Power = { Hatchets = DEF.MaxHatchets, WindupStart = nil }
	table.clear(projectiles)
	setAttrs(kdata)
end

local function cancelWindup(kdata)
	if kdata.Power.WindupStart then
		kdata.Power.WindupStart = nil
		kdata.PowerBusy = false
		State.playAnim(kdata.Player, "Cancel")
		setAttrs(kdata)
	end
end

function Huntress.Press(kdata)
	local t = State.now()
	if kdata.Power.Hatchets <= 0 then
		State.notify(kdata.Player, "Топоры кончились — пополни их в шкафчике (E)", State.WHITE)
		return
	end
	if kdata.Power.WindupStart or kdata.Carrying or kdata.Action or kdata.Lunging then
		return
	end
	if t < kdata.StunnedUntil or t < kdata.BlindUntil or t < kdata.VaultUntil then
		return
	end
	kdata.Power.WindupStart = t
	kdata.PowerBusy = true
	State.playAnim(kdata.Player, "Windup")
	State.sfx("Hum", State.getRoot(kdata.Player))
end

local function throw(kdata, aim: Vector3?, charge: number)
	local char = kdata.Player.Character
	local head = char and char:FindFirstChild("Head") :: BasePart?
	local root = State.getRoot(kdata.Player)
	if not head or not root then
		return
	end
	local look = root.CFrame.LookVector
	local dir = aim or head.CFrame.LookVector
	-- Нельзя бросать назад
	if dir:Dot(look) < 0.2 then
		dir = look
	end
	local k = math.clamp((charge - DEF.MinWindup) / (DEF.FullWindup - DEF.MinWindup), 0, 1)
	local speed = DEF.ThrowSpeedMin + (DEF.ThrowSpeedMax - DEF.ThrowSpeedMin) * k
	local origin = head.Position + root.CFrame.RightVector * 0.8 + dir * 1.2
	local vel = dir * speed
	nextId += 1
	table.insert(projectiles, { Id = nextId, Pos = origin, Vel = vel, Life = 0, Owner = kdata })
	kdata.Power.Hatchets -= 1
	Remotes.Projectile:FireAllClients(nextId, origin, vel, DEF.Gravity)
	State.sfx("Throw", origin)
	State.playAnim(kdata.Player, "Throw")
end

function Huntress.Release(kdata, aim: Vector3?)
	local start = kdata.Power.WindupStart
	if not start then
		return
	end
	local charge = State.now() - start
	kdata.Power.WindupStart = nil
	kdata.PowerBusy = false
	if charge >= DEF.MinWindup and kdata.Status == "Playing" then
		throw(kdata, aim, charge)
	else
		State.playAnim(kdata.Player, "Cancel")
	end
	setAttrs(kdata)
end

function Huntress.CanAttack(kdata)
	return kdata.Power.WindupStart == nil
end

function Huntress.SpeedOverride(kdata, _t)
	if kdata.Power.WindupStart then
		return DEF.WindupSpeed
	end
	return nil
end

function Huntress.OnStun(kdata)
	cancelWindup(kdata)
end
Huntress.OnBlind = Huntress.OnStun

function Huntress.OnLockerSearched(kdata)
	if kdata.Power.Hatchets < DEF.MaxHatchets then
		kdata.Power.Hatchets = DEF.MaxHatchets
		setAttrs(kdata)
		State.notify(kdata.Player, "Топоры пополнены", State.WHITE)
		State.sfx("Rustle", State.getRoot(kdata.Player))
	end
end

local function survivorFromPart(part: Instance)
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		for player, data in State.Participants do
			if player.Character == model and data.Role == "Survivor" then
				return data
			end
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

function Huntress.Update(kdata, dt: number)
	setAttrs(kdata)
	if #projectiles == 0 then
		return
	end
	local exclude = { kdata.Player.Character }
	if State.Map then
		table.insert(exclude, State.Map.Effects)
		table.insert(exclude, State.Map.Crows)
		table.insert(exclude, State.Map.Traps)
	end
	-- Спрятанных и висящих не задеваем
	for _, data in State.Participants do
		if data.Role == "Survivor" and data.Player.Character and (data.Status ~= "Playing" or data.Hidden) then
			table.insert(exclude, data.Player.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	for i = #projectiles, 1, -1 do
		local p = projectiles[i]
		local newVel = p.Vel + GRAVITY * dt
		local newPos = p.Pos + (p.Vel + newVel) * 0.5 * dt
		p.Life += dt
		local result = workspace:Raycast(p.Pos, newPos - p.Pos, params)
		local done = false
		if result then
			local sdata = survivorFromPart(result.Instance)
			if sdata and sdata.Status == "Playing" and sdata.Health > 0 then
				Health.damage(sdata, "Hatchet")
				Scoring.add(kdata.Player, "Deviousness", 700, "Попадание топором")
				Remotes.ProjectileEnd:FireAllClients(p.Id, result.Position, true)
			else
				Remotes.ProjectileEnd:FireAllClients(p.Id, result.Position, false)
				State.sfx("Thud", result.Position)
			end
			done = true
		elseif p.Life > 4 or newPos.Y < -20 then
			Remotes.ProjectileEnd:FireAllClients(p.Id, newPos, false)
			done = true
		end
		if done then
			table.remove(projectiles, i)
		else
			p.Pos = newPos
			p.Vel = newVel
		end
	end
end

function Huntress.Cleanup(_kdata)
	table.clear(projectiles)
end

return Huntress
