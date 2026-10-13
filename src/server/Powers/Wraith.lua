-- Призрак: колокол, невидимость и рывок после проявления.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KillerDefs = require(ReplicatedStorage.Shared.KillerDefs)
local Server = script.Parent.Parent
local State = require(Server.Core.State)
local Scoring = require(Server.Core.Scoring)

local DEF = KillerDefs.Wraith
local Wraith = {}

local function setCloaked(kdata, cloaked: boolean)
	kdata.Power.Cloaked = cloaked
	kdata.Player:SetAttribute("Cloaked", cloaked)
	local char = kdata.Player.Character
	if char then
		char:SetAttribute("Cloaked", cloaked)
		-- Красное пятно не видно, пока Призрак невидим
		local head = char:FindFirstChild("Head")
		local stain = head and head:FindFirstChild("RedStain") :: SpotLight?
		if stain then
			stain.Enabled = not cloaked
		end
	end
end

function Wraith.Setup(kdata)
	kdata.Power = { Cloaked = false, Transition = nil, TransitionEnd = 0, BoostUntil = 0, UncloakedAt = 0 }
	setCloaked(kdata, false)
	kdata.Player:SetAttribute("PowerState", "Visible")
end

local function startTransition(kdata, kind: string, duration: number)
	kdata.Power.Transition = kind
	kdata.Power.TransitionEnd = State.now() + duration
	kdata.PowerBusy = true
	kdata.Player:SetAttribute("PowerState", kind)
	State.playAnim(kdata.Player, "Bell")
	State.sfx("Bell", State.getRoot(kdata.Player))
end

function Wraith.Press(kdata)
	local p = kdata.Power
	local t = State.now()
	if p.Transition or kdata.Carrying or kdata.Action or kdata.Lunging then
		return
	end
	if t < kdata.StunnedUntil or t < kdata.BlindUntil or t < kdata.VaultUntil then
		return
	end
	if p.Cloaked then
		startTransition(kdata, "Uncloaking", DEF.UncloakTime)
	else
		startTransition(kdata, "Cloaking", DEF.CloakTime)
	end
end

function Wraith.Update(kdata, _dt)
	local p = kdata.Power
	if p.Transition and State.now() >= p.TransitionEnd then
		if p.Transition == "Cloaking" then
			setCloaked(kdata, true)
			kdata.Player:SetAttribute("PowerState", "Cloaked")
		else
			setCloaked(kdata, false)
			p.BoostUntil = State.now() + DEF.UncloakBoostTime
			p.UncloakedAt = State.now()
			kdata.Player:SetAttribute("PowerState", "Visible")
		end
		p.Transition = nil
		kdata.PowerBusy = false
	end
end

function Wraith.CanAttack(kdata)
	return not kdata.Power.Cloaked and kdata.Power.Transition == nil
end

function Wraith.SpeedOverride(kdata, t: number)
	local p = kdata.Power
	if p.Transition then
		return 4
	end
	if p.Cloaked then
		return DEF.CloakedSpeed
	end
	if t < p.BoostUntil then
		return DEF.UncloakBoostSpeed
	end
	return nil
end

function Wraith.TerrorRadius(kdata)
	if kdata.Power.Cloaked then
		return 0
	end
	return DEF.TerrorRadius
end

-- Фонарик проявляет Призрака
function Wraith.OnBlind(kdata)
	local p = kdata.Power
	if p.Cloaked or p.Transition == "Cloaking" then
		p.Transition = nil
		kdata.PowerBusy = false
		setCloaked(kdata, false)
		kdata.Player:SetAttribute("PowerState", "Visible")
		State.notifyAll("Призрак проявлен светом!", State.YELLOW)
	end
end

function Wraith.OnStun(kdata)
	local p = kdata.Power
	if p.Transition then
		p.Transition = nil
		kdata.PowerBusy = false
		kdata.Player:SetAttribute("PowerState", p.Cloaked and "Cloaked" or "Visible")
	end
end

function Wraith.OnHit(kdata, _sdata)
	if State.now() - (kdata.Power.UncloakedAt or 0) < 2 then
		Scoring.add(kdata.Player, "Deviousness", 500, "Внезапный удар")
	end
end

function Wraith.Cleanup(kdata)
	setCloaked(kdata, false)
end

return Wraith
