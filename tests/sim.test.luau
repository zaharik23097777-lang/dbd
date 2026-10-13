--!nocheck
-- Полная симуляция серверной логики в эмуляторе: лобби -> матч -> все механики -> итоги.
local Fake = require("./fakeroblox")
local process = require("@lune/process")

local W = Fake.newWorld(process.args[1] or "DeadByDaylight.rbxlx")
local V3, CF = Fake.Vector3, Fake.CFrame
local Sched = Fake.Sched
local game = W.Game
local SSS = W:service("ServerScriptService")
local RS = W:service("ReplicatedStorage")

local failures = 0
local function check(cond, msg)
	if not cond then
		failures += 1
		print("FAIL: " .. msg)
	end
end

local function errorsOk(stage)
	if #Sched.Errors > 0 then
		print("ERRORS during " .. stage .. ":")
		for _, e in Sched.Errors do
			print("  " .. e)
		end
		failures += #Sched.Errors
		table.clear(Sched.Errors)
		return false
	end
	return true
end

-- Автоответ на проверки навыка (как будто клиент нажал вовремя)
W.RemoteHooks = {
	SkillCheck = function(target, id)
		Fake.Sched.Queue[#Fake.Sched.Queue + 1] = {
			At = Sched.Time + 0.4,
			Fn = function()
				RS.Remotes.SkillCheck.OnServerEvent:Fire(target, id, "great")
			end,
			Args = table.pack(),
		}
	end,
}

-- Запуск сервера
W:run(SSS.Server.Main)
errorsOk("server start")
local State = W:require(SSS.Server.Core.State)
local Items = W:require(SSS.Server.Systems.Items)
local Config = W:require(RS.Shared.Config)

local function fire(p, remote, ...)
	RS.Remotes[remote].OnServerEvent:Fire(p, ...)
end
local function data(p)
	return State.Participants[p]
end
local function root(p)
	return p.Character and p.Character:FindFirstChild("HumanoidRootPart")
end
-- Переносит персонажа целиком (в эмуляторе детали не сварены между собой)
local function place(p, pos, look)
	local r = root(p)
	r.Anchored = false
	local target = CF.lookAt(pos, look or (pos + V3.new(0, 0, -1)))
	p.Character:PivotTo(target)
end
local function flat(v)
	return V3.new(v.X, 0, v.Z)
end

local P1 = W:addPlayer("Killer", 1)
local P2 = W:addPlayer("Alice", 2)
local P3 = W:addPlayer("Bob", 3)

-- Клиент за Alice: настоящий Client.client.lua в том же мире
local Players = W:service("Players")
local gui = Fake.Instance.new("PlayerGui")
gui.Name = "PlayerGui"
gui.Parent = P2
Players.LocalPlayer = P2
W.LocalPlayer = P2
W:run(W:service("StarterPlayer").StarterPlayerScripts.Client.Client)
errorsOk("client start")
local Enum = require("@lune/roblox").Enum
local KEY = { UserInputType = Enum.UserInputType.Keyboard }
local function press(action, state)
	local a = W.Actions[action]
	assert(a, "action not bound: " .. action)
	Fake.Sched.Queue[#Fake.Sched.Queue + 1] = {
		At = Sched.Time,
		Fn = a.Fn,
		Args = table.pack(action, state or Enum.UserInputState.Begin, KEY),
	}
	Sched.advance(0)
end
local camera = W:service("Workspace").CurrentCamera

W:step(1)
errorsOk("join")
check(camera.CameraSubject == P2.Character:FindFirstChildOfClass("Humanoid"), "camera follows own character in lobby")
check(W:service("Players").LocalPlayer.CameraMinZoomDistance >= 6, "lobby zoom not first person")
for _, p in { P1, P2, P3 } do
	check(root(p) ~= nil, p.Name .. " has lobby character")
	check(p.Character:FindFirstChild("Animate") == nil, "Animate removed")
	check(p:GetAttribute("Bloodpoints") == 0, "bloodpoints loaded")
end
check(W.Groups.DBDLimbs and W.Groups.DBDLimbs.Default == false, "limbs group non-colliding")

