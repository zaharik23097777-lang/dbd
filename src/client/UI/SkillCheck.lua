-- Круглая проверка навыка, как в Dead by Daylight.
-- Кольцо — круг с обводкой, зона — дуга из маленьких повёрнутых квадратиков,
-- стрелка — повёрнутая полоска. Положения считаются через тригонометрию.
local Widgets = require(script.Parent.Widgets)
local new = Widgets.new

local SkillCheck = {}

local SIZE = 170
local RADIUS = 70

export type Check = {
	Press: () -> (),
	Update: () -> (),
	Cancel: () -> (),
	Done: boolean,
}

local root: Frame
local zoneHolder: Frame
local needle: Frame
local active: Check? = nil

local function pointOnCircle(angleDeg: number, r: number): UDim2
	local a = math.rad(angleDeg)
	return UDim2.new(0.5, math.sin(a) * r, 0.5, -math.cos(a) * r)
end

function SkillCheck.mount(parent: Instance)
	root = new("Frame", {
		Name = "SkillCheck",
		Parent = parent,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromOffset(SIZE, SIZE),
		BackgroundTransparency = 1,
		Visible = false,
	})
	new("Frame", {
		Parent = root,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(RADIUS * 2, RADIUS * 2),
		BackgroundTransparency = 1,
	}, { Widgets.corner(RADIUS), Widgets.stroke(Color3.new(1, 1, 1), 3, 0.1) })
	Widgets.label({
		Parent = root,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(80, 30),
		Text = "ПРОБЕЛ",
		TextSize = 14,
		TextTransparency = 0.2,
	})
	zoneHolder = new("Frame", { Parent = root, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	needle = new("Frame", {
		Parent = root,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(4, RADIUS + 8),
		BackgroundColor3 = Color3.fromRGB(255, 40, 40),
		BorderSizePixel = 0,
		ZIndex = 5,
	})
end

local function drawZone(startDeg: number, endDeg: number, color: Color3, thickness: number)
	local a = startDeg
	while a <= endDeg do
		new("Frame", {
			Parent = zoneHolder,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = pointOnCircle(a, RADIUS),
			Size = UDim2.fromOffset(4, thickness),
			Rotation = a,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = 3,
		})
		a += 2
	end
end

local function setNeedle(angleDeg: number)
	needle.Position = pointOnCircle(angleDeg, (RADIUS + 8) / 2)
	needle.Rotation = angleDeg
end

-- zoneStart (0..1) от сервера, duration — время полного оборота
function SkillCheck.start(zoneStart: number, duration: number, onResult: (string) -> ()): Check
	if active then
		active.Cancel()
	end
	zoneHolder:ClearAllChildren()
	local GREAT = 0.035
	local ZONE = 0.13
	drawZone(zoneStart * 360, (zoneStart + GREAT) * 360, Color3.new(1, 1, 1), 14)
	drawZone((zoneStart + GREAT) * 360, (zoneStart + ZONE) * 360, Color3.fromRGB(200, 200, 200), 8)
	setNeedle(0)
	root.Visible = true

	local startAt = os.clock() + 0.55
	local check: Check
	local function finish(result: string)
		if check.Done then
			return
		end
		check.Done = true
		if active == check then
			active = nil
			root.Visible = false
		end
		onResult(result)
	end
	local function position(): number
		return math.clamp((os.clock() - startAt) / duration, 0, 1)
	end
	check = {
		Done = false,
		Press = function()
			if os.clock() < startAt then
				finish("fail")
				return
			end
			local p = position()
			if p >= zoneStart and p < zoneStart + GREAT then
				finish("great")
			elseif p >= zoneStart and p <= zoneStart + ZONE then
				finish("good")
			else
				finish("fail")
			end
		end,
		Update = function()
			setNeedle(position() * 360)
			if os.clock() > startAt + duration then
				finish("fail")
			end
		end,
		Cancel = function()
			check.Done = true
			if active == check then
				active = nil
				root.Visible = false
			end
		end,
	}
	active = check
	return check
end

function SkillCheck.get(): Check?
	return active
end

return SkillCheck
