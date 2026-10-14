-- Основной интерфейс: генераторы, портреты выживших, подсказки, полоски,
-- способность/предмет, очки крови, уведомления, затемнения и эффекты экрана.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local KillerDefs = require(ReplicatedStorage.Shared.KillerDefs)
local ItemDefs = require(ReplicatedStorage.Shared.ItemDefs)
local Widgets = require(script.Parent.Widgets)
local SkillCheck = require(script.Parent.SkillCheck)

local new, label = Widgets.new, Widgets.label
local player = Players.LocalPlayer

local Hud = {}

local gui: ScreenGui
local edges = {}
local blindOverlay: Frame
local fadeOverlay: Frame
local fadeText: TextLabel
local genFrame: Frame
local genLabel: TextLabel
local genSub: TextLabel
local top: TextLabel
local topSub: TextLabel
local notifyHolder: Frame
local scoreHolder: Frame
local portraitHolder: Frame
local portraits = {}
local hintPrimary: TextLabel
local hintSecondary: TextLabel
local actionBar
local statusBar
local powerPanel: Frame
local powerTitle: TextLabel
local powerInfo: TextLabel
local powerBar
local controls: TextLabel
local notifyOrder = 0
local darkEdges = {}
local bloodEdges = {}
local flashOverlay: Frame
local fateText: TextLabel
local fateSub: TextLabel

-- Четыре рамки с градиентом от края экрана к центру (виньетка)
local function edgeFrames(color: Color3, thickness: number, zindex: number)
	local list = {}
	for _, data in
		{
			{ UDim2.fromScale(1, thickness), UDim2.fromScale(0, 0), 90 },
			{ UDim2.fromScale(1, thickness), UDim2.fromScale(0, 1 - thickness), -90 },
			{ UDim2.fromScale(thickness * 0.8, 1), UDim2.fromScale(0, 0), 0 },
			{ UDim2.fromScale(thickness * 0.8, 1), UDim2.fromScale(1 - thickness * 0.8, 0), 180 },
		}
	do
		table.insert(
			list,
			new("Frame", {
				Parent = gui,
				Size = data[1],
				Position = data[2],
				BackgroundColor3 = color,
				BorderSizePixel = 0,
				BackgroundTransparency = 1,
				ZIndex = zindex,
			}, { new("UIGradient", { Rotation = data[3], Transparency = NumberSequence.new(0, 1) }) })
		)
	end
	return list
end

