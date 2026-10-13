-- Атака маньяка (выпад), оглушение паллетой и ослепление фонариком.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Core = script.Parent.Parent.Core
local State = require(Core.State)
local Actions = require(Core.Actions)
local Health = require(script.Parent.Health)
local Carry = require(script.Parent.Carry)
local Powers = require(script.Parent.Parent.Powers)

local Combat = {}

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.RespectCanCollide = true

-- Исключаем персонажей и мелкий декор при проверке прямой видимости
function Combat.lineOfSight(from: Vector3, to: Vector3): boolean
	local exclude = {}
	for p in State.Participants do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	if State.Map then
		table.insert(exclude, State.Map.Effects)
		table.insert(exclude, State.Map.Traps)
		table.insert(exclude, State.Map.Crows)
	end
	raycastParams.FilterDescendantsInstances = exclude
	return workspace:Raycast(from, to - from, raycastParams) == nil
end

local function tryHit(kdata): boolean
	local kroot = State.getRoot(kdata.Player)
	if not kroot then
		return false
	end
	local forward = kroot.CFrame.LookVector * Vector3.new(1, 0, 1)
	if forward.Magnitude < 0.01 then
		return false
	end
	forward = forward.Unit
	for _, sdata in State.survivors() do
		local sroot = State.getRoot(sdata.Player)
		if sdata.Status == "Playing" and not sdata.Hidden and sdata.Health > 0 and sroot then
			local offset = sroot.Position - kroot.Position
			local flat = offset * Vector3.new(1, 0, 1)
			local d = flat.Magnitude
			if d <= Config.AttackRange * (kdata.Scale or 1) and (d < 1 or forward:Dot(flat.Unit) >= 0.3) then
				if Combat.lineOfSight(kroot.Position, sroot.Position) then
					Health.damage(sdata, "M1")
					Powers.call(kdata, "OnHit", sdata)
					return true
				end
			end
		end
	end
	return false
end

function Combat.onAttack(player: Player)
	local data = State.get(player)
	if not State.Active or not data or data.Role ~= "Killer" then
		return
	end
	local t = State.now()
	if not Actions.canAct(data) or data.Action or t < data.AttackReadyAt then
		return
	end
	if Powers.call(data, "CanAttack") == false then
		return
	end
	data.Lunging = true
	data.LungeUntil = t + Config.KillerLungeTime
	data.AttackReadyAt = math.huge
	State.playAnim(player, "Swing")
	local root = State.getRoot(player)
	if root then
		State.sfx("Swing", root)
	end
end

-- Оглушение (паллета). Маньяк роняет выжившего.
function Combat.stun(duration: number)
	local kdata = State.Killer
	if not kdata or kdata.Status ~= "Playing" then
		return
	end
	kdata.StunnedUntil = State.now() + duration
	kdata.Lunging = false
	kdata.AttackReadyAt = State.now() + duration
	Actions.cancel(kdata)
	Powers.call(kdata, "OnStun")
	if kdata.Carrying then
		Carry.escape(kdata.Carrying, "Спасение паллетой")
	end
	State.playAnim(kdata.Player, "Stun")
	State.effect(kdata.Player, "Stun", duration)
	State.notify(kdata.Player, "Оглушён!", State.YELLOW)
end

-- Ослепление (фонарик)
function Combat.blind(duration: number): boolean
	local kdata = State.Killer
	if not kdata or kdata.Status ~= "Playing" or State.now() < kdata.BlindUntil then
		return false
	end
	kdata.BlindUntil = State.now() + duration
	kdata.Lunging = false
	kdata.AttackReadyAt = math.max(kdata.AttackReadyAt, State.now() + 0.5)
	Actions.cancel(kdata)
	Powers.call(kdata, "OnBlind")
	if kdata.Carrying then
		Carry.escape(kdata.Carrying, "Спасение фонариком")
	end
	State.playAnim(kdata.Player, "Blind")
	State.effect(kdata.Player, "Blind", duration)
	State.notify(kdata.Player, "Ослеплён!", State.YELLOW)
	return true
end

function Combat.update(_dt: number)
	local k = State.Killer
	if not k or not k.Lunging then
		return
	end
	local t = State.now()
	if tryHit(k) then
		k.Lunging = false
		k.SlowUntil = t + Config.AttackCooldownHit
		k.AttackReadyAt = t + Config.AttackCooldownHit
		State.playAnim(k.Player, "Wipe")
	elseif t >= k.LungeUntil then
		k.Lunging = false
		k.SlowUntil = t + Config.AttackCooldownMiss
		k.AttackReadyAt = t + Config.AttackCooldownMiss
	end
end

Remotes.Attack.OnServerEvent:Connect(Combat.onAttack)

return Combat
