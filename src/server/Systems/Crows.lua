-- Вороны: взлетают, когда рядом пробегает выживший, и выдают его маньяку.
local TweenService = game:GetService("TweenService")

local Core = script.Parent.Parent.Core
local State = require(Core.State)
local Templates = require(script.Parent.Parent.Map.Art.Templates)

local Crows = {}

local crows = {}
local spots = {}
local timer = 0
local rng = Random.new()

local COUNT = 12

local function spawnCrow()
	if #spots == 0 or not State.Map then
		return
	end
	local spot = spots[rng:NextInteger(1, #spots)]
	local cf = spot * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local model = Templates.spawn("Crow", cf, State.Map.Crows)
	table.insert(crows, { Model = model, Pos = cf.Position })
end

local function flyAway(crow)
	local model = crow.Model
	local pivot = model:GetPivot()
	local dir = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
	if dir.Magnitude < 0.1 then
		dir = Vector3.new(1, 0, 0)
	end
	local target = pivot.Position + dir.Unit * 40 + Vector3.new(0, 30, 0)
	local value = Instance.new("CFrameValue")
	value.Value = pivot
	value.Changed:Connect(function(cf)
		if model.Parent then
			model:PivotTo(cf)
		end
	end)
	local tw = TweenService:Create(value, TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Value = CFrame.lookAt(target, target + dir),
	})
	tw.Completed:Connect(function()
		value:Destroy()
		model:Destroy()
	end)
	tw:Play()
	State.sfx("Crow", pivot.Position)
	State.sfx("Flutter", pivot.Position)
	State.noise(pivot.Position)
	task.delay(25, function()
		if State.Active then
			spawnCrow()
		end
	end)
end

function Crows.setup()
	table.clear(crows)
	spots = State.Map and State.Map.CrowSpots or {}
	for _ = 1, COUNT do
		spawnCrow()
	end
end

function Crows.update(dt: number)
	timer += dt
	if timer < 0.2 then
		return
	end
	timer = 0
	local positions = {}
	for _, data in State.Participants do
		if data.Role == "Survivor" and data.Status == "Playing" and not data.Hidden then
			local root = State.getRoot(data.Player)
			if root then
				table.insert(positions, { root.Position, data.Player:GetAttribute("Running") == true })
			end
		end
	end
	for i = #crows, 1, -1 do
		local crow = crows[i]
		if not crow.Model.Parent then
			table.remove(crows, i)
			continue
		end
		for _, p in positions do
			local d = (p[1] - crow.Pos).Magnitude
			if d < 2.5 or (p[2] and d < 8) then
				table.remove(crows, i)
				flyAway(crow)
				break
			end
		end
	end
end

return Crows
