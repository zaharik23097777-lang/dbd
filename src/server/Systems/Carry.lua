-- Подъём, перенос на плече, вырывание, крюки, Сущность и жертвоприношение.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Core = script.Parent.Parent.Core
local State = require(Core.State)
local Actions = require(Core.Actions)
local Lifecycle = require(Core.Lifecycle)
local Scoring = require(Core.Scoring)
local Characters = require(Core.Characters)
local PropFX = require(script.Parent.Parent.Map.PropFX)

local Carry = {}

local function killerScale(kdata): number
	local char = kdata.Player.Character
	local ok, s = pcall(function()
		return char:GetScale()
	end)
	return ok and s or 1
end

------------------------------------------------------------------------
-- Перенос
------------------------------------------------------------------------

function Carry.startCarry(kdata, sdata)
	local kroot = State.getRoot(kdata.Player)
	local sroot = State.getRoot(sdata.Player)
	local shum = State.getHumanoid(sdata.Player)
	local schar = sdata.Player.Character
	if not kroot or not sroot or not shum or not schar then
		return
	end
	Lifecycle.detach(sdata)
	Actions.cancel(sdata)
	sdata.Status = "Carried"
	sdata.CarriedBy = kdata
	sdata.Wiggle = 0
	kdata.Carrying = sdata
	sdata.SavedMassless = {}
	for _, d in schar:GetDescendants() do
		if d:IsA("BasePart") then
			sdata.SavedMassless[d] = d.Massless
			d.Massless = true
		end
	end
	Characters.setCollision(schar, Characters.GROUP_CARRIED)
	shum.PlatformStand = true
	sroot.Anchored = false
	local s = killerScale(kdata)
	-- Тело лежит на правом плече животом вниз, голова за спиной маньяка
	sroot.CFrame = kroot.CFrame
		* CFrame.new(1.4 * s, 1.7 * s, 0.6 * s)
		* CFrame.Angles(math.rad(90), 0, 0)
		* CFrame.Angles(0, math.pi, 0)
	sdata.CarryWeld = Util.weld(kroot, sroot)
	pcall(function()
		sroot:SetNetworkOwner(kdata.Player)
	end)
	State.playAnim(kdata.Player, "Pickup")
	State.sfx("Rustle", kroot)
	State.notifyAll(sdata.Player.DisplayName .. " схвачен маньяком!", State.RED)
	Scoring.add(kdata.Player, "Hunter", 200, "Поднял")
end

function Carry.release(sdata)
	local kdata = sdata.CarriedBy
	if kdata then
		kdata.Carrying = nil
	end
	sdata.CarriedBy = nil
	if sdata.CarryWeld then
		sdata.CarryWeld:Destroy()
		sdata.CarryWeld = nil
	end
	local char = sdata.Player.Character
	if not char then
		return
	end
	for part, massless in sdata.SavedMassless or {} do
		if part.Parent then
			part.Massless = massless
		end
	end
	sdata.SavedMassless = nil
	Characters.setCollision(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.PlatformStand = false
	end
	local sroot = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local kroot = kdata and State.getRoot(kdata.Player)
	if sroot and kroot then
		local look = kroot.CFrame.LookVector * Vector3.new(1, 0, 1)
		local pos = kroot.Position + look.Unit * 3
		sroot.CFrame = CFrame.lookAt(pos, pos + look)
	end
	if sroot then
		pcall(function()
			sroot:SetNetworkOwner(sdata.Player)
		end)
	end
end

-- Выживший вырвался (сам, паллетой или фонариком)
function Carry.escape(sdata, scoreLabel: string?)
	Carry.release(sdata)
	sdata.Status = "Playing"
	sdata.Health = 1
	sdata.Wiggle = 0
	sdata.BoostUntil = State.now() + Config.SurvivorHitBoostTime
	State.notifyAll(sdata.Player.DisplayName .. " вырвался из рук маньяка!", State.GREEN)
	Scoring.add(sdata.Player, "Survival", 1000, scoreLabel or "Вырвался")
end

------------------------------------------------------------------------
-- Крюки
------------------------------------------------------------------------

local function clearEntity(hook: Instance?)
	if hook and hook:IsA("Model") then
		PropFX.entity(hook, false)
	end
end

local function summonEntity(hook: Model)
	if not hook:FindFirstChild("EntityLegs") then
		PropFX.entity(hook, true)
		State.sfx("EntityDrone", hook:FindFirstChild("HangPoint", true))
	end
end

function Carry.sacrifice(sdata)
	if sdata.Sacrificing then
		return
	end
	sdata.Sacrificing = true
	local hook = sdata.Hook
	if hook then
		summonEntity(hook)
	end
	State.playAnim(sdata.Player, "Entity")
	local root = State.getRoot(sdata.Player)
	if root then
		State.sfx("Scream", root)
	end
	local killer = State.Killer and State.Killer.Player
	Scoring.add(killer, "Sacrifice", 2000, "Жертвоприношение")
	task.delay(1.6, function()
		local r = State.getRoot(sdata.Player)
		if r and State.Map then
			local fx = Instance.new("Part")
			fx.Anchored = true
			fx.CanCollide = false
			fx.CanQuery = false
			fx.Shape = Enum.PartType.Ball
			fx.Material = Enum.Material.Neon
			fx.Color = Color3.fromRGB(255, 60, 20)
			fx.Size = Vector3.new(2, 2, 2)
			fx.CFrame = r.CFrame
			fx.Parent = State.Map.Effects
			TweenService:Create(fx, TweenInfo.new(1.4), { Size = Vector3.new(14, 14, 14), Transparency = 1 }):Play()
			Debris:AddItem(fx, 1.5)
			TweenService:Create(r, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				CFrame = r.CFrame + Vector3.new(0, 30, 0),
			}):Play()
		end
		task.delay(1.1, function()
			clearEntity(hook)
			Lifecycle.remove(sdata, "Dead", sdata.Player.DisplayName .. " принесён в жертву Сущности", State.RED)
		end)
	end)