------------------------------------------------------------------------
print("== Раунд 1: Траппер")
fire(P1, "LobbyChoice", "WantKiller", true)
fire(P1, "LobbyChoice", "Killer", "Trapper")
W:step(Config.LobbyCountdown + 2)
errorsOk("round 1 start")
check(State.Active, "match active")
check(data(P1) and data(P1).Role == "Killer", "P1 is killer")
check(data(P2) and data(P2).Role == "Survivor", "P2 survivor")
check(P1.Character:GetAttribute("KillerType") == "Trapper", "killer char tagged")
check(#State.Map.Traps:GetChildren() == 4, "trapper traps placed: " .. #State.Map.Traps:GetChildren())
check(State.GameState:GetAttribute("Phase") == "InGame", "phase InGame")
local spawnPos = State.Map.SurvivorSpawn

-- Ремонт
local gen = State.Map.Generators:GetChildren()[1]
local body = gen.PrimaryPart
place(P2, body.Position + V3.new(0, 1, -2.6), body.Position)
W:step(0.1)
check(W.Actions.DBDInteract ~= nil, "survivor controls bound")
check(W.Actions.DBDSprint ~= nil, "sprint bound")
press("DBDInteract") -- клиент сам выбирает ближайшее действие (Repair)
W:step(3)
errorsOk("repair")
check(gen:GetAttribute("Progress") > 0.03, "gen progress " .. tostring(gen:GetAttribute("Progress")))
check(P2:GetAttribute("ActionName") == "Repair", "action attr")
gen:SetAttribute("Progress", 0.995)
W:step(1)
check(gen:GetAttribute("Done") == true, "gen done")
check(State.GensDone == 1, "gens done 1")
check(P2:GetAttribute("ActionName") == nil, "action cleared after done")
press("DBDInteract", Enum.UserInputState.End)

-- Атака
place(P2, spawnPos, spawnPos + V3.new(0, 0, 10))
place(P1, spawnPos + V3.new(0, 0.45, -3), spawnPos)
place(P3, spawnPos + V3.new(30, 0, 0)) -- второй выживший далеко
fire(P1, "Attack")
W:step(0.5)
errorsOk("attack")
check(data(P2).Health == 1, "P2 injured, health=" .. data(P2).Health)
W:step(3)
fire(P1, "Attack")
W:step(0.5)
check(data(P2).Health == 0, "P2 downed")
check(P2:GetAttribute("BleedOut") ~= nil, "bleedout attr")

-- Подъём и крюк
fire(P1, "BeginAction", "Pickup", P2)
W:step(0.2)
errorsOk("pickup")
check(data(P2).Status == "Carried", "P2 carried")
check(data(P1).Carrying == data(P2), "killer carrying")
local hook = State.Map.Hooks:GetChildren()[1]
local hp = hook:FindFirstChild("HangPoint")
place(P1, hp.Position * V3.new(1, 0, 1) + V3.new(2, 3.45, 0), hp.Position)
fire(P1, "BeginAction", "Hook", hook)
W:step(1.6)
errorsOk("hook")
check(data(P2).Status == "Hooked", "P2 hooked: " .. tostring(data(P2).Status))
check(hook:GetAttribute("Occupant") == P2.UserId, "hook occupant")
check(root(P2).Anchored == true, "hooked root anchored")
check(data(P1).Carrying == nil, "killer no longer carrying")

-- Снятие с крюка
place(P3, hp.Position * V3.new(1, 0, 1) + V3.new(-2, 3, 0), hp.Position)
fire(P3, "BeginAction", "Unhook", P2)
W:step(1.5)
errorsOk("unhook")
check(data(P2).Status == "Playing" and data(P2).Health == 1, "P2 unhooked injured")
check(hook:GetAttribute("Occupant") == 0, "hook free")
check(root(P2).Anchored == false, "unhooked root free")

-- Лечение
place(P2, spawnPos)
place(P3, spawnPos + V3.new(2, 0, 0))
fire(P3, "BeginAction", "Heal", P2)
W:step(17)
errorsOk("heal")
check(data(P2).Health == 2, "P2 healed: " .. data(P2).Health)
fire(P3, "EndAction")

-- Паллета и оглушение
local pallet
for _, p in State.Map.Pallets:GetChildren() do
	if p:GetAttribute("State") == "Up" then
		pallet = p
		break
	end
end
local dropCF = pallet:GetAttribute("DropCFrame")
place(P2, (dropCF * CF.new(0, 1.5, 2.5)).Position, dropCF.Position)
place(P1, (dropCF * CF.new(0, 1.95, -3)).Position, dropCF.Position)
W:step(3) -- кулдаун атаки прошёл
fire(P2, "BeginAction", "DropPallet", pallet)
W:step(0.3)
errorsOk("pallet")
check(pallet:GetAttribute("State") == "Dropped", "pallet dropped")
check(P1:GetAttribute("Stunned") == true, "killer stunned")
check(pallet.PrimaryPart.CanCollide == true, "pallet hitbox collides")
W:step(2.5)
fire(P1, "BeginAction", "Break", pallet)
W:step(3)
errorsOk("break")
check(pallet:GetAttribute("State") == "Broken", "pallet broken")
W:step(2.5)
check(pallet.Parent == nil, "pallet debris removed")

-- Перелезание через окно
local window = State.Map.Windows:GetChildren()[1]
local before = window.CFrame:PointToObjectSpace(V3.new(0, 0, 0))
place(P2, (window.CFrame * CF.new(0, 1.5, -2)).Position, window.Position)
fire(P2, "BeginAction", "Vault", window)
W:step(1.2)
errorsOk("vault")
local rel = window.CFrame:PointToObjectSpace(root(P2).Position)
check(rel.Z > 1, "vaulted to other side, rel.Z=" .. rel.Z)
check(root(P2).Anchored == false, "root free after vault")
local _ = before

-- Шкафчик глазами клиента: камера внутри, потом снова обычная
do
	local l = State.Map.Lockers:GetChildren()[2]
	local ins = l:FindFirstChild("Inside")
	place(P2, (ins.CFrame * CF.new(0, 0, -3)).Position, ins.Position)
	W:step(0.1)
	press("DBDSecondary") -- Пробел: ближайшее вторичное действие — шкафчик
	W:step(1)
	check(data(P2).Hidden == l, "client entered locker via Space")
	check(camera.CameraType == Enum.CameraType.Scriptable, "locker camera scriptable")
	press("DBDSecondary")
	W:step(1)
	check(data(P2).Hidden == nil, "client left locker via Space")
	check(camera.CameraType == Enum.CameraType.Custom, "camera restored after locker")
	errorsOk("client locker")
end

-- Шкафчик и обыск
local locker = State.Map.Lockers:GetChildren()[1]
local inside = locker:FindFirstChild("Inside")
place(P3, (inside.CFrame * CF.new(0, 0, -3)).Position, inside.Position)
fire(P3, "BeginAction", "EnterLocker", locker)
W:step(1)
errorsOk("enter locker")
check(data(P3).Hidden == locker and P3:GetAttribute("Hidden") == true, "P3 hidden")
check(locker:GetAttribute("Occupant") == P3.UserId, "locker occupied")
place(P1, (inside.CFrame * CF.new(0, 0.45, -3.5)).Position, inside.Position)
fire(P1, "BeginAction", "SearchLocker", locker)
W:step(1.3)
errorsOk("search locker")
check(data(P3).Status == "Carried", "P3 grabbed from locker: " .. tostring(data(P3).Status))
check(data(P3).Hidden == nil and locker:GetAttribute("Occupant") == 0, "locker freed")

-- Вырывание
W:step(Config.WiggleTime + 1)
errorsOk("wiggle")
check(data(P3).Status == "Playing" and data(P3).Health == 1, "P3 wiggled free")

-- Капканы (маньяк ещё оглушён после того, как выживший вырвался)
W:step(3)
local kroot = root(P1)
place(P1, spawnPos + V3.new(10, 0.45, 0), spawnPos + V3.new(10, 0.45, -10))
local trapsBefore = #State.Map.Traps:GetChildren()
fire(P1, "UsePower", true, V3.new(0, 0, -1))
W:step(2.5)
errorsOk("set trap")
check(#State.Map.Traps:GetChildren() == trapsBefore + 1, "trap placed")
check(P1:GetAttribute("PowerCount") == 0, "trap count decreased")
local trap
for _, t in State.Map.Traps:GetChildren() do
	if t:GetAttribute("Armed") then
		trap = t
		break
	end
end
local origin = trap:GetAttribute("Origin")
place(P2, origin.Position + V3.new(0, 3, 0))
W:step(0.3)
errorsOk("trap catch")
check(data(P2).Trapped == trap, "P2 trapped")
check(data(P2).Health == 1, "trap injures")
local freed = false
for _ = 1, 12 do
	fire(P2, "BeginAction", "EscapeTrap", trap)
	W:step(1.6)
	if not data(P2).Trapped then
		freed = true
		break
	end
end
errorsOk("escape trap")
check(freed, "escaped trap eventually")
local _ = kroot

-- Сундук и предметы
local chest = State.Map.Chests:GetChildren()[1]
place(P2, chest.PrimaryPart.Position + V3.new(0, 2, -2.5), chest.PrimaryPart.Position)
fire(P2, "BeginAction", "OpenChest", chest)
W:step(5.5)
errorsOk("chest")
check(chest:GetAttribute("Opened") == true, "chest opened")
check(P2:GetAttribute("Item") ~= nil, "got item " .. tostring(P2:GetAttribute("Item")))
Items.give(data(P2), "Medkit")
fire(P2, "UseItem", true, V3.new(0, 0, -1))
W:step(13)
errorsOk("medkit")
check(data(P2).Health == 2, "self healed with medkit: " .. data(P2).Health)
fire(P2, "UseItem", false, V3.new(0, 0, -1))
-- Фонарик
Items.give(data(P3), "Flashlight")
place(P3, spawnPos)
place(P1, spawnPos + V3.new(0, 0.45, -8), spawnPos)
W:step(3)
local aim = (root(P1).Position - root(P3).Position).Unit
fire(P3, "UseItem", true, aim)
W:step(1.5)
errorsOk("flashlight")
check(P1:GetAttribute("Blinded") == true or data(P1).BlindUntil > Sched.Time, "killer blinded")
fire(P3, "UseItem", false, aim)

-- Тотем
local hex
for _, t in State.Map.Totems:GetChildren() do
	if t:GetAttribute("Hex") then
		hex = t
	end
end
check(State.HexRuin == true, "hex ruin active")
place(P2, hex.PrimaryPart.Position + V3.new(0, 3, -2.5), hex.PrimaryPart.Position)
fire(P2, "BeginAction", "Cleanse", hex)
W:step(13)
errorsOk("cleanse")
check(hex:GetAttribute("Cleansed") == true and State.HexRuin == false, "hex cleansed")

-- Остальные генераторы
for _, g in State.Map.Generators:GetChildren() do
	if State.GensDone >= Config.GeneratorsRequired then
		break
	end
	if not g:GetAttribute("Done") then
		g:SetAttribute("Progress", 0.998)
		place(P2, g.PrimaryPart.Position + V3.new(0, 1, -2.6), g.PrimaryPart.Position)
		fire(P2, "BeginAction", "Repair", g)
		W:step(0.5)
	end
end
errorsOk("all gens")
check(State.GatesPowered, "gates powered")

-- Ворота и побег
local gate = State.Map.ExitGates:GetChildren()[1]
place(P3, gate.Switch.Position + V3.new(0, 1, 0) - gate.Switch.CFrame.LookVector * 2.5, gate.Switch.Position)
fire(P3, "BeginAction", "OpenGate", gate)
W:step(Config.OpenGateTime + 1)
errorsOk("open gate")
check(gate:GetAttribute("Open") == true, "gate open")
check(State.EndgameDeadline ~= nil, "endgame started")
place(P3, gate.EscapeZone.Position)
W:step(0.5)
errorsOk("escape")
check(data(P3).Status == "Escaped", "P3 escaped")
W:step(1)
check(root(P3) and root(P3).Position.Y > 300, "P3 respawned in lobby")

-- Обрушение
W:step(Config.EndGameCollapseTime + 2)
errorsOk("collapse")
check(not State.Active, "match ended")
check(State.GameState:GetAttribute("Phase") == "Results", "results phase")
local results
for _, r in W.Remotes do
	if r.Name == "Results" then
		results = r
	end
end
check(results ~= nil, "results sent")
check(P1:GetAttribute("Role") == nil, "attributes cleared")
W:step(0.5)
check(camera.CameraSubject == P2.Character:FindFirstChildOfClass("Humanoid"), "camera back on own character after round")
check(Players.LocalPlayer.CameraMode == Enum.CameraMode.Classic, "classic camera after round")
check((P2:GetAttribute("Bloodpoints") or 0) > 0, "bloodpoints committed")
W:step(1)
check(root(P1) and root(P1).Position.Y > 300, "killer back in lobby")

------------------------------------------------------------------------
print("== Раунд 2: Охотница")
fire(P1, "LobbyChoice", "Killer", "Huntress")
W:step(Config.ResultsTime + Config.LobbyCountdown + 3)
errorsOk("round 2 start")
check(State.Active and data(P1).KillerType == "Huntress", "huntress round")
place(P2, spawnPos, spawnPos + V3.new(0, 0, 10))
place(P1, spawnPos + V3.new(0, 0.8, -15), spawnPos)
local spawn2 = State.Map.SurvivorSpawn
place(P3, spawn2 + V3.new(30, 0, 0))
place(P2, spawn2, spawn2 + V3.new(0, 0, 10))
place(P1, spawn2 + V3.new(0, 0.8, -14), spawn2)
local head = P1.Character.Head
local dir = (root(P2).Position - head.Position).Unit
fire(P1, "UsePower", true, dir)
W:step(1.2)
check(P1:GetAttribute("PowerCharge") > 0, "windup charge")
fire(P1, "UsePower", false, dir)
W:step(1)
errorsOk("hatchet")
check(P1:GetAttribute("PowerCount") == 4, "hatchet used")
check(data(P2).Health == 1, "hatchet hit P2: health=" .. data(P2).Health)
-- Пополнение в шкафчике
local locker2 = State.Map.Lockers:GetChildren()[1]
local inside2 = locker2:FindFirstChild("Inside")
place(P1, (inside2.CFrame * CF.new(0, 0.8, -3.5)).Position, inside2.Position)
fire(P1, "BeginAction", "SearchLocker", locker2)
W:step(1.3)
errorsOk("reload")
check(P1:GetAttribute("PowerCount") == 5, "hatchets refilled")

-- Выход игрока посреди раунда
P3.Parent = nil
W:service("Players").PlayerRemoving:Fire(P3)
W:step(0.5)
errorsOk("leave")
check(data(P3) == nil or data(P3).Status == "Left", "P3 left")

-- Люк: остался один выживший (P2), было двое
local hatch = State.Map.Hatch
check(hatch:GetAttribute("Open") == true, "hatch open for last survivor")
place(P2, hatch.PrimaryPart.Position + V3.new(1, 3, 0))
fire(P2, "BeginAction", "JumpHatch", hatch)
W:step(1)
errorsOk("hatch")
check(not State.Active, "round ended after hatch escape")

------------------------------------------------------------------------
print("== Раунд 3: Призрак")
local P4 = W:addPlayer("Carol", 4)
fire(P1, "LobbyChoice", "Killer", "Wraith")
W:step(Config.ResultsTime + Config.LobbyCountdown + 3)
errorsOk("round 3 start")
check(State.Active and data(P1).KillerType == "Wraith", "wraith round")
local spawn3 = State.Map.SurvivorSpawn
place(P4, spawn3 + V3.new(30, 0, 0))
place(P2, spawn3, spawn3 + V3.new(0, 0, 10))
place(P1, spawn3 + V3.new(0, 0.45, -3), spawn3)
fire(P1, "UsePower", true)
W:step(2)
errorsOk("cloak")
check(P1:GetAttribute("PowerState") == "Cloaked", "wraith cloaked")
check(P1:GetAttribute("TerrorRadius") == 0, "no terror radius cloaked")
fire(P1, "Attack")
W:step(0.5)
check(data(P2).Health == 2, "cloaked wraith cannot hit")
fire(P1, "UsePower", true)
W:step(1.5)
check(P1:GetAttribute("PowerState") == "Visible", "uncloaked")
place(P1, spawn3 + V3.new(0, 0.45, -3), spawn3)
fire(P1, "Attack")
W:step(0.5)
errorsOk("wraith hit")
check(data(P2).Health == 1, "uncloaked hit lands")

-- Маньяк выходит -> раунд заканчивается
P1.Parent = nil
W:service("Players").PlayerRemoving:Fire(P1)
W:step(1)
errorsOk("killer leaves")
check(not State.Active, "round ends when killer leaves")
local _ = P4

------------------------------------------------------------------------
if failures > 0 then
	print(("%d checks failed"):format(failures))
	process.exit(1)
end
print("sim tests OK")
