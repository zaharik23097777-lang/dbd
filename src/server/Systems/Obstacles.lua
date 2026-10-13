-- Паллеты и перелезание через окна/паллеты.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Core = script.Parent.Parent.Core
local State = require(Core.State)
local Actions = require(Core.Actions)
local Scoring = require(Core.Scoring)
local Combat = require(script.Parent.Combat)

local Obstacles = {}

-- Плавно двигает модель паллеты (сервер, короткий твин)
local function tweenModel(model: Model, target: CFrame, duration: number)
	local value = Instance.new("CFrameValue")
	value.Value = model:GetPivot()
	value.Changed:Connect(function(cf)
		model:PivotTo(cf)
	end)
	local tw = TweenService:Create(value, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = target })
	tw.Completed:Connect(function()
		model:PivotTo(target)
		value:Destroy()
	end)
	tw:Play()
end

local function obstacleCFrame(target: Instance): CFrame?
	local kind = target:GetAttribute("Kind")
	if kind == "Pallet" then
		return target:GetAttribute("DropCFrame") :: CFrame
	elseif kind == "Window" and target:IsA("BasePart") then
		return target.CFrame
	end
	return nil
end

Actions.register("DropPallet", {
	Validate = function(_data, target)
		return target:GetAttribute("Kind") == "Pallet" and target:GetAttribute("State") == "Up"
	end,
	Begin = function(data, target)
		local pallet = target :: Model
		local dropCF = pallet:GetAttribute("DropCFrame") :: CFrame
		pallet:SetAttribute("State", "Dropped")
		local hitbox = pallet.PrimaryPart
		if hitbox then
			hitbox.CanCollide = true
		end
		tweenModel(pallet, dropCF, 0.25)
		State.playAnim(data.Player, "PalletDrop")
		task.delay(0.22, function()
			State.sfx("PalletSlam", dropCF.Position)
		end)
		local k = State.Killer
		if k and k.Status == "Playing" then
			local kroot = State.getRoot(k.Player)
			if kroot then
				local rel = dropCF:PointToObjectSpace(kroot.Position)
				if math.abs(rel.X) < 3.5 and math.abs(rel.Z) < 2.4 then
					-- маньяк стоял прямо под паллетой — отталкиваем на его сторону
					local side = rel.Z >= 0 and 1 or -1
					local w = dropCF:PointToWorldSpace(Vector3.new(rel.X, 0, side * 2.8))
					kroot.CFrame = CFrame.new(w.X, kroot.Position.Y, w.Z) * kroot.CFrame.Rotation
				end
				if State.flatDist(kroot.Position, dropCF.Position) <= Config.PalletStunRange then
					Combat.stun(Config.PalletStunTime)
					Scoring.add(data.Player, "Boldness", 1000, "Оглушение паллетой")
				end
			end
		end
	end,
})

Actions.register("Break", {
	Validate = function(_data, target)
		return target:GetAttribute("Kind") == "Pallet" and target:GetAttribute("State") == "Dropped"
	end,
	Complete = function(data, target)
		target:SetAttribute("State", "Broken")
		local pos = (target :: Model):GetPivot().Position
		State.sfx("PalletBreak", pos)
		-- Обломки разлетаются
		for _, d in target:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = false
				d.CanCollide = false
				d.AssemblyLinearVelocity = Vector3.new(math.random(-15, 15), math.random(8, 18), math.random(-15, 15))
			end
		end
		task.delay(2, function()
			target:Destroy()
		end)
		target.Parent = State.Map and State.Map.Effects or target.Parent
		Scoring.add(data.Player, "Brutality", 100, "Паллета сломана")
	end,
})

Actions.register("Vault", {
	Validate = function(data, target)
		local kind = target:GetAttribute("Kind")
		if data.Carrying then
			return false
		end
		if kind == "Window" then
			return true
		end
		return kind == "Pallet" and data.Role == "Survivor" and target:GetAttribute("State") == "Dropped"
	end,
	Begin = function(data, target)
		local root = State.getRoot(data.Player)
		local ocf = obstacleCFrame(target)
		if not root or not ocf then
			return
		end
		local rel = ocf:PointToObjectSpace(root.Position)
		local side = rel.Z >= 0 and 1 or -1
		local x = math.clamp(rel.X, -1.2, 1.2)
		local y = root.Position.Y
		local function at(z: number): Vector3
			local w = ocf:PointToWorldSpace(Vector3.new(x, 0, z))
			return Vector3.new(w.X, y, w.Z)
		end
		local mid = at(0) + Vector3.new(0, 2.2, 0)
		local finish = at(-side * 3.4)
		local dir = (finish - root.Position) * Vector3.new(1, 0, 1)
		if dir.Magnitude < 0.1 then
			return
		end
		dir = dir.Unit
		local duration
		if data.Role == "Killer" then
			duration = 1.6
			State.playAnim(data.Player, "KillerVault")
		else
			duration = data.Sprinting and 0.55 or 0.95
			State.playAnim(data.Player, "Vault")
			if data.Sprinting then
				-- быстрый прыжок шумит
				State.noise(root.Position)
				State.sfx("Vault", root)
				if data.Chase then
					Scoring.add(data.Player, "Boldness", 100, "Прыжок")
				end
			end
		end
		data.VaultUntil = State.now() + duration
		Actions.cancel(data)
		root.Anchored = true
		task.spawn(function()
			local info = TweenInfo.new(duration / 2, Enum.EasingStyle.Linear)
			local t1 = TweenService:Create(root, info, { CFrame = CFrame.lookAt(mid, mid + dir) })
			t1:Play()
			t1.Completed:Wait()
			local t2 = TweenService:Create(root, info, { CFrame = CFrame.lookAt(finish, finish + dir) })
			t2:Play()
			t2.Completed:Wait()
			if root.Parent and data.Status == "Playing" and not data.Hidden and not data.Trapped then
				root.Anchored = false
			end
		end)
	end,
})

return Obstacles
