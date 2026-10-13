-- Меню лобби: очки крови, «хочу быть маньяком», выбор маньяка.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KillerDefs = require(ReplicatedStorage.Shared.KillerDefs)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Widgets = require(script.Parent.Widgets)

local new, label = Widgets.new, Widgets.label
local player = Players.LocalPlayer

local LobbyUI = {}

local panel: Frame
local bloodLabel: TextLabel
local wantButton: TextButton
local cards = {}

local function refresh()
	local want = player:GetAttribute("WantKiller") == true
	wantButton.Text = want and "Хочу быть маньяком: ДА" or "Хочу быть маньяком: НЕТ"
	wantButton.BackgroundColor3 = want and Color3.fromRGB(110, 20, 20) or Color3.fromRGB(35, 25, 25)
	local choice = player:GetAttribute("KillerChoice") or "Trapper"
	for id, card in cards do
		local selected = id == choice
		card.Stroke.Color = selected and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(80, 40, 40)
		card.Stroke.Thickness = selected and 2 or 1
		card.Frame.BackgroundTransparency = selected and 0.1 or 0.35
	end
	bloodLabel.Text = "Очки крови: " .. tostring(player:GetAttribute("Bloodpoints") or 0)
end

function LobbyUI.mount(gui: ScreenGui)
	panel = new("Frame", {
		Name = "Lobby",
		Parent = gui,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromOffset(300, 420),
		BackgroundColor3 = Widgets.DARK,
		BackgroundTransparency = 0.25,
		Visible = false,
	}, { Widgets.corner(8), Widgets.stroke(Widgets.RED, 1, 0.3) })
	label({
		Parent = panel,
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 0, 0, 40),
		Text = "DEAD BY DAYLIGHT",
		Font = Widgets.FONT_TITLE,
		TextSize = 34,
		TextColor3 = Color3.fromRGB(200, 25, 25),
	})
	bloodLabel = label({
		Parent = panel,
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 15,
		TextColor3 = Color3.fromRGB(255, 90, 90),
	})
	wantButton = Widgets.button({
		Parent = panel,
		Position = UDim2.fromOffset(16, 78),
		Size = UDim2.new(1, -32, 0, 36),
	})
	wantButton.Activated:Connect(function()
		Remotes.LobbyChoice:FireServer("WantKiller", not player:GetAttribute("WantKiller"))
	end)
	label({
		Parent = panel,
		Position = UDim2.fromOffset(16, 120),
		Size = UDim2.new(1, -32, 0, 20),
		Text = "Маньяк (если выпадет роль):",
		TextSize = 14,
		Font = Widgets.FONT_REG,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	for i, id in KillerDefs.Order do
		local def = KillerDefs[id]
		local stroke = Widgets.stroke(Color3.fromRGB(80, 40, 40), 1, 0)
		local frame = new("TextButton", {
			Parent = panel,
			Position = UDim2.fromOffset(16, 146 + (i - 1) * 88),
			Size = UDim2.new(1, -32, 0, 80),
			BackgroundColor3 = Color3.fromRGB(30, 18, 18),
			BackgroundTransparency = 0.35,
			Text = "",
			AutoButtonColor = true,
		}, { Widgets.corner(6), stroke })
		label({
			Parent = frame,
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.new(1, -20, 0, 22),
			Text = def.Name .. "  —  " .. def.PowerName,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		label({
			Parent = frame,
			Position = UDim2.fromOffset(10, 26),
			Size = UDim2.new(1, -20, 0, 50),
			Text = def.Description,
			TextSize = 12,
			Font = Widgets.FONT_REG,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = Color3.fromRGB(200, 200, 200),
		})
		frame.Activated:Connect(function()
			Remotes.LobbyChoice:FireServer("Killer", id)
		end)
		cards[id] = { Frame = frame, Stroke = stroke }
	end
	for _, attr in { "WantKiller", "KillerChoice", "Bloodpoints" } do
		player:GetAttributeChangedSignal(attr):Connect(refresh)
	end
	refresh()
end

function LobbyUI.setVisible(visible: boolean)
	panel.Visible = visible
end

return LobbyUI