function Hud.mount(playerGui: PlayerGui)
	gui = new("ScreenGui", {
		Name = "DBDHud",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	Hud.Gui = gui

	-- Тёмная виньетка (всегда) и кровь по краям (ранен / повержен / на крюке)
	darkEdges = edgeFrames(Color3.new(0, 0, 0), 0.3, 0)
	bloodEdges = edgeFrames(Color3.fromRGB(90, 0, 0), 0.26, 0)

	-- Красная виньетка радиуса ужаса
	for _, data in
		{
			{ UDim2.fromScale(1, 0.22), UDim2.fromScale(0, 0), 90 },
			{ UDim2.fromScale(1, 0.22), UDim2.fromScale(0, 0.78), -90 },
			{ UDim2.fromScale(0.18, 1), UDim2.fromScale(0, 0), 0 },
			{ UDim2.fromScale(0.18, 1), UDim2.fromScale(0.82, 0), 180 },
		}
	do
		table.insert(
			edges,
			new("Frame", {
				Parent = gui,
				Size = data[1],
				Position = data[2],
				BackgroundColor3 = Color3.fromRGB(150, 0, 0),
				BorderSizePixel = 0,
				BackgroundTransparency = 1,
				ZIndex = 0,
			}, { new("UIGradient", { Rotation = data[3], Transparency = NumberSequence.new(0, 1) }) })
		)
	end

	-- Счётчик генераторов (слева сверху)
	genFrame = new("Frame", {
		Parent = gui,
		Position = UDim2.fromOffset(16, 56),
		Size = UDim2.fromOffset(230, 64),
		BackgroundColor3 = Widgets.DARK,
		BackgroundTransparency = 0.35,
		Visible = false,
	}, { Widgets.corner(6), Widgets.stroke(Widgets.RED, 1, 0.4) })
	genLabel = label({
		Parent = genFrame,
		Position = UDim2.fromOffset(12, 4),
		Size = UDim2.new(1, -24, 0, 32),
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	})
	genSub = label({
		Parent = genFrame,
		Position = UDim2.fromOffset(12, 36),
		Size = UDim2.new(1, -24, 0, 22),
		TextSize = 14,
		Font = Widgets.FONT_REG,
		TextColor3 = Color3.fromRGB(255, 110, 90),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	})

	top = label({
		Parent = gui,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 48),
		Size = UDim2.new(0.6, 0, 0, 32),
		TextSize = 24,
		Text = "",
	})
	topSub = label({
		Parent = gui,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 80),
		Size = UDim2.new(0.6, 0, 0, 22),
		TextSize = 17,
		TextColor3 = Color3.fromRGB(255, 120, 100),
		Text = "",
	})

	notifyHolder = new("Frame", {
		Parent = gui,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 110),
		Size = UDim2.new(0.7, 0, 0, 160),
		BackgroundTransparency = 1,
	}, {
		new("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 2),
		}),
	})

	scoreHolder = new("Frame", {
		Parent = gui,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.42, 0),
		Size = UDim2.fromOffset(260, 200),
		BackgroundTransparency = 1,
	}, {
		new("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 2),
		}),
	})

	-- Портреты выживших (слева снизу)
	portraitHolder = new("Frame", {
		Parent = gui,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -20),
		Size = UDim2.fromOffset(250, 230),
		BackgroundTransparency = 1,
	}, {
		new("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 5),
		}),
	})

	hintPrimary = label({
		Parent = gui,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -150),
		Size = UDim2.new(0.6, 0, 0, 26),
		TextSize = 20,
		Text = "",
	})
	hintSecondary = label({
		Parent = gui,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -124),
		Size = UDim2.new(0.6, 0, 0, 26),
		TextSize = 20,
		Text = "",
	})
	actionBar = Widgets.bar(gui, UDim2.new(0.5, 0, 1, -92), UDim2.fromOffset(340, 14))
	statusBar = Widgets.bar(gui, UDim2.new(0.5, 0, 1, -200), UDim2.fromOffset(340, 10), Color3.fromRGB(200, 40, 40))

	-- Способность / предмет (справа снизу)
	powerPanel = new("Frame", {
		Parent = gui,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -20),
		Size = UDim2.fromOffset(260, 74),
		BackgroundColor3 = Widgets.DARK,
		BackgroundTransparency = 0.35,
		Visible = false,
	}, { Widgets.corner(6), Widgets.stroke(Widgets.RED, 1, 0.4) })
	powerTitle = label({
		Parent = powerPanel,
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 22),
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	powerInfo = label({
		Parent = powerPanel,
		Position = UDim2.fromOffset(12, 28),
		Size = UDim2.new(1, -24, 0, 18),
		TextSize = 13,
		Font = Widgets.FONT_REG,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(210, 210, 210),
	})
	powerBar = Widgets.bar(powerPanel, UDim2.new(0.5, 0, 1, -12), UDim2.new(1, -24, 0, 8), Color3.fromRGB(230, 200, 120))
	powerBar.Label.Visible = false

	controls = label({
		Parent = gui,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -104),
		Size = UDim2.fromOffset(360, 110),
		TextSize = 13,
		Font = Widgets.FONT_REG,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		TextTransparency = 0.25,
		Text = "",
	})

	-- Белая вспышка (ослепление) и затемнение (начало раунда)
	blindOverlay = new("Frame", {
		Parent = gui,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		ZIndex = 20,
	})
	flashOverlay = new("Frame", {
		Parent = gui,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 25,
	})
	fateText = label({
		Parent = gui,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.new(0.9, 0, 0, 90),
		TextSize = 64,
		Font = Widgets.FONT_TITLE,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		ZIndex = 26,
		Text = "",
	})
	fateSub = label({
		Parent = gui,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.new(0.9, 0, 0, 30),
		TextSize = 22,
		Font = Widgets.FONT_REG,
		TextColor3 = Color3.fromRGB(200, 190, 190),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		ZIndex = 26,
		Text = "",
	})
	fadeOverlay = new("Frame", {
		Parent = gui,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 30,
	})
	fadeText = label({
		Parent = fadeOverlay,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.8, 0, 0, 240),
		TextSize = 48,
		Font = Widgets.FONT_TITLE,
		TextColor3 = Color3.fromRGB(200, 30, 30),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		ZIndex = 31,
	})

	SkillCheck.mount(gui)
