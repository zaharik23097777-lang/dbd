-- Собирает интерфейс на настоящей базе свойств Roblox (Lune проверяет имена свойств и типы).
local Harness = require("./harness")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

-- Фейковый локальный игрок для клиентских модулей
local attrs = { WantKiller = false, KillerChoice = "Trapper", Bloodpoints = 1234 }
local fakePlayer = {
	UserId = 1,
	DisplayName = "Tester",
	GetAttribute = function(_, k)
		return attrs[k]
	end,
	GetAttributeChangedSignal = function()
		return { Connect = function() end }
	end,
}
Harness.STUBS.Players = {
	LocalPlayer = fakePlayer,
	GetPlayers = function()
		return { fakePlayer }
	end,
}
local game, req = Harness.load(process.args[1] or "DeadByDaylight.rbxlx")
local Client = game.StarterPlayer.StarterPlayerScripts.Client
local Hud = req(Client.UI.Hud)
local SkillCheck = req(Client.UI.SkillCheck)
local Results = req(Client.UI.Results)

local fakeGui = roblox.Instance.new("Folder")
Hud.mount(fakeGui)
Results.mount(Hud.Gui)
Hud.updatePower()
attrs.Role = "Killer"
for _, killer in { "Trapper", "Huntress", "Wraith" } do
	attrs.KillerType = killer
	attrs.PowerCount = 2
	attrs.PowerCharge = 0.5
	attrs.PowerState = "Cloaked"
	Hud.updatePower()
end
attrs.Role = "Survivor"
attrs.Status = "Hooked"
attrs.HookCount = 1
attrs.HookProgress = 0.4
Hud.updatePortraits(true)
attrs.Status = "Playing"
attrs.Health = 0
attrs.HookProgress = nil
attrs.BleedOut = 0.2
Hud.updatePortraits(true)
for _, item in { "Medkit", "Toolbox", "Flashlight" } do
	attrs.Item = item
	attrs.ItemCharges = 5
	attrs.ItemMax = 10
	Hud.updatePower()
end

Hud.setTop("a", "b")
Hud.setGenerators(true, "Генераторы: 5", "x")
Hud.setHints("[E] test", "[Пробел] test")
Hud.setAction("Ремонт", 0.5)
Hud.setStatus("x", 0.3)
Hud.setTerror(0.5)
Hud.notify("hello", nil)
Hud.score("Удар", 300)
Hud.blind(1)
Hud.intro("Ты — Траппер", "x")
local check = SkillCheck.start(0.6, 1.1, function() end)
check.Update()
check.Press()
Results.show("Победа", "", {
	{ Name = "A", Role = "Killer", KillerType = "Huntress", Status = "Playing", Total = 1000, Score = { { Name = "Охота", Value = 1000 } } },
	{ Name = "B", Role = "Survivor", Status = "Escaped", Total = 7000, Score = { { Name = "Цели", Value = 1250 } } },
}, 0.01)

local count = 0
for _, d in Hud.Gui:GetDescendants() do
	count += 1
end
print(("ui instances: %d"):format(count))
print("ui tests OK")
