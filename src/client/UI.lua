-- Весь интерфейс игры, создаётся из кода.
local TweenService = game:GetService("TweenService")

local UI = {}

local FONT = Enum.Font.GothamBold
local FONT_REG = Enum.Font.Gotham

local function new(className, props, children)
	local inst = Instance.new(className)
	for k, v in props or {} do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function corner(radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 6) })
end

local function label(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or FONT
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	props.TextStrokeTransparency = props.TextStrokeTransparency or 0.5
	return new("TextLabel", props)
end

local function progressBar(parent, position, size)
	local bg = new("Frame", {
		Parent = parent,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = size,
		BackgroundColor3 = Color3.fromRGB(20, 20, 20),
		BackgroundTransparency = 0.25,
		Visible = false,
	}, { corner(4), new("UIStroke", { Color = Color3.fromRGB(200, 200, 200), Thickness = 1 }) })
	local fill = new("Frame", {
		Parent = bg,
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.fromRGB(230, 230, 230),
	}, { corner(4) })
	local text = label({
		Parent = bg,
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 0, -22),
		TextSize = 16,
	})
	return { Frame = bg, Fill = fill, Label = text }
end

function UI.new(playerGui)
	local self = {}

	local gui = new("ScreenGui", {
		Name = "DBDGui",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	self.Gui = gui

	-- Красная виньетка радиуса ужаса
	local vignette = new("Frame", {
		Parent = gui,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 0,
	})
	local edges = {}
	for _, data in
		{
			{ UDim2.fromScale(1, 0.25), UDim2.fromScale(0, 0), 90 },
			{ UDim2.fromScale(1, 0.25), UDim2.fromScale(0, 0.75), -90 },
			{ UDim2.fromScale(0.2, 1), UDim2.fromScale(0, 0), 0 },
			{ UDim2.fromScale(0.2, 1), UDim2.fromScale(0.8, 0), 180 },
		}
	do
		local f = new("Frame", {
			Parent = vignette,
			Size = data[1],
			Position = data[2],
			BackgroundColor3 = Color3.fromRGB(170, 0, 0),
			BorderSizePixel = 0,
			BackgroundTransparency = 1,
		}, {
			new("UIGradient", {
				Rotation = data[3],
				Transparency = NumberSequence.new(0, 1),
			}),
		})
		table.insert(edges, f)
	end

	-- Верхняя строка
	local top = label({
		Parent = gui,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 44),
		Size = UDim2.new(0.6, 0, 0, 32),
		TextSize = 24,
		Text = "",
	})
	local sub = label({
		Parent = gui,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 76),
		Size = UDim2.new(0.6, 0, 0, 22),
		TextSize = 18,
		TextColor3 = Color3.fromRGB(255, 120, 100),
		Text = "",
	})

	-- Уведомления
	local notifyHolder = new("Frame", {
		Parent = gui,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 108),
		Size = UDim2.new(0.7, 0, 0, 140),
		BackgroundTransparency = 1,
	}, {
		new("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 2),
		}),
	})
	local notifyOrder = 0

	-- Список выживших слева
	local list = new("Frame", {
		Parent = gui,
		Position = UDim2.new(0, 12, 0.3, 0),
		Size = UDim2.new(0, 230, 0, 200),
		BackgroundTransparency = 1,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local listRows = {}

	-- Подсказки действий
	local hintPrimary = label({
		Parent = gui,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -150),
		Size = UDim2.new(0.6, 0, 0, 26),
		TextSize = 20,
		Text = "",
	})
	local hintSecondary = label({
		Parent = gui,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -124),
		Size = UDim2.new(0.6, 0, 0, 26),
		TextSize = 20,
		Text = "",
	})

	local actionBar = progressBar(gui, UDim2.new(0.5, 0, 1, -90), UDim2.new(0, 320, 0, 16))
	local statusBar = progressBar(gui, UDim2.new(0.5, 0, 1, -200), UDim2.new(0, 320, 0, 12))
	statusBar.Fill.BackgroundColor3 = Color3.fromRGB(200, 40, 40)

	-- Проверка навыка
	local skill = new("Frame", {
		Parent = gui,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.new(0, 360, 0, 26),
		BackgroundColor3 = Color3.fromRGB(15, 15, 15),
		BackgroundTransparency = 0.2,
		Visible = false,
	}, { corner(4), new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2 }) })
	local skillZone = new("Frame", {
		Parent = skill,
		BackgroundColor3 = Color3.fromRGB(230, 230, 230),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
	})
	local skillGreat = new("Frame", {
		Parent = skill,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
	})
	local needle = new("Frame", {
		Parent = skill,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0, 4, 1, 10),
		BackgroundColor3 = Color3.fromRGB(255, 40, 40),
		BorderSizePixel = 0,
		ZIndex = 3,
	})
	label({
		Parent = skill,
		Position = UDim2.new(0, 0, 0, -28),
		Size = UDim2.new(1, 0, 0, 24),
		TextSize = 18,
		Text = "ПРОВЕРКА НАВЫКА — жми ПРОБЕЛ / кнопку",
	})

	-- Кнопка наблюдения
	local spectateButton = new("TextButton", {
		Parent = gui,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.new(0, 220, 0, 40),
		BackgroundColor3 = Color3.fromRGB(40, 40, 50),
		TextColor3 = Color3.new(1, 1, 1),
		Font = FONT,
		TextSize = 18,
		Text = "Наблюдать",
		Visible = false,
	}, { corner(8) })
	self.SpectateButton = spectateButton

	-- Итоги раунда
	local results = new("Frame", {
		Parent = gui,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 460, 0, 320),
		BackgroundColor3 = Color3.fromRGB(15, 10, 10),
		BackgroundTransparency = 0.1,
		Visible = false,
	}, { corner(10), new("UIStroke", { Color = Color3.fromRGB(150, 20, 20), Thickness = 2 }) })
	local resultsTitle = label({
		Parent = results,
		Position = UDim2.new(0, 0, 0, 12),
		Size = UDim2.new(1, 0, 0, 36),
		TextSize = 30,
		TextColor3 = Color3.fromRGB(255, 80, 80),
	})
	local resultsReason = label({
		Parent = results,
		Position = UDim2.new(0, 0, 0, 50),
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 16,
		Font = FONT_REG,
	})
	local resultsBody = label({
		Parent = results,
		Position = UDim2.new(0, 24, 0, 84),
		Size = UDim2.new(1, -48, 1, -100),
		TextSize = 18,
		Font = FONT_REG,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		RichText = true,
	})

	-- Подсказка управления (в лобби)
	local controls = label({
		Parent = gui,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -12),
		Size = UDim2.new(0, 330, 0, 120),
		TextSize = 14,
		Font = FONT_REG,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		TextTransparency = 0.2,
		Text = "",
	})

	--------------------------------------------------------------------

	function self.SetTop(text, subText)
		top.Text = text or ""
		sub.Text = subText or ""
	end

	function self.SetControls(text)
		controls.Text = text or ""
	end

	function self.Notify(text, color)
		notifyOrder += 1
		local l = label({
			Parent = notifyHolder,
			LayoutOrder = notifyOrder,
			Size = UDim2.new(1, 0, 0, 24),
			TextSize = 20,
			Text = text,
			TextColor3 = color or Color3.new(1, 1, 1),
		})
		local children = notifyHolder:GetChildren()
		local labels = {}
		for _, c in children do
			if c:IsA("TextLabel") then
				table.insert(labels, c)
			end
		end
		if #labels > 5 then
			table.sort(labels, function(a, b)
				return a.LayoutOrder < b.LayoutOrder
			end)
			labels[1]:Destroy()
		end
		task.delay(4, function()
			if l.Parent then
				local tw = TweenService:Create(l, TweenInfo.new(1), { TextTransparency = 1, TextStrokeTransparency = 1 })
				tw:Play()
				tw.Completed:Wait()
				l:Destroy()
			end
		end)
	end

	function self.SetHints(primary, secondary)
		hintPrimary.Text = primary or ""
		hintSecondary.Text = secondary or ""
	end

	function self.SetAction(text, fraction)
		if fraction then
			actionBar.Frame.Visible = true
			actionBar.Fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
			actionBar.Label.Text = text or ""
		else
			actionBar.Frame.Visible = false
		end
	end

	function self.SetStatus(text, fraction)
		if fraction then
			statusBar.Frame.Visible = true
			statusBar.Fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
			statusBar.Label.Text = text or ""
		else
			statusBar.Frame.Visible = false
		end
	end

	function self.SetSurvivors(rows)
		for i, row in rows do
			local l = listRows[i]
			if not l then
				l = label({
					Parent = list,
					LayoutOrder = i,
					Size = UDim2.new(1, 0, 0, 26),
					TextSize = 16,
					TextXAlignment = Enum.TextXAlignment.Left,
					BackgroundTransparency = 0.5,
					BackgroundColor3 = Color3.fromRGB(10, 10, 10),
				})
				new("UIPadding", { PaddingLeft = UDim.new(0, 8), Parent = l })
				corner(4).Parent = l
				listRows[i] = l
			end
			l.Visible = true
			l.Text = row.Text
			l.TextColor3 = row.Color
		end
		for i = #rows + 1, #listRows do
			listRows[i].Visible = false
		end
	end

	function self.SetTerror(intensity)
		for _, f in edges do
			f.BackgroundTransparency = 1 - math.clamp(intensity, 0, 1) * 0.75
		end
	end

	-- Запускает проверку навыка. onResult(result) вызывается один раз.
	local activeCheck
	function self.StartSkillCheck(zoneStart, duration, onResult)
		local zoneWidth = 0.13
		local greatWidth = 0.035
		skillGreat.Position = UDim2.fromScale(zoneStart, 0)
		skillGreat.Size = UDim2.fromScale(greatWidth, 1)
		skillZone.Position = UDim2.fromScale(zoneStart + greatWidth, 0)
		skillZone.Size = UDim2.fromScale(zoneWidth - greatWidth, 1)
		needle.Position = UDim2.fromScale(0, 0.5)
		skill.Visible = true
		local check = { Start = os.clock() + 0.6, Done = false }
		activeCheck = check
		local function finish(result)
			if check.Done then
				return
			end
			check.Done = true
			if activeCheck == check then
				activeCheck = nil
				skill.Visible = false
			end
			onResult(result)
		end
		function check.Position()
			return math.clamp((os.clock() - check.Start) / duration, 0, 1)
		end
		function check.Press()
			if os.clock() < check.Start then
				finish("fail")
				return
			end
			local p = check.Position()
			if p >= zoneStart and p < zoneStart + greatWidth then
				finish("great")
			elseif p >= zoneStart and p <= zoneStart + zoneWidth then
				finish("good")
			else
				finish("fail")
			end
		end
		function check.Update()
			needle.Position = UDim2.fromScale(check.Position(), 0.5)
			if os.clock() > check.Start + duration then
				finish("fail")
			end
		end
		check.Cancel = function()
			check.Done = true
			if activeCheck == check then
				activeCheck = nil
				skill.Visible = false
			end
		end
	end

	function self.GetSkillCheck()
		return activeCheck
	end

	function self.ShowResults(title, reason, rows, duration)
		resultsTitle.Text = title
		resultsReason.Text = reason or ""
		local lines = {}
		local statusText = {
			Escaped = '<font color="#6eff8c">сбежал</font>',
			Dead = '<font color="#ff5050">принесён в жертву</font>',
			Left = '<font color="#aaaaaa">вышел</font>',
			Playing = '<font color="#ffdc5a">выжил</font>',
			Hooked = '<font color="#ff5050">на крюке</font>',
			Carried = '<font color="#ff5050">в руках маньяка</font>',
		}
		for _, row in rows do
			local role = row.Role == "Killer" and "Маньяк" or "Выживший"
			local status = row.Role == "Killer" and "" or (" — " .. (statusText[row.Status] or row.Status))
			table.insert(lines, string.format("<b>%s</b> (%s)%s", row.Name, role, status))
		end
		resultsBody.Text = table.concat(lines, "\n")
		results.Visible = true
		task.delay(duration or 10, function()
			results.Visible = false
		end)
	end

	return self
end

return UI