end

------------------------------------------------------------------------

function Hud.setTop(text: string?, sub: string?)
	top.Text = text or ""
	topSub.Text = sub or ""
end

function Hud.setGenerators(visible: boolean, text: string?, sub: string?)
	genFrame.Visible = visible
	genLabel.Text = text or ""
	genSub.Text = sub or ""
end

function Hud.setControls(text: string)
	controls.Text = text
end

function Hud.notify(text: string, color: Color3?)
	notifyOrder += 1
	local l = label({
		Parent = notifyHolder,
		LayoutOrder = notifyOrder,
		Size = UDim2.new(1, 0, 0, 24),
		TextSize = 20,
		Text = text,
		TextColor3 = color or Color3.new(1, 1, 1),
	})
	local labels = {}
	for _, c in notifyHolder:GetChildren() do
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
	task.delay(4.5, function()
		if l.Parent then
			local tw = TweenService:Create(l, TweenInfo.new(1), { TextTransparency = 1, TextStrokeTransparency = 1 })
			tw:Play()
			tw.Completed:Wait()
			l:Destroy()
		end
	end)
end

function Hud.score(text: string, amount: number)
	notifyOrder += 1
	local l = label({
		Parent = scoreHolder,
		LayoutOrder = notifyOrder,
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Right,
		RichText = true,
		Text = string.format('<font color="#ff4d4d">+%d</font>  %s', amount, text),
	})
	task.delay(3, function()
		if l.Parent then
			local tw = TweenService:Create(l, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 })
			tw:Play()
			tw.Completed:Wait()
			l:Destroy()
		end
	end)
end

function Hud.setHints(primary: string?, secondary: string?)
	hintPrimary.Text = primary or ""
	hintSecondary.Text = secondary or ""
end

function Hud.setAction(text: string?, fraction: number?)
	Widgets.setBar(actionBar, text, fraction)
end

function Hud.setStatus(text: string?, fraction: number?)
	Widgets.setBar(statusBar, text, fraction)
end

function Hud.setTerror(intensity: number)
	for _, f in edges do
		f.BackgroundTransparency = 1 - math.clamp(intensity, 0, 1) * 0.75
	end
end

-- Чёрные края экрана: 0 — нет, 1 — почти ничего не видно по краям
function Hud.setDarkness(amount: number)
	local tr = 1 - math.clamp(amount, 0, 1) * 0.95
	for _, f in darkEdges do
		f.BackgroundTransparency = tr
	end
end

-- Кровь по краям экрана; pulse — пульсирует в такт сердцу
function Hud.setBlood(amount: number, pulse: boolean?)
	local a = math.clamp(amount, 0, 1)
	if pulse and a > 0 then
		a *= 0.75 + 0.25 * math.abs(math.sin(os.clock() * 2.4))
	end
	for _, f in bloodEdges do
		f.BackgroundTransparency = 1 - a
	end
end

