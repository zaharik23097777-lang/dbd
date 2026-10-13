-- Маленькие помощники для создания интерфейса из кода.
local Widgets = {}

Widgets.FONT = Enum.Font.GothamBold
Widgets.FONT_REG = Enum.Font.Gotham
Widgets.FONT_TITLE = Enum.Font.Creepster
Widgets.RED = Color3.fromRGB(190, 25, 25)
Widgets.DARK = Color3.fromRGB(14, 10, 10)

function Widgets.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent
	if props then
		for k, v in props do
			if k == "Parent" then
				parent = v
			else
				(inst :: any)[k] = v
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end
local new = Widgets.new

function Widgets.corner(radius: number?): UICorner
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 6) })
end

function Widgets.stroke(color: Color3?, thickness: number?, transparency: number?): UIStroke
	return new("UIStroke", {
		Color = color or Color3.fromRGB(200, 200, 200),
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Widgets.label(props: { [string]: any }): TextLabel
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or Widgets.FONT
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	props.TextStrokeTransparency = props.TextStrokeTransparency or 0.6
	return new("TextLabel", props)
end

export type Bar = { Frame: Frame, Fill: Frame, Label: TextLabel }

function Widgets.bar(parent: Instance, position: UDim2, size: UDim2, color: Color3?): Bar
	local bg = new("Frame", {
		Parent = parent,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = size,
		BackgroundColor3 = Color3.fromRGB(15, 15, 15),
		BackgroundTransparency = 0.2,
		Visible = false,
	}, { Widgets.corner(3), Widgets.stroke(Color3.fromRGB(180, 180, 180), 1, 0.3) })
	local fill = new("Frame", {
		Parent = bg,
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = color or Color3.fromRGB(230, 230, 230),
		BorderSizePixel = 0,
	}, { Widgets.corner(3) })
	local text = Widgets.label({
		Parent = bg,
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 0, -22),
		TextSize = 16,
	})
	return { Frame = bg, Fill = fill, Label = text }
end

function Widgets.setBar(bar: Bar, text: string?, fraction: number?)
	if fraction then
		bar.Frame.Visible = true
		bar.Fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
		bar.Label.Text = text or ""
	else
		bar.Frame.Visible = false
	end
end

function Widgets.button(props: { [string]: any }): TextButton
	props.BackgroundColor3 = props.BackgroundColor3 or Color3.fromRGB(35, 25, 25)
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	props.Font = props.Font or Widgets.FONT
	props.TextSize = props.TextSize or 16
	props.AutoButtonColor = true
	local b = new("TextButton", props, { Widgets.corner(6), Widgets.stroke(Widgets.RED, 1, 0.3) })
	return b
end

return Widgets
