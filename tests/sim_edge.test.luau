--!nocheck
-- Пограничные случаи серверной логики и клиент за маньяка.
local Fake = require("./fakeroblox")
local process = require("@lune/process")
local Enum = require("@lune/roblox").Enum

local PLACE = process.args[1] or "DeadByDaylight.rbxlx"
local V3, CF = Fake.Vector3, Fake.CFrame
local Sched = Fake.Sched

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
	end
end

-- Создаёт мир, игроков и запускает раунд. clientIndex — за кого запускать клиент.
local function setup(names, killerType, clientIndex)
	local W = Fake.newWorld(PLACE)
	local SSS = W:service("ServerScriptService")
	local RS = W:service("ReplicatedStorage")
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
	W:run(SSS.Server.Main)
	local players = {}
	for i, n in names do
		players[i] = W:addPlayer(n, i)
	end
	if clientIndex then
		local p = players[clientIndex]
		local gui = Fake.Instance.new("PlayerGui")
		gui.Name = "PlayerGui"
		gui.Parent = p
		W:service("Players").LocalPlayer = p
		W.LocalPlayer = p
		W:run(W:service("StarterPlayer").StarterPlayerScripts.Client.Client)
	end
	W:step(1)
	local function fire(p, remote, ...)
		RS.Remotes[remote].OnServerEvent:Fire(p, ...)
	end
	if #names > 1 then
		fire(players[1], "LobbyChoice", "WantKiller", true)
		fire(players[1], "LobbyChoice", "Killer", killerType or "Trapper")
	end
	local Config = W:require(RS.Shared.Config)
	W:step(Config.LobbyCountdown + 2)
	local State = W:require(SSS.Server.Core.State)
	local ctx = { W = W, State = State, Config = Config, P = players, fire = fire }
	function ctx.data(p)
		return State.Participants[p]
	end
	function ctx.root(p)
		return p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	end
	function ctx.place(p, pos, look)
		local r = ctx.root(p)
		r.Anchored = false
		p.Character:PivotTo(CF.lookAt(pos, look or (pos + V3.new(0, 0, -1))))
	end
	-- Разводим всех выживших подальше друг от друга
	local sp = State.Map.SurvivorSpawn
	for i, p in players do
		if ctx.data(p) and ctx.data(p).Role == "Survivor" then
			ctx.place(p, sp + V3.new((i - 1) * 25, 0, 0))
		end
	end
	return ctx
end

local function down(ctx, killer, victim)
	local sp = ctx.State.Map.SurvivorSpawn
	ctx.place(victim, sp, sp + V3.new(0, 0, 10))
	for _ = 1, 2 do
		ctx.place(killer, sp + V3.new(0, 0.45, -3), sp)
		ctx.fire(killer, "Attack")
		ctx.W:step(3)
	end
end

local function hookOn(ctx, killer, victim, hookIndex)
	ctx.fire(killer, "BeginAction", "Pickup", victim)
	ctx.W:step(0.2)
	local hook = ctx.State.Map.Hooks:GetChildren()[hookIndex or 1]
	local hp = hook:FindFirstChild("HangPoint")
	ctx.place(killer, hp.Position * V3.new(1, 0, 1) + V3.new(2, 3.45, 0), hp.Position)
	ctx.fire(killer, "BeginAction", "Hook", hook)
	ctx.W:step(1.6)
	return hook
end

