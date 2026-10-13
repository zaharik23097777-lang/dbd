-- Ауры (подсветка сквозь стены), как в DBD.
-- Выжившие видят висящих/поверженных товарищей и запитанные ворота.
-- Маньяк видит генераторы, а когда несёт выжившего — свободные крюки.
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local Auras = {}

local auras = {} :: { [Instance]: Highlight }

local RED = Color3.fromRGB(255, 50, 50)
local YELLOW = Color3.fromRGB(255, 220, 90)
local WHITE = Color3.fromRGB(235, 235, 235)

local function children(name: string): { Instance }
	local map = workspace:FindFirstChild("Map")
	local f = map and map:FindFirstChild(name)
	return f and f:GetChildren() or {}
end

function Auras.update()
	local wanted = {} :: { [Instance]: Color3 }
	local role = player:GetAttribute("Role")
	local status = player:GetAttribute("Status")
	local inGame = status == "Playing" or status == "Carried" or status == "Hooked"
	if role == "Survivor" and inGame then
		for _, p in Players:GetPlayers() do
			if p ~= player and p:GetAttribute("Role") == "Survivor" and p.Character then
				local s = p:GetAttribute("Status")
				if s == "Hooked" or (s == "Playing" and p:GetAttribute("Health") == 0 and not p:GetAttribute("Hidden")) then
					wanted[p.Character] = RED
				end
			end
		end
		for _, gate in children("ExitGates") do
			if gate:GetAttribute("Powered") and not gate:GetAttribute("Open") then
				wanted[gate] = YELLOW
			end
		end
	elseif role == "Killer" and status == "Playing" then
		if player:GetAttribute("Carrying") then
			for _, hook in children("Hooks") do
				if hook:GetAttribute("Occupant") == 0 then
					wanted[hook] = WHITE
				end
			end
		end
		for _, gen in children("Generators") do
			if not gen:GetAttribute("Done") then
				wanted[gen] = WHITE
			end
		end
	end

	for inst, h in auras do
		if not wanted[inst] or not inst.Parent then
			h:Destroy()
			auras[inst] = nil
		end
	end
	for inst, color in wanted do
		local h = auras[inst]
		if not h then
			h = Instance.new("Highlight")
			h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			h.FillTransparency = 0.85
			h.OutlineTransparency = 0.1
			h.Adornee = inst
			h.Parent = camera
			auras[inst] = h
		end
		h.OutlineColor = color
		h.FillColor = color
	end
end

return Auras
