-- Экран итогов раунда с очками крови по категориям.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KillerDefs = require(ReplicatedStorage.Shared.KillerDefs)
local Widgets = require(script.Parent.Widgets)

local new, label = Widgets.new, Widgets.label

local Results = {}

local panel: Frame
local title: TextLabel
local reason: TextLabel
local list: Frame

local STATUS_TEXT = {
	Escaped = '<font color="#6eff8c">сбежал</font>',
	Dead = '<font color="#ff5050">принесён в жертву</font>',
	Left = '<font color="#aaaaaa">вышел</font>',
	Playing = '<font color="#ffdc5a">выжил</font>',
	Hooked = '<font color="#ff5050">на крюке</font>',
	Carried = '<font color="#ff5050">в руках маньяка</font>',
}

function Results.mount(gui: ScreenGui)
	panel = new("Frame", {
		Name = "Results",
		Parent = gui,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(620, 420),
		BackgroundColor3 = Color3.fromRGB(12, 8, 8),
		BackgroundTransparency = 0.08,
		Visible = false,
		ZIndex = 10,
	}, { Widgets.corner(10), Widgets.stroke(Color3.fromRGB(150, 20, 20), 2, 0) })
	title = label({
		Parent = panel,
		Position = UDim2.fromOffset(0, 10),
		Size = UDim2.new(1, 0, 0, 44),
		TextSize = 40,
		Font = Widgets.FONT_TITLE,
		TextColor3 = Color3.fromRGB(230, 50, 50),
		ZIndex = 11,
	})
	reason = label({
		Parent = panel,
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 15,
		Font = Widgets.FONT_REG,
		ZIndex = 11,
	})
	list = new("ScrollingFrame", {
		Parent = panel,
		Position = UDim2.fromOffset(16, 84),
		Size = UDim2.new(1, -32, 1, -100),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 11,
	}, { new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
end

function Results.show(titleText: string, reasonText: string, rows, duration: number)
	title.Text = titleText
	reason.Text = reasonText
	for _, c in list:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	for i, row in rows do
		local frame = new("Frame", {
			Parent = list,
			LayoutOrder = i,
			Size = UDim2.new(1, -6, 0, 58),
			BackgroundColor3 = row.Role == "Killer" and Color3.fromRGB(45, 12, 12) or Color3.fromRGB(28, 24, 24),
			BackgroundTransparency = 0.2,
			ZIndex = 11,
		}, { Widgets.corner(6) })
		local role = row.Role == "Killer" and ("Маньяк: " .. KillerDefs.get(row.KillerType).Name) or "Выживший"
		local status = row.Role == "Killer" and "" or ("  —  " .. (STATUS_TEXT[row.Status] or row.Status))
		label({
			Parent = frame,
			Position = UDim2.fromOffset(12, 4),
			Size = UDim2.new(0.7, 0, 0, 22),
			RichText = true,
			Text = string.format("<b>%s</b>  (%s)%s", row.Name, role, status),
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 12,
		})
		label({
			Parent = frame,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 4),
			Size = UDim2.new(0.3, 0, 0, 22),
			Text = tostring(row.Total) .. " очков",
			TextSize = 16,
			TextColor3 = Color3.fromRGB(255, 80, 80),
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 12,
		})
		local parts = {}
		for _, s in row.Score or {} do
			table.insert(parts, s.Name .. ": " .. s.Value)
		end
		label({
			Parent = frame,
			Position = UDim2.fromOffset(12, 30),
			Size = UDim2.new(1, -24, 0, 20),
			Text = table.concat(parts, "   •   "),
			TextSize = 13,
			Font = Widgets.FONT_REG,
			TextColor3 = Color3.fromRGB(200, 200, 200),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 12,
		})
	end
	panel.Visible = true
	task.delay(duration, function()
		panel.Visible = false
	end)
end

return Results