end

function Carry.hang(kdata, hook: Model)
	local sdata = kdata.Carrying
	if not sdata then
		return
	end
	Carry.release(sdata)
	local sroot = State.getRoot(sdata.Player)
	local hp = hook:FindFirstChild("HangPoint") :: BasePart?
	if not sroot or not hp then
		sdata.Status = "Playing"
		return
	end
	sdata.Status = "Hooked"
	sdata.Hook = hook
	sdata.HookTimer = 0
	sdata.HookCount += 1
	sdata.BleedOut = 0
	sdata.Health = 0
	hook:SetAttribute("Occupant", sdata.Player.UserId)
	sroot.Anchored = true
	sroot.CFrame = hp.CFrame
	State.sfx("Clank", hp)
	State.sfx("Scream", hp)
	State.playAnim(sdata.Player, "HookScream")
	Scoring.add(kdata.Player, "Sacrifice", 1000, "Повешен на крюк")
	if sdata.HookCount >= Config.MaxHooks then
		Carry.sacrifice(sdata)
	else
		if sdata.HookCount >= 2 then
			summonEntity(hook)
		end
		State.notifyAll(string.format("%s на крюке! (стадия %d)", sdata.Player.DisplayName, sdata.HookCount), State.RED)
	end
end

function Carry.unhook(sdata, rescuer: Player)
	local hook = sdata.Hook
	local sroot = State.getRoot(sdata.Player)
	if hook then
		hook:SetAttribute("Occupant", 0)
		clearEntity(hook)
	end
	sdata.Hook = nil
	sdata.Status = "Playing"
	sdata.Health = 1
	sdata.HealProgress = 0
	sdata.HookTimer = 0
	sdata.BoostUntil = State.now() + 1.5
	if sroot then
		sroot.Anchored = false
		local hp = hook and hook:FindFirstChild("HangPoint") :: BasePart?
		if hp then
			sroot.CFrame = hp.CFrame * CFrame.new(0, -4, -3)
		end
	end
	State.playAnim(rescuer, "Flinch")
	State.notifyAll(rescuer.DisplayName .. " снял(а) " .. sdata.Player.DisplayName .. " с крюка", State.GREEN)
	Scoring.add(rescuer, "Altruism", 1500, "Спасение")
end

------------------------------------------------------------------------
-- Действия
------------------------------------------------------------------------

local function isCloaked(kdata): boolean
	return kdata.Power ~= nil and (kdata.Power.Cloaked == true or kdata.Power.Transition ~= nil)
end

Actions.register("Pickup", {
	Validate = function(data, target)
		if not target:IsA("Player") or data.Carrying or isCloaked(data) then
			return false
		end
		local td = State.get(target :: Player)
		return td ~= nil
			and td.Role == "Survivor"
			and td.Status == "Playing"
			and not td.Hidden
			and (td.Health == 0 or td.Trapped ~= nil)
			and State.now() >= td.VaultUntil
	end,
	Begin = function(data, target)
		Carry.startCarry(data, State.get(target :: Player))
	end,
})

Actions.register("Hook", {
	AllowCarrying = true,
	Validate = function(data, target)
		return data.Carrying ~= nil and target:GetAttribute("Kind") == "Hook" and target:GetAttribute("Occupant") == 0
	end,
	Complete = function(data, target)
		Carry.hang(data, target :: Model)
	end,
})

Actions.register("Unhook", {
	Validate = function(data, target)
		if not target:IsA("Player") then
			return false
		end
		local td = State.get(target :: Player)
		return td ~= nil and td ~= data and td.Status == "Hooked" and not td.Sacrificing
	end,
	Complete = function(data, target)
		local td = State.get(target :: Player)
		if td and td.Status == "Hooked" and not td.Sacrificing then
			Carry.unhook(td, data.Player)
		end
	end,
})

------------------------------------------------------------------------
-- Цикл
------------------------------------------------------------------------

function Carry.update(dt: number)
	local t = State.now()
	for _, data in State.Participants do
		if data.Role ~= "Survivor" then
			continue
		end
		if data.Status == "Hooked" and not data.Sacrificing then
			data.HookTimer += dt
			if data.HookTimer >= Config.HookStageTime then
				data.HookTimer = 0
				data.HookCount += 1
				if data.HookCount >= Config.MaxHooks then
					Carry.sacrifice(data)
				else
					if data.Hook then
						summonEntity(data.Hook)
					end
					State.notifyAll(data.Player.DisplayName .. " борется с Сущностью!", State.RED)
				end
			end
		elseif data.Status == "Carried" then
			data.Wiggle += dt / Config.WiggleTime
			if data.Wiggle >= 1 then
				local kdata = data.CarriedBy
				Carry.escape(data)
				if kdata then
					kdata.StunnedUntil = t + 3
					State.playAnim(kdata.Player, "Stun")
				end
			end
		end
	end
end

-- Освобождение при выбывании/выходе
Lifecycle.addDetach(function(data)
	if data.CarriedBy then
		Carry.release(data)
	end
	if data.Carrying then
		local carried = data.Carrying
		Carry.release(carried)
		carried.Status = "Playing"
	end
	if data.Hook then
		data.Hook:SetAttribute("Occupant", 0)
		clearEntity(data.Hook)
		data.Hook = nil
		local root = State.getRoot(data.Player)
		if root then
			root.Anchored = false
		end
	end
end)

return Carry
