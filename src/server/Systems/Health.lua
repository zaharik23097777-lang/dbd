-- Здоровье выживших: удары, повержение, лечение, истекание кровью.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local Core = script.Parent.Parent.Core
local State = require(Core.State)
local Actions = require(Core.Actions)
local Lifecycle = require(Core.Lifecycle)
local Scoring = require(Core.Scoring)

local Health = {}

local function bloodBurst(part: BasePart)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(150, 0, 0))
	emitter.Size = NumberSequence.new(0.5, 0)
	emitter.Speed = NumberRange.new(6, 14)
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.Lifetime = NumberRange.new(0.4, 0.9)
	emitter.Acceleration = Vector3.new(0, -35, 0)
	emitter.Enabled = false
	emitter.Parent = part
	emitter:Emit(35)
	Debris:AddItem(emitter, 2)
end

-- source: "M1" | "Hatchet" | "Trap"
function Health.damage(sdata, source: string)
	Actions.cancel(sdata)
	sdata.HealProgress = 0
	local root = State.getRoot(sdata.Player)
	if source == "Trap" then
		sdata.Health = math.max(sdata.Health - 1, 1)
	else
		sdata.Health -= 1
	end
	if root then
		bloodBurst(root)
		State.sfx("Hit", root)
	end
	State.playAnim(sdata.Player, "Flinch")
	State.effect(sdata.Player, "Shake", 0.6)
	local killer = State.Killer and State.Killer.Player
	if sdata.Health >= 1 then
		if source ~= "Trap" then
			sdata.BoostUntil = State.now() + Config.SurvivorHitBoostTime
		end
		if root then
			State.sfx("Pain", root)
		end
		State.notify(sdata.Player, "Тебя ранили! Беги!", State.RED)
		Scoring.add(killer, "Brutality", 300, "Удар")
	else
		sdata.Health = 0
		sdata.BleedOut = 0
		if root then
			State.sfx("Scream", root)
		end
		State.notifyAll(sdata.Player.DisplayName .. " повержен!", State.RED)
		Scoring.add(killer, "Brutality", 500, "Повержен")
	end
end

Actions.register("Heal", {
	SkillChecks = true,
	Validate = function(data, target)
		if not target:IsA("Player") then
			return false
		end
		local td = State.get(target :: Player)
		return td ~= nil
			and td ~= data
			and td.Role == "Survivor"
			and td.Status == "Playing"
			and td.Health < 2
			and not td.Hidden
			and not td.Trapped
			and State.now() >= td.VaultUntil
	end,
	Tick = function(data, target, dt)
		local td = State.get(target :: Player)
		td.HealProgress += dt / Config.HealTime
		td.HealedAt = State.now()
		if td.HealProgress >= 1 then
			td.HealProgress = 0
			td.Health += 1
			Actions.cancel(data)
			if td.Health == 1 then
				State.notify(td.Player, "Тебя подняли!", State.GREEN)
				Scoring.add(data.Player, "Altruism", 1250, "Подъём")
			else
				State.notify(td.Player, "Ты полностью вылечен", State.GREEN)
				Scoring.add(data.Player, "Altruism", 1000, "Лечение")
			end
		end
	end,
	Progress = function(_data, target)
		local td = State.get(target :: Player)
		return td and td.HealProgress
	end,
	OnSkillCheck = function(data, target, result)
		local td = State.get(target :: Player)
		if not td then
			return
		end
		if result == "great" then
			td.HealProgress = math.min(td.HealProgress + Config.SkillCheckGreatBonus, 0.999)
			Scoring.add(data.Player, "Altruism", 50, "Отличная проверка")
		elseif result == "fail" then
			td.HealProgress = math.max(td.HealProgress - Config.SkillCheckFailPenalty, 0)
			local root = State.getRoot(td.Player)
			if root then
				State.noise(root.Position)
				State.sfx("Pain", root)
			end
			State.notify(data.Player, "Провал! Маньяк услышал крик.", State.RED)
		end
	end,
})

function Health.update(dt: number)
	local t = State.now()
	for _, data in State.Participants do
		if data.Role == "Survivor" and data.Status == "Playing" and data.Health == 0 then
			if t - (data.HealedAt or 0) > 0.25 then
				data.BleedOut += dt
				if data.BleedOut >= Config.BleedOutTime then
					Lifecycle.remove(data, "Dead", data.Player.DisplayName .. " истёк кровью", State.RED)
				end
			end
		end
	end
end

return Health
