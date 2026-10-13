-- Погоня: маньяк видит бегущего рядом выжившего -> музыка погони и очки.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Core = script.Parent.Parent.Core
local State = require(Core.State)
local Scoring = require(Core.Scoring)
local Combat = require(script.Parent.Combat)

local Chase = {}

local timer = 0
local GRACE = 2.5

function Chase.update(dt: number)
	timer += dt
	if timer < 0.25 then
		return
	end
	local step = timer
	timer = 0
	local k = State.Killer
	local kroot = k and State.getRoot(k.Player)
	local t = State.now()
	local anyChase = false
	for _, data in State.survivors() do
		local inChase = false
		local root = State.getRoot(data.Player)
		if kroot and root and k.Status == "Playing" and data.Status == "Playing" and not data.Hidden then
			local offset = (root.Position - kroot.Position) * Vector3.new(1, 0, 1)
			local d = offset.Magnitude
			if d <= Config.ChaseDistance and d > 0.1 then
				local facing = kroot.CFrame.LookVector:Dot(offset.Unit)
				local fleeing = data.Player:GetAttribute("Running") == true or d < 12
				if facing > 0.3 and fleeing and Combat.lineOfSight(kroot.Position, root.Position) then
					inChase = true
				end
			end
		end
		if inChase then
			data.ChaseUntil = t + GRACE
		end
		local chased = t < (data.ChaseUntil or 0) and data.Status == "Playing"
		data.Chase = chased
		data.Player:SetAttribute("Chase", chased)
		if chased then
			anyChase = true
			Scoring.add(data.Player, "Boldness", 20 * step, nil)
			if k then
				Scoring.add(k.Player, "Hunter", 15 * step, nil)
			end
		end
	end
	if k then
		k.Player:SetAttribute("Chase", anyChase)
	end
end

return Chase