------------------------------------------------------------------------
print("== Смерть, истечение кровью, жертвоприношение")
do
	local c = setup({ "K", "A", "B", "C" }, "Trapper", 2)
	local K, A, B, C = c.P[1], c.P[2], c.P[3], c.P[4]
	check(c.State.Active, "round active")
	-- Reset
	local hum = A.Character:FindFirstChildOfClass("Humanoid")
	hum.Died:Fire()
	c.W:step(2.5)
	errorsOk("reset")
	check(c.data(A).Status == "Dead", "reset -> dead")
	check(c.root(A) and c.root(A).Position.Y > 300, "dead respawned in lobby")
	check(c.State.Active, "match continues")
	-- Наблюдение (клиент за A)
	local cam = c.W:service("Workspace").CurrentCamera
	local gui = A.PlayerGui.DBDHud
	local button
	for _, d in gui:GetDescendants() do
		if d._class == "TextButton" and d.Text == "Наблюдать" then
			button = d
		end
	end
	check(button ~= nil and button.Visible, "spectate button visible after death")
	button.Activated:Fire()
	c.W:step(0.2)
	local subj = cam.CameraSubject
	local watched = subj and c.W:service("Players"):GetPlayerFromCharacter(subj.Parent)
	check(watched ~= nil and watched ~= A, "spectating another player")
	errorsOk("spectate")
	-- Истечение кровью (если A смотрел за B, камера переключится)
	down(c, K, B)
	check(c.data(B).Health == 0, "B downed")
	c.W:step(c.Config.BleedOutTime + 1)
	errorsOk("bleedout")
	check(c.data(B).Status == "Dead", "B bled out")
	c.W:step(0.2)
	local s2 = cam.CameraSubject
	local w2 = s2 and c.W:service("Players"):GetPlayerFromCharacter(s2.Parent)
	check(w2 ~= B, "camera left the dead player")
	check(w2 == nil or w2 == A or (c.data(w2) and c.data(w2).Status ~= "Dead"), "camera on a living player or self")
	-- Крюк до жертвоприношения
	down(c, K, C)
	local hook = hookOn(c, K, C)
	check(c.data(C).Status == "Hooked", "C hooked")
	c.W:step(c.Config.HookStageTime + 1)
	check(c.data(C).HookCount == 2 and hook:FindFirstChild("EntityLegs") ~= nil, "stage 2 with entity")
	c.W:step(c.Config.HookStageTime + 4)
	errorsOk("sacrifice")
	check(c.data(C) == nil or c.data(C).Status == "Dead", "C sacrificed")
	check(not c.State.Active, "round over, all dead")
	c.W:step(0.5)
	check(cam.CameraSubject == A.Character:FindFirstChildOfClass("Humanoid"), "spectating stops after round")
	check(not button.Visible, "spectate button hidden after round")
	check(hook:GetAttribute("Occupant") == 0 or hook.Parent == nil, "hook freed")
end

------------------------------------------------------------------------
print("== Выходы игроков в разных состояниях, люк закрыт маньяком")
do
	local c = setup({ "K", "A", "B", "C", "D" }, "Trapper")
	local K, A, B, C, D = c.P[1], c.P[2], c.P[3], c.P[4], c.P[5]
	-- A уходит, пока его несут
	down(c, K, A)
	c.fire(K, "BeginAction", "Pickup", A)
	c.W:step(0.2)
	check(c.data(A).Status == "Carried", "A carried")
	A.Parent = nil
	c.W:service("Players").PlayerRemoving:Fire(A)
	c.W:step(0.5)
	errorsOk("leave while carried")
	check(c.data(K).Carrying == nil, "killer freed after carried left")
	-- B уходит с крюка
	down(c, K, B)
	local hook = hookOn(c, K, B, 2)
	check(c.data(B).Status == "Hooked", "B hooked")
	B.Parent = nil
	c.W:service("Players").PlayerRemoving:Fire(B)
	c.W:step(0.5)
	errorsOk("leave while hooked")
	check(hook:GetAttribute("Occupant") == 0, "hook freed after leaving")
	-- C уходит из шкафчика
	local locker = c.State.Map.Lockers:GetChildren()[1]
	local ins = locker:FindFirstChild("Inside")
	c.place(C, (ins.CFrame * CF.new(0, 0, -3)).Position, ins.Position)
	c.fire(C, "BeginAction", "EnterLocker", locker)
	c.W:step(1)
	check(locker:GetAttribute("Occupant") == C.UserId, "C in locker")
	C.Parent = nil
	c.W:service("Players").PlayerRemoving:Fire(C)
	c.W:step(0.5)
	errorsOk("leave while hidden")
	check(locker:GetAttribute("Occupant") == 0, "locker freed after leaving")
	-- Остался D: люк открыт (выживших было 4), маньяк закрывает
	local hatch = c.State.Map.Hatch
	check(hatch:GetAttribute("Open") == true, "hatch opens for last survivor")
	c.place(K, hatch.PrimaryPart.Position + V3.new(1.5, 3.45, 0))
	c.fire(K, "BeginAction", "CloseHatch", hatch)
	c.W:step(2)
	errorsOk("close hatch")
	check(hatch:GetAttribute("Closed") == true, "hatch closed")
	check(c.State.GatesPowered and c.State.EndgameDeadline ~= nil, "endgame after hatch closed")
	local _ = D
