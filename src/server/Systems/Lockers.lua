-- Шкафчики: спрятаться, выйти, обыскать (маньяк хватает выжившего).
local TweenService = game:GetService("TweenService")

local Core = script.Parent.Parent.Core
local State = require(Core.State)
local Actions = require(Core.Actions)
local Lifecycle = require(Core.Lifecycle)
local Scoring = require(Core.Scoring)
local PropFX = require(script.Parent.Parent.Map.PropFX)
local Carry = require(script.Parent.Carry)
local Powers = require(script.Parent.Parent.Powers)

local Lockers = {}

-- Открыть и закрыть дверь (анимация на сервере, видят все)
local function swingDoor(locker: Model, holdTime: number)
	PropFX.swingLockerDoor(locker, holdTime, function()
		if locker.Parent then
			State.sfx("LockerDoor", locker.PrimaryPart)
		end
	end)
end

local function insideCF(locker: Model): CFrame?
	local inside = locker:FindFirstChild("Inside") :: BasePart?
	return inside and inside.CFrame
end

local function moveRoot(root: BasePart, target: CFrame, duration: number)
	local tw = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Quad), { CFrame = target })
	tw:Play()
end

-- Вытащить игрока из шкафчика без анимации входа/выхода
local function freeFromLocker(data, moveOut: boolean)
	local locker = data.Hidden
	if not locker then
		return
	end
	data.Hidden = nil
	data.Player:SetAttribute("Hidden", nil)
	locker:SetAttribute("Occupant", 0)
	local root = State.getRoot(data.Player)
	local cf = insideCF(locker)
	if root then
		if moveOut and cf then
			root.CFrame = cf * CFrame.new(0, 0, -2.8)
		end
		root.Anchored = false
	end
end

Actions.register("EnterLocker", {
	Validate = function(data, target)
		return target:GetAttribute("Kind") == "Locker" and target:GetAttribute("Occupant") == 0 and not data.Hidden
	end,
	Begin = function(data, target)
		local locker = target :: Model
		local root = State.getRoot(data.Player)
		local cf = insideCF(locker)
		if not root or not cf then
			return
		end
		local fast = data.Sprinting
		local duration = fast and 0.35 or 0.7
		locker:SetAttribute("Occupant", data.Player.UserId)
		data.Hidden = locker
		data.Player:SetAttribute("Hidden", true)
		data.VaultUntil = State.now() + duration
		root.Anchored = true
		moveRoot(root, cf, duration)
		swingDoor(locker, duration - 0.1)
		if fast then
			State.noise(cf.Position)
		end
	end,
})

Actions.register("ExitLocker", {
	AllowHidden = true,
	Validate = function(data, target)
		return data.Hidden == target
	end,
	Begin = function(data, target)
		local locker = target :: Model
		local root = State.getRoot(data.Player)
		local cf = insideCF(locker)
		data.Hidden = nil
		data.Player:SetAttribute("Hidden", nil)
		locker:SetAttribute("Occupant", 0)
		data.VaultUntil = State.now() + 0.6
		swingDoor(locker, 0.4)
		if root and cf then
			moveRoot(root, cf * CFrame.new(0, 0, -2.8), 0.5)
			task.delay(0.55, function()
				if root.Parent and data.Status == "Playing" and not data.Hidden and not data.Trapped then
					root.Anchored = false
				end
			end)
		elseif root then
			root.Anchored = false
		end
	end,
})

Actions.register("SearchLocker", {
	Validate = function(_data, target)
		return target:GetAttribute("Kind") == "Locker"
	end,
	Begin = function(_data, target)
		swingDoor(target :: Model, 0.8)
	end,
	Complete = function(data, target)
		local occupantId = target:GetAttribute("Occupant") :: number
		if occupantId ~= 0 then
			for _, sdata in State.Participants do
				if sdata.Hidden == target and sdata.Status == "Playing" then
					freeFromLocker(sdata, true)
					sdata.Health = 0
					Carry.startCarry(data, sdata)
					State.notifyAll(sdata.Player.DisplayName .. " вытащен из шкафчика!", State.RED)
					Scoring.add(data.Player, "Deviousness", 1000, "Вытащил из шкафчика")
					return
				end
			end
		end
		Powers.call(data, "OnLockerSearched")
	end,
})

Lifecycle.addDetach(function(data)
	if data.Hidden then
		freeFromLocker(data, true)
	end
end)

return Lockers