-- Короткая вспышка цветом на весь экран (удар, скример)
function Hud.flash(color: Color3, strength: number)
	flashOverlay.BackgroundColor3 = color
	flashOverlay.BackgroundTransparency = 1 - math.clamp(strength, 0, 1)
	TweenService:Create(flashOverlay, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()
end

-- Большая надпись о судьбе игрока («ТЫ ПРИНЕСЁН В ЖЕРТВУ»)
function Hud.fate(text: string, sub: string?, color: Color3?)
	fateText.Text = text
	fateText.TextColor3 = color or Color3.fromRGB(200, 20, 20)
	fateSub.Text = sub or ""
	for _, l in { fateText, fateSub } do
		l.TextTransparency = 1
		l.TextStrokeTransparency = 1
		TweenService:Create(l, TweenInfo.new(1.2), { TextTransparency = 0, TextStrokeTransparency = 0.4 }):Play()
	end
	task.delay(4.5, function()
		for _, l in { fateText, fateSub } do
			TweenService:Create(l, TweenInfo.new(2), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

------------------------------------------------------------------------
-- Портреты выживших
------------------------------------------------------------------------

local STATE_INFO = {
	Healthy = { "ЗДОРОВ", Color3.fromRGB(220, 220, 220) },
	Injured = { "РАНЕН", Color3.fromRGB(255, 160, 60) },
	Downed = { "ПОВЕРЖЕН", Color3.fromRGB(255, 70, 70) },
	Carried = { "НЕСУТ", Color3.fromRGB(255, 70, 70) },
	Hooked = { "НА КРЮКЕ", Color3.fromRGB(255, 40, 40) },
	Trapped = { "В КАПКАНЕ", Color3.fromRGB(255, 120, 60) },
	Dead = { "ПОГИБ", Color3.fromRGB(110, 110, 110) },
	Left = { "ВЫШЕЛ", Color3.fromRGB(110, 110, 110) },
	Escaped = { "СБЕЖАЛ", Color3.fromRGB(110, 255, 140) },
}

local function stateKey(p: Player): string
	local status = p:GetAttribute("Status") or "Playing"
	if status ~= "Playing" then
		return status
	end
	if p:GetAttribute("Trapped") then
		return "Trapped"
	end
	local h = p:GetAttribute("Health") or 2
	return h == 2 and "Healthy" or (h == 1 and "Injured" or "Downed")
end

local function makePortrait(index: number)
	local frame = new("Frame", {
		Parent = portraitHolder,
		LayoutOrder = index,
		Size = UDim2.fromOffset(250, 42),
		BackgroundColor3 = Widgets.DARK,
		BackgroundTransparency = 0.3,
	}, { Widgets.corner(5) })
	local stripe = new("Frame", {
		Parent = frame,
		Size = UDim2.new(0, 5, 1, 0),
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
	})
	local name = label({
		Parent = frame,
		Position = UDim2.fromOffset(14, 2),
		Size = UDim2.new(1, -60, 0, 20),
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local state = label({
		Parent = frame,
		Position = UDim2.fromOffset(14, 21),
		Size = UDim2.new(1, -60, 0, 18),
		TextSize = 12,
		Font = Widgets.FONT_REG,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local pips = {}
	for i = 1, 2 do
		table.insert(
			pips,
			new("Frame", {
				Parent = frame,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10 - (2 - i) * 18, 0.5, 0),
				Size = UDim2.fromOffset(12, 12),
				Rotation = 45,
				BorderSizePixel = 0,
				BackgroundColor3 = Color3.fromRGB(60, 60, 60),
			})
		)
	end
	local bar = new("Frame", {
		Parent = frame,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 5, 1, 0),
		Size = UDim2.new(0, 0, 0, 3),
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.fromRGB(220, 40, 40),
	})
	return { Frame = frame, Stripe = stripe, Name = name, State = state, Pips = pips, Bar = bar }
end

function Hud.updatePortraits(visible: boolean)
	local list = {}
	if visible then
		for _, p in Players:GetPlayers() do
			if p:GetAttribute("Role") == "Survivor" then
				table.insert(list, p)
			end
		end
		table.sort(list, function(a, b)
			return a.UserId < b.UserId
		end)
	end
	for i, p in list do
		local row = portraits[i] or makePortrait(i)
		portraits[i] = row
		row.Frame.Visible = true
		local key = stateKey(p)
		local info = STATE_INFO[key] or STATE_INFO.Healthy
		row.Name.Text = p.DisplayName .. (p == player and " (ты)" or "")
		local item = p:GetAttribute("Item")
		row.State.Text = info[1] .. (item and ("  •  " .. ItemDefs[item].Name) or "")
		row.State.TextColor3 = info[2]
		row.Stripe.BackgroundColor3 = info[2]
		local hooks = p:GetAttribute("HookCount") or 0
		for j, pip in row.Pips do
			pip.BackgroundColor3 = hooks >= j and Color3.fromRGB(220, 30, 30) or Color3.fromRGB(60, 60, 60)
		end
		local f = p:GetAttribute("HookProgress") or p:GetAttribute("BleedOut")
		row.Bar.Size = UDim2.new(f and (1 - f) or 0, -5, 0, 3)
	end
	for i = #list + 1, #portraits do
		portraits[i].Frame.Visible = false
	end
end

------------------------------------------------------------------------
-- Способность маньяка / предмет выжившего
------------------------------------------------------------------------

function Hud.updatePower()
	local role = player:GetAttribute("Role")
	if role == "Killer" then
		local def = KillerDefs.get(player:GetAttribute("KillerType"))
		powerPanel.Visible = true
		powerTitle.Text = def.Name .. " — " .. def.PowerName
		local count = player:GetAttribute("PowerCount")
		if def.Id == "Trapper" then
			powerInfo.Text = string.format("Капканы в руках: %d   •   %s", count or 0, def.PowerHint)
			Widgets.setBar(powerBar, nil, nil)
		elseif def.Id == "Huntress" then
			powerInfo.Text = string.format("Топоры: %d/%d   •   %s", count or 0, def.MaxHatchets, "ПКМ/Q")
			local charge = player:GetAttribute("PowerCharge") or 0
			Widgets.setBar(powerBar, nil, charge > 0 and charge or nil)
		else
			local state = player:GetAttribute("PowerState") or "Visible"
			local names = { Visible = "видим", Cloaking = "звонит в колокол...", Uncloaking = "проявляется...", Cloaked = "НЕВИДИМ" }
			powerInfo.Text = "Состояние: " .. (names[state] or state) .. "   •   ПКМ/Q"
			Widgets.setBar(powerBar, nil, nil)
		end
	elseif role == "Survivor" and player:GetAttribute("Item") then
		local item = player:GetAttribute("Item")
		local def = ItemDefs[item]
		powerPanel.Visible = true
		powerTitle.Text = def.Name
		powerInfo.Text = def.Hint
		local max = player:GetAttribute("ItemMax") or 1
		Widgets.setBar(powerBar, nil, (player:GetAttribute("ItemCharges") or 0) / max)
	else
		powerPanel.Visible = false
	end
end

------------------------------------------------------------------------
-- Эффекты экрана
------------------------------------------------------------------------

function Hud.blind(duration: number)
	blindOverlay.BackgroundTransparency = 0
	TweenService:Create(blindOverlay, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 1,
	}):Play()
end

function Hud.intro(text: string, sub: string?, quote: string?)
	fadeOverlay.BackgroundTransparency = 0
	fadeText.RichText = true
	fadeText.Text = text
		.. (sub and ("\n" .. sub) or "")
		.. (quote and ('\n<font size="22" color="#8c8c8c"><i>' .. quote .. "</i></font>") or "")
	fadeText.TextTransparency = 1
	TweenService:Create(fadeText, TweenInfo.new(0.8), { TextTransparency = 0 }):Play()
	task.delay(2.6, function()
		TweenService:Create(fadeOverlay, TweenInfo.new(2.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			BackgroundTransparency = 1,
		}):Play()
		TweenService:Create(fadeText, TweenInfo.new(1.5), { TextTransparency = 1 }):Play()
	end)
end

return Hud