end

------------------------------------------------------------------------
print("== Капканы: обезвредить, освободить, поднять из капкана")
do
	local c = setup({ "K", "A", "B" }, "Trapper")
	local K, A, B = c.P[1], c.P[2], c.P[3]
	local traps = c.State.Map.Traps:GetChildren()
	local t1, t2 = traps[1], traps[2]
	c.place(A, t1:GetAttribute("Origin").Position + V3.new(2, 3, 0))
	c.fire(A, "BeginAction", "DisarmTrap", t1)
	c.W:step(3)
	errorsOk("disarm")
	check(t1:GetAttribute("Armed") == false, "trap disarmed")
	c.place(K, t1:GetAttribute("Origin").Position + V3.new(-2, 3.45, 0))
	c.fire(K, "BeginAction", "ResetTrap", t1)
	c.W:step(2)
	check(t1:GetAttribute("Armed") == true, "trap re-armed")
	-- A попадает, B освобождает
	c.place(K, t1:GetAttribute("Origin").Position + V3.new(40, 3.45, 0))
	c.place(A, t2:GetAttribute("Origin").Position + V3.new(0, 3, 0))
	c.W:step(0.3)
	check(c.data(A).Trapped == t2, "A trapped")
	c.place(B, t2:GetAttribute("Origin").Position + V3.new(2.5, 3, 0))
	c.fire(B, "BeginAction", "FreeTrap", t2)
	c.W:step(3.5)
	errorsOk("free trap")
	check(c.data(A).Trapped == nil and c.root(A).Anchored == false, "A freed by B")
	-- Маньяк поднимает пойманного
	t2:SetAttribute("Armed", true)
	c.place(B, t2:GetAttribute("Origin").Position + V3.new(30, 3, 0))
	c.place(A, t2:GetAttribute("Origin").Position + V3.new(0, 3, 0))
	c.W:step(0.3)
	check(c.data(A).Trapped == t2, "A trapped again")
	c.place(K, t2:GetAttribute("Origin").Position + V3.new(2.5, 3.45, 0))
	c.fire(K, "BeginAction", "Pickup", A)
	c.W:step(0.3)
	errorsOk("pickup trapped")
	check(c.data(A).Status == "Carried" and c.data(A).Trapped == nil, "trapped survivor picked up")
	check(t2:GetAttribute("Caught") == 0, "trap released on pickup")
end

------------------------------------------------------------------------
print("== Генераторы: повреждение и Руина")
do
	local c = setup({ "K", "A" }, "Trapper")
	local K, A = c.P[1], c.P[2]
	c.State.Map.Traps:ClearAllChildren() -- капканы не должны мешать этому сценарию
	local gen = c.State.Map.Generators:GetChildren()[1]
	gen:SetAttribute("Progress", 0.5)
	c.place(K, gen.PrimaryPart.Position + V3.new(0, 1.45, -2.8), gen.PrimaryPart.Position)
	c.fire(K, "BeginAction", "Kick", gen)
	c.W:step(2)
	errorsOk("kick")
	check(gen:GetAttribute("Regressing") == true, "gen regressing")
	local p1 = gen:GetAttribute("Progress")
	check(p1 < 0.5, "kick regressed")
	c.W:step(5)
	check(gen:GetAttribute("Progress") < p1, "regression continues")
	-- Руина откатывает и без пинка
	local g2 = c.State.Map.Generators:GetChildren()[2]
	g2:SetAttribute("Progress", 0.3)
	c.W:step(5)
	check(not c.State.HexRuin or g2:GetAttribute("Progress") < 0.3, "ruin regresses")
	-- Начало ремонта снимает откат
	c.place(A, gen.PrimaryPart.Position + V3.new(0, 1, -2.6), gen.PrimaryPart.Position)
	c.fire(A, "BeginAction", "Repair", gen)
	c.W:step(0.5)
	check(gen:GetAttribute("Regressing") == false, "repair stops regression")
end

------------------------------------------------------------------------
print("== Охотница: отмена замаха, оглушение во время замаха")
do
	local c = setup({ "K", "A" }, "Huntress")
	local K, A = c.P[1], c.P[2]
	c.fire(K, "UsePower", true, V3.new(0, 0, -1))
	c.W:step(0.2)
	c.fire(K, "UsePower", false, V3.new(0, 0, -1))
	c.W:step(0.2)
	errorsOk("cancel windup")
	check(K:GetAttribute("PowerCount") == 5, "early release does not throw")
	check(c.data(K).PowerBusy == false, "not busy after cancel")
	-- оглушение паллетой во время замаха
	local pallet = c.State.Map.Pallets:GetChildren()[1]
	local dropCF = pallet:GetAttribute("DropCFrame")
	c.place(A, (dropCF * CF.new(0, 1.5, 2.5)).Position, dropCF.Position)
	c.place(K, (dropCF * CF.new(0, 1.95, -3)).Position, dropCF.Position)
	c.fire(K, "UsePower", true, V3.new(0, 0, 1))
	c.W:step(0.3)
	c.fire(A, "BeginAction", "DropPallet", pallet)
	c.W:step(0.3)
	errorsOk("stun during windup")
	check(c.data(K).PowerBusy == false and K:GetAttribute("PowerCharge") == 0, "windup cancelled by stun")
	c.fire(K, "UsePower", false, V3.new(0, 0, 1))
	c.W:step(0.3)
	check(K:GetAttribute("PowerCount") == 5, "no throw after stun")
end

------------------------------------------------------------------------
print("== Призрак: фонарик проявляет")
do
	local c = setup({ "K", "A" }, "Wraith")
	local K, A = c.P[1], c.P[2]
	local Items = c.W:require(c.W:service("ServerScriptService").Server.Systems.Items)
	c.fire(K, "UsePower", true)
	c.W:step(2)
	check(K:GetAttribute("PowerState") == "Cloaked", "cloaked")
	Items.give(c.data(A), "Flashlight")
	local sp = c.State.Map.SurvivorSpawn
	c.place(A, sp)
	c.place(K, sp + V3.new(0, 0.45, -8), sp)
	local aim = (c.root(K).Position - c.root(A).Position).Unit
	c.fire(A, "UseItem", true, aim)
	c.W:step(1.5)
	errorsOk("flashlight on wraith")
	check(K:GetAttribute("PowerState") == "Visible", "flashlight uncloaks wraith")
	check(c.data(K).PowerBusy == false, "wraith not stuck busy")
end

------------------------------------------------------------------------
print("== Одиночный режим (Studio): починить, открыть, сбежать")
do
	local c = setup({ "Solo" }, nil, 1)
	local S = c.P[1]
	check(c.State.Active and c.State.SoloTest, "solo round")
	check(c.data(S).Role == "Survivor", "solo is survivor")
	for _, g in c.State.Map.Generators:GetChildren() do
		if c.State.GensDone >= c.Config.GeneratorsRequired then
			break
		end
		g:SetAttribute("Progress", 0.998)
		c.place(S, g.PrimaryPart.Position + V3.new(0, 1, -2.6), g.PrimaryPart.Position)
		c.fire(S, "BeginAction", "Repair", g)
		c.W:step(0.5)
	end
	check(c.State.GatesPowered, "solo gates powered")
	local gate = c.State.Map.ExitGates:GetChildren()[2]
	c.place(S, gate.Switch.Position + V3.new(0, 1, 0) - gate.Switch.CFrame.LookVector * 2.5, gate.Switch.Position)
	c.fire(S, "BeginAction", "OpenGate", gate)
	c.W:step(c.Config.OpenGateTime + 1)
	c.place(S, gate.EscapeZone.Position)
	c.W:step(1)
	errorsOk("solo escape")
	check(not c.State.Active, "solo round ended")
	local cam = c.W:service("Workspace").CurrentCamera
	c.W:step(1)
	check(cam.CameraSubject == S.Character:FindFirstChildOfClass("Humanoid"), "solo camera on lobby character")
end

------------------------------------------------------------------------
print("== Вороны и погоня")
do
	local c = setup({ "K", "A" }, "Trapper")
	local K, A = c.P[1], c.P[2]
	local crows = c.State.Map.Crows:GetChildren()
	check(#crows > 0, "crows spawned")
	local crow = crows[1]
	local cpos = crow.PrimaryPart.Position
	local before = #c.W.Remotes
	c.fire(A, "Sprint", true)
	c.place(A, cpos + V3.new(3, 3, 0))
	c.root(A).AssemblyLinearVelocity = V3.new(16, 0, 0)
	c.W:step(0.5)
	errorsOk("crow")
	local noise = false
	for i = before + 1, #c.W.Remotes do
		if c.W.Remotes[i].Name == "Noise" then
			noise = true
		end
	end
	check(noise, "crow alerted killer")
	c.W:step(3)
	check(crow.Parent == nil, "crow flew away")
	-- Погоня: ищем направление, где между ними нет стен
	local sp = c.State.Map.SurvivorSpawn
	local ws = c.W:service("Workspace")
	local kpos
	for i = 0, 7 do
		local a = i * math.pi / 4
		local candidate = sp + V3.new(math.sin(a) * 10, 0.45, math.cos(a) * 10)
		local params = { FilterDescendantsInstances = { K.Character, A.Character }, RespectCanCollide = true }
		if not ws:Raycast(candidate, sp - candidate, params) then
			kpos = candidate
			break
		end
	end
	check(kpos ~= nil, "found clear line for chase test")
	local away = (sp - kpos) * V3.new(1, 0, 1)
	c.place(A, sp, sp + away)
	c.root(A).AssemblyLinearVelocity = away.Unit * 16
	c.place(K, kpos, sp)
	c.W:step(0.6)
	errorsOk("chase")
	check(A:GetAttribute("Chase") == true and K:GetAttribute("Chase") == true, "chase detected")
end

------------------------------------------------------------------------
print("== Клиент за маньяка")
do
	local c = setup({ "K", "A" }, "Huntress", 1)
	local K, A = c.P[1], c.P[2]
	local Players = c.W:service("Players")
	c.W:step(0.5)
	errorsOk("killer client")
	check(Players.LocalPlayer.CameraMode == Enum.CameraMode.LockFirstPerson, "killer first person")
	check(c.W.Actions.DBDAttack ~= nil and c.W.Actions.DBDPower ~= nil, "killer controls bound")
	check(c.W.Actions.DBDSprint == nil, "no sprint for killer")
	-- Следы бегущего выжившего видит маньяк
	c.root(A).AssemblyLinearVelocity = V3.new(16, 0, 0)
	c.fire(A, "Sprint", true)
	c.W:step(1)
	errorsOk("scratch marks")
	local fx = c.W:service("Workspace"):FindFirstChild("DBDLocalFX")
	local scratches = 0
	for _, d in fx:GetChildren() do
		if d.Name == "Scratch" then
			scratches += 1
		end
	end
	check(scratches > 0, "scratch marks drawn for killer: " .. scratches)
	-- Оглушение не уводит камеру
	local cam = c.W:service("Workspace").CurrentCamera
	local look0 = cam.CFrame.LookVector
	c.W:service("ReplicatedStorage").Remotes.Effect:FireClient(K, "Stun", 2)
	c.W:step(2.5)
	local look1 = cam.CFrame.LookVector
	check(look0:Dot(look1) > 0.99, "stun does not permanently tilt camera")
	-- Конец раунда: камера возвращается к обычной
	K.Parent = nil
	c.W:service("Players").PlayerRemoving:Fire(K)
	local _ = A
	c.W:step(1)
	errorsOk("killer client end")
end

------------------------------------------------------------------------
print("== Предметы, спасения, окна, промахи")
do
	local c = setup({ "K", "A", "B" }, "Huntress")
	local K, A, B = c.P[1], c.P[2], c.P[3]
	local Items = c.W:require(c.W:service("ServerScriptService").Server.Systems.Items)
	local Config = c.Config
	-- Ящик с инструментами ускоряет ремонт и тратится
	local gen = c.State.Map.Generators:GetChildren()[1]
	Items.give(c.data(A), "Toolbox")
	c.place(A, gen.PrimaryPart.Position + V3.new(0, 1, -2.6), gen.PrimaryPart.Position)
	c.fire(A, "BeginAction", "Repair", gen)
	c.W:step(4)
	local p = gen:GetAttribute("Progress")
	check(p > 4 * 1.4 / Config.GeneratorRepairTime, "toolbox speeds repair: " .. p)
	check(c.data(A).ItemCharges < Config.ToolboxCharges, "toolbox charges spent")
	c.data(A).ItemCharges = 0.1
	c.W:step(0.5)
	errorsOk("toolbox")
	check(A:GetAttribute("Item") == nil, "empty toolbox removed")
	c.fire(A, "EndAction")
	-- Фонарик разряжается
	Items.give(c.data(B), "Flashlight")
	c.data(B).ItemCharges = 0.3
	c.fire(B, "UseItem", true, V3.new(0, 0, -1))
	c.W:step(0.6)
	errorsOk("flashlight empty")
	check(B:GetAttribute("Item") == nil, "empty flashlight removed")
	-- Оглушение паллетой спасает несомого
	down(c, K, A)
	c.fire(K, "BeginAction", "Pickup", A)
	c.W:step(0.2)
	check(c.data(A).Status == "Carried", "A carried for pallet save")
	local pallet
	for _, pl in c.State.Map.Pallets:GetChildren() do
		if pl:GetAttribute("State") == "Up" then
			pallet = pl
			break
		end
	end
	local dropCF = pallet:GetAttribute("DropCFrame")
	c.place(B, (dropCF * CF.new(0, 1.5, 2.5)).Position, dropCF.Position)
	c.place(K, (dropCF * CF.new(0, 1.95, -3)).Position, dropCF.Position)
	c.fire(B, "BeginAction", "DropPallet", pallet)
	c.W:step(0.3)
	errorsOk("pallet save")
	check(c.data(A).Status == "Playing" and c.data(A).Health == 1, "pallet stun frees carried survivor")
	check(c.data(K).Carrying == nil, "killer drops survivor")
	-- Ослепление спасает несомого
	c.W:step(3)
	down(c, K, A)
	c.fire(K, "BeginAction", "Pickup", A)
	c.W:step(0.2)
	Items.give(c.data(B), "Flashlight")
	local sp = c.State.Map.SurvivorSpawn
	local kpos = c.root(K).Position
	c.place(B, kpos + c.root(K).CFrame.LookVector * 6 - V3.new(0, 0.45, 0), kpos)
	local aim = (K.Character.Head.Position - B.Character.Head.Position).Unit
	c.fire(B, "UseItem", true, aim)
	c.W:step(1.5)
	errorsOk("blind save")
	check(c.data(A).Status == "Playing", "flashlight save frees carried survivor")
	c.fire(B, "UseItem", false, aim)
	-- Маньяк перелезает через окно
	c.W:step(3)
	local window = c.State.Map.Windows:GetChildren()[1]
	c.place(K, (window.CFrame * CF.new(0, 1.95, -2.2)).Position, window.Position)
	c.fire(K, "BeginAction", "Vault", window)
	c.W:step(2)
	errorsOk("killer vault")
	check(window.CFrame:PointToObjectSpace(c.root(K).Position).Z > 1, "killer vaulted window")
	-- Промах топором: летит в небо и пропадает
	c.place(K, sp + V3.new(40, 0.8, 0))
	c.fire(K, "UsePower", true, V3.new(0, 0.7, 0.7))
	c.W:step(1)
	c.fire(K, "UsePower", false, V3.new(0, 0.7, 0.7))
	c.W:step(5)
	errorsOk("hatchet miss")
	local ended = false
	for _, r in c.W.Remotes do
		if r.Name == "ProjectileEnd" then
			ended = true
		end
	end
	check(ended, "missed hatchet ends")
	-- Обычный тотем
	local dull
	for _, t in c.State.Map.Totems:GetChildren() do
		if not t:GetAttribute("Hex") then
			dull = t
		end
	end
	c.place(B, dull.PrimaryPart.Position + V3.new(0, 3, -2.5), dull.PrimaryPart.Position)
	c.fire(B, "BeginAction", "Cleanse", dull)
	c.W:step(13)
	errorsOk("dull totem")
	check(dull:GetAttribute("Cleansed") == true, "dull totem cleansed")
end

if failures > 0 then
	print(("%d checks failed"):format(failures))
	process.exit(1)
end
print("edge tests OK")
