-- Объекты карты: генератор, крюк, паллета, шкафчик, тотем, сундук, люк, капкан, ворона, ворота.
-- Каждая функция Build строит модель в начале координат: земля y = 0, «перед» модели смотрит в -Z.
-- Требования к моделям — в Contract.lua, подвижные части — через Kit.movable (см. PropFX.lua).
local Kit = require(script.Parent.Kit)

local P = Kit.Palette
local Mat = Kit.Mat
local A = Kit.A
local V = Vector3.new
local C = CFrame.new

local MapProps = {}
local T = {}
MapProps.Templates = T

local function base(name: string, kind: string): Model
	local m = Kit.model(name)
	m:SetAttribute("Kind", kind)
	return m
end

------------------------------------------------------------------------
-- Генератор
------------------------------------------------------------------------

T.Generator = {
	Variants = 3,
	Build = function(rng: Random)
		local m = base("Generator", "Generator")
		local body = Kit.box(m, C(0, 2, 0), V(4, 3, 3), Kit.jitter(P.Paint, 0.05, rng), Mat.DiamondPlate)
		body.Name = "Body"
		Kit.setOrigin(m, body)
		Kit.box(m, C(0, 0.25, 0), V(4.6, 0.5, 3.4), P.Rust, Mat.CorrodedMetal)
		Kit.box(m, C(-0.5, 4.15, 0), V(2.6, 1.3, 2.2), P.DarkSteel, Mat.Metal)
		for i = 1, 2 do
			local piston = Kit.vcyl(m, C(-1.1 + (i - 1) * 1.1, 5.2, 0), 1.3, 0.55, P.Steel, Mat.Metal, { Decor = true })
			piston:SetAttribute("AnimatedPiston", true)
		end
		Kit.vcyl(m, C(1.4, 4.4, 1), 2.2, 0.35, P.Black, Mat.Metal, { Decor = true })
		Kit.box(m, C(0, 3.65, -1.55), V(2.4, 0.25, 0.4), P.Black, Mat.Metal, { Decor = true })
		for i = 1, 4 do
			local l = Kit.box(m, C(-0.9 + (i - 1) * 0.6, 3.65, -1.8), V(0.35, 0.35, 0.2), Color3.fromRGB(45, 40, 30), Mat.Glass, { Decor = true })
			l:SetAttribute("ProgressLight", i)
		end
		local bulb = Kit.ball(m, C(1.2, 5.3, -0.6), 1.1, Color3.fromRGB(60, 60, 50), Mat.Glass, { Decor = true })
		bulb:SetAttribute("Bulb", true)
		local light = Kit.pointLight(bulb, Color3.fromRGB(255, 230, 150), 28, 3, true)
		light.Enabled = false
		local fx = Instance.new("Attachment")
		fx.Name = "FX"
		fx.Position = V(0, 1.8, 0)
		fx.Parent = body
		m:SetAttribute("Progress", 0)
		m:SetAttribute("Done", false)
		m:SetAttribute("Regressing", false)
		return m
	end,
}

------------------------------------------------------------------------
-- Крюк
------------------------------------------------------------------------

T.Hook = {
	Variants = 2,
	Build = function(rng: Random)
		local m = base("Hook", "Hook")
		local red = Kit.jitter(Color3.fromRGB(95, 25, 20), 0.05, rng)
		local pole = Kit.box(m, C(0, 6, 0), V(0.9, 12, 0.9), red, Mat.CorrodedMetal)
		pole.Name = "Pole"
		Kit.setOrigin(m, pole)
		Kit.box(m, C(0, 0.4, 0) * A(0, 20, 0), V(2.6, 0.8, 2.6), Color3.fromRGB(70, 65, 60), Mat.Slate)
		Kit.box(m, C(0, 11.4, -2), V(0.7, 0.7, 4.4), red, Mat.CorrodedMetal)
		Kit.box(m, C(0, 10.3, -1) * A(-45, 0, 0), V(0.4, 0.4, 3), red, Mat.CorrodedMetal, { Decor = true })
		Kit.chain(m, { V(0, 11, -3.9), V(0, 9.4, -3.9) }, 0.4, Color3.fromRGB(80, 80, 80))
		Kit.arc(m, C(0, 8.6, -3.5) * A(0, 90, 0), 0.45, 180, 360, 5, 0.22, P.Steel, Mat.Metal, { Decor = true })
		Kit.vcyl(m, C(0, 0.03, -3.9), 0.05, 2.6, P.Blood, Mat.SmoothPlastic, { Decor = true })
		local hp = Kit.box(m, C(0.25, 7, -4.3), V(1, 1, 1), P.Black, Mat.SmoothPlastic, { Decor = true, Transparency = 1 })
		hp.Name = "HangPoint"
		m:SetAttribute("Occupant", 0)
		return m
	end,
}

-- Лапы Сущности вокруг висящего (hangPoint — мировой CFrame точки HangPoint)
function MapProps.entityLegs(hangPoint: CFrame): Model
	local m = Kit.model("EntityLegs")
	for i = 1, 6 do
		local angle = (i / 6) * math.pi * 2
		local basePos = hangPoint.Position + V(math.cos(angle) * 3.5, 5, math.sin(angle) * 3.5)
		local look = CFrame.lookAt(basePos, hangPoint.Position + V(0, 1, 0))
		Kit.box(m, look * C(0, 0, -3.5), V(0.35, 0.35, 7), Color3.fromRGB(25, 10, 10), Mat.Slate, { Decor = true })
		Kit.box(m, look * C(0, 0, -7.4), V(0.2, 0.2, 1.4), Color3.fromRGB(200, 40, 20), Mat.Neon, { Decor = true })
	end
	return m
end

------------------------------------------------------------------------
-- Паллета (собирается в ОПУЩЕННОМ положении: хитбокс в начале координат, длинная сторона по X)
------------------------------------------------------------------------

T.Pallet = {
	Variants = 3,
	Build = function(rng: Random)
		local m = base("Pallet", "Pallet")
		local hitbox = Kit.box(m, CFrame.identity, V(5.6, 3, 1.2), P.Black, Mat.SmoothPlastic, { Transparency = 1, CanCollide = false })
		hitbox.Name = "Hitbox"
		Kit.setOrigin(m, hitbox)
		local wood = Kit.jitter(Color3.fromRGB(150, 112, 66), 0.06, rng)
		for i = 0, 3 do
			for _, z in { -0.45, 0.45 } do
				Kit.box(m, C(0, -1.15 + i * 0.77, z), V(5.6, 0.55, 0.2), Kit.jitter(wood, 0.08, rng), Mat.WoodPlanks, { Decor = true })
			end
		end
		for _, x in { -2.4, 0, 2.4 } do
			Kit.box(m, C(x, 0, 0), V(0.5, 3, 0.7), Kit.dark(wood, 0.25), Mat.Wood, { Decor = true })
		end
		m:SetAttribute("State", "Up")
		return m
	end,
}

------------------------------------------------------------------------
-- Шкафчик (опора — пол в центре, дверь спереди -Z)
------------------------------------------------------------------------

T.Locker = {
	Variants = 2,
	Build = function(rng: Random)
		local m = base("Locker", "Locker")
		local metal = Kit.jitter(Color3.fromRGB(70, 85, 80), 0.05, rng)
		local back = Kit.box(m, C(0, 3.6, 1.2), V(3, 7.2, 0.2), metal, Mat.CorrodedMetal)
		back.Name = "Back"
		Kit.setOrigin(m, back)
		for _, x in { -1.5, 1.5 } do
			Kit.box(m, C(x, 3.6, 0), V(0.2, 7.2, 2.6), metal, Mat.CorrodedMetal)
		end
		Kit.box(m, C(0, 7.3, 0), V(3.2, 0.2, 2.6), metal, Mat.CorrodedMetal)
		Kit.box(m, C(0, 0.1, 0), V(3, 0.2, 2.6), metal, Mat.CorrodedMetal)
		local closed = C(0, 3.6, -1.3)
		local hinge = C(-1.4, 3.6, -1.3)
		local open = Kit.aroundHinge(closed, hinge, A(0, -100, 0))
		local door = Kit.box(m, closed, V(2.8, 7, 0.15), metal:Lerp(Color3.new(1, 1, 1), 0.08), Mat.CorrodedMetal)
		door.Name = "Door"
		Kit.movable(m, door, "LockerDoor", closed, open)
		for i = 1, 4 do
			local off = C(0, 2.6 - i * 0.3, -0.1)
			local slit = Kit.box(m, closed * off, V(1.6, 0.12, 0.05), P.Black, Mat.SmoothPlastic, { Decor = true })
			Kit.movable(m, slit, "LockerDoor", closed * off, open * off)
		end
		local inside = Kit.box(m, C(0, 3, 0.2), V(1, 1, 1), P.Black, Mat.SmoothPlastic, { Decor = true, Transparency = 1 })
		inside.Name = "Inside"
		m:SetAttribute("Occupant", 0)
		return m
	end,
}

------------------------------------------------------------------------
-- Тотем
------------------------------------------------------------------------

local function buildTotem(rng: Random, hex: boolean): Model
	local m = base(hex and "HexTotem" or "Totem", "Totem")
	local root = Kit.box(m, C(0, 0.3, 0) * A(0, 30, 0), V(2.4, 0.6, 2.4), Color3.fromRGB(60, 50, 40), Mat.Ground)
	root.Name = "Base"
	Kit.setOrigin(m, root)
	for _ = 1, 9 do
		Kit.cyl(
			m,
			C(rng:NextNumber(-0.8, 0.8), rng:NextNumber(0.6, 1.8), rng:NextNumber(-0.8, 0.8)) * A(rng:NextNumber(-60, 60), rng:NextNumber(0, 180), rng:NextNumber(-60, 60)),
			rng:NextNumber(0.8, 1.6),
			0.25,
			P.Bone,
			Mat.SmoothPlastic,
			{ Decor = true }
		)
	end
	Kit.box(m, C(0, 2, 0), V(0.3, 3.2, 0.3), P.DarkWood, Mat.Wood, { Decor = true })
	local skullCF = C(0, 3.5, 0)
	local fallen = C(0.6, 0.9, 0) * A(0, 0, 80)
	local skull = Kit.ball(m, skullCF, 1.1, P.Bone, Mat.SmoothPlastic, { Decor = true })
	skull.Name = "Skull"
	Kit.movable(m, skull, "Skull", skullCF, fallen)
	for _, x in { -0.22, 0.22 } do
		local off = C(x, 0.08, -0.43)
		local eye = Kit.ball(m, skullCF * off, 0.3, hex and Color3.fromRGB(255, 60, 20) or P.Black, hex and Mat.Neon or Mat.SmoothPlastic, { Decor = true })
		eye:SetAttribute("SkullEye", true)
		Kit.movable(m, eye, "Skull", skullCF * off, fallen * off)
	end
	for i = 1, 5 do
		local angle = i / 5 * math.pi * 2
		local h = rng:NextNumber(0.4, 0.9)
		local pos = V(math.cos(angle) * 1.4, 0.6 + h / 2, math.sin(angle) * 1.4)
		Kit.vcyl(m, C(pos), h, 0.25, P.Wax, Mat.SmoothPlastic, { Decor = true })
		if hex then
			local flame = Kit.box(m, C(pos + V(0, h / 2 + 0.12, 0)), V(0.12, 0.25, 0.12), P.Flame, Mat.Neon, { Decor = true })
			flame:SetAttribute("HexFlame", true)
			if i == 1 then
				Kit.pointLight(flame, Color3.fromRGB(255, 120, 50), 10, 2)
			end
		end
	end
	m:SetAttribute("Hex", hex)
	m:SetAttribute("Progress", 0)
	m:SetAttribute("Cleansed", false)
	return m
end

T.Totem = {
	Variants = 3,
	Build = function(rng: Random)
		return buildTotem(rng, false)
	end,
}
T.HexTotem = {
	Variants = 1,
	Build = function(rng: Random)
		return buildTotem(rng, true)
	end,
}

------------------------------------------------------------------------
-- Сундук
------------------------------------------------------------------------

T.Chest = {
	Variants = 2,
	Build = function(rng: Random)
		local m = base("Chest", "Chest")
		local box = Kit.box(m, C(0, 0.8, 0), V(3, 1.6, 2), Kit.jitter(P.Wood, 0.06, rng), Mat.WoodPlanks)
		box.Name = "Box"
		Kit.setOrigin(m, box)
		local closed = C(0, 1.85, 0)
		local hinge = C(0, 2.1, 1.05)
		local lid = Kit.box(m, closed, V(3.1, 0.5, 2.1), P.DarkWood, Mat.WoodPlanks)
		lid.Name = "Lid"
		Kit.movable(m, lid, "ChestLid", closed, Kit.aroundHinge(closed, hinge, A(70, 0, 0)))
		for _, x in { -1, 1 } do
			Kit.box(m, C(x, 1.1, 0), V(0.25, 2.2, 2.15), P.Steel, Mat.Metal, { Decor = true })
		end
		Kit.box(m, C(0, 1.5, -1.08), V(0.4, 0.5, 0.15), Color3.fromRGB(180, 150, 60), Mat.Metal, { Decor = true })
		local glow = Kit.pointLight(box, Color3.fromRGB(255, 220, 140), 6, 1)
		glow.Name = "Glow"
		glow.Enabled = false
		m:SetAttribute("Opened", false)
		return m
	end,
}

------------------------------------------------------------------------
-- Люк
------------------------------------------------------------------------

T.Hatch = {
	Variants = 1,
	Build = function(_rng: Random)
		local m = base("Hatch", "Hatch")
		local frame = Kit.box(m, C(0, 0.15, 0), V(4.4, 0.3, 4.4), P.Rust, Mat.CorrodedMetal, { CanCollide = false })
		frame.Name = "Frame"
		Kit.setOrigin(m, frame)
		Kit.box(m, C(0, 0.32, 0), V(3.6, 0.1, 3.6), P.Black, Mat.SmoothPlastic, { Decor = true })
		for _, x in { -0.9, 0.9 } do
			local closed = C(x, 0.42, 0)
			local hinge = C(x * 2, 0.42, 0)
			local sign = x > 0 and 1 or -1
			local door = Kit.box(m, closed, V(1.8, 0.15, 3.6), P.Steel, Mat.DiamondPlate, { Decor = true })
			Kit.movable(m, door, "HatchDoor", closed, Kit.aroundHinge(closed, hinge, A(0, 0, -100 * sign)))
		end
		local glow = Kit.pointLight(frame, Color3.fromRGB(180, 200, 255), 14, 2)
		glow.Name = "Glow"
		glow.Enabled = false
		m:SetAttribute("Open", false)
		m:SetAttribute("Closed", false)
		return m
	end,
}

------------------------------------------------------------------------
-- Медвежий капкан (CF0 — раскрыт/взведён, CF1 — захлопнут)
------------------------------------------------------------------------

T.Trap = {
	Variants = 1,
	Build = function(_rng: Random)
		local m = base("BearTrap", "Trap")
		local plate = Kit.vcyl(m, C(0, 0.08, 0), 0.15, 1.2, Color3.fromRGB(70, 65, 60), Mat.CorrodedMetal, { CanCollide = false })
		plate.Name = "Plate"
		Kit.setOrigin(m, plate)
		for i = 1, 2 do
			local side = i == 1 and -1 or 1
			local armed = C(0, 0.12, side * 0.85)
			local sprung = C(0, 0.55, side * 0.18) * A(side * 75, 0, 0)
			local jaw = Kit.box(m, armed, V(2.2, 0.12, 0.7), Color3.fromRGB(110, 105, 100), Mat.Metal, { Decor = true })
			Kit.movable(m, jaw, "TrapJaw", armed, sprung)
			for t = -2, 2 do
				local off = C(t * 0.45, 0.2, -side * 0.3)
				local tooth = Kit.box(m, armed * off, V(0.14, 0.4, 0.14), Color3.fromRGB(150, 145, 140), Mat.Metal, { Decor = true })
				Kit.movable(m, tooth, "TrapJaw", armed * off, sprung * off)
			end
		end
		Kit.box(m, C(0, 0.06, 1.4), V(0.12, 0.12, 2), P.Black, Mat.Metal, { Decor = true })
		m:SetAttribute("Armed", true)
		m:SetAttribute("Caught", 0)
		return m
	end,
}

------------------------------------------------------------------------
-- Ворона
------------------------------------------------------------------------

T.Crow = {
	Variants = 1,
	Build = function(_rng: Random)
		local m = base("Crow", "Crow")
		local black = Color3.fromRGB(15, 15, 18)
		local body = Kit.box(m, C(0, 0.35, 0), V(0.45, 0.45, 0.9), black, Mat.SmoothPlastic, { Decor = true })
		body.Name = "Body"
		Kit.setOrigin(m, body)
		Kit.ball(m, C(0, 0.65, -0.45), 0.38, black, Mat.SmoothPlastic, { Decor = true })
		Kit.box(m, C(0, 0.62, -0.72), V(0.1, 0.1, 0.3), Color3.fromRGB(60, 55, 40), Mat.SmoothPlastic, { Decor = true })
		for _, x in { -0.3, 0.3 } do
			Kit.box(m, C(x, 0.38, 0.05), V(0.12, 0.35, 0.75), black, Mat.SmoothPlastic, { Decor = true })
		end
		Kit.box(m, C(0, 0.4, 0.6) * A(15, 0, 0), V(0.3, 0.08, 0.45), black, Mat.SmoothPlastic, { Decor = true })
		return m
	end,
}

------------------------------------------------------------------------
-- Ворота выхода (опора — центр проёма на линии стены; -Z внутрь карты, +Z наружу)
------------------------------------------------------------------------

T.ExitGate = {
	Variants = 1,
	Build = function(_rng: Random)
		local m = base("ExitGate", "ExitGate")
		local frameTop = Kit.box(m, C(0, 14.75, 0), V(16, 2.5, 2.5), Color3.fromRGB(40, 40, 40), Mat.Metal)
		frameTop.Name = "Frame"
		Kit.setOrigin(m, frameTop)
		local metal = Color3.fromRGB(60, 60, 65)
		local closed = C(0, 6, 0)
		local open = C(0, 17.8, 0)
		local door = Kit.box(m, closed, V(12, 12, 1), metal, Mat.DiamondPlate)
		door.Name = "Door"
		Kit.movable(m, door, "GateDoor", closed, open)
		for i = -2, 2 do
			local off = C(i * 2.4, 0, 0)
			local rib = Kit.box(m, closed * off, V(0.4, 12, 1.3), Kit.dark(metal, 0.3), Mat.Metal, { Decor = true })
			Kit.movable(m, rib, "GateDoor", closed * off, open * off)
		end
		for _, x in { -7, 7 } do
			Kit.box(m, C(x, 8, 0), V(2, 16, 2.5), Color3.fromRGB(50, 48, 46), Mat.Concrete)
		end
		local switch = Kit.box(m, C(10, 2, -2.2), V(2.2, 4, 1.4), Color3.fromRGB(50, 50, 50), Mat.Metal)
		switch.Name = "Switch"
		local pivot = switch.CFrame * C(0, 0.6, -0.8)
		Kit.box(m, pivot, V(0.5, 0.5, 0.5), P.Black, Mat.Metal, { Decor = true })
		local lever = Kit.box(m, pivot, V(0.25, 1.6, 0.25), Color3.fromRGB(150, 30, 30), Mat.Metal, { Decor = true })
		lever.Name = "Lever"
		Kit.movable(m, lever, "GateLever", pivot * A(-35, 0, 0) * C(0, 0.7, 0), pivot * A(35, 0, 0) * C(0, 0.7, 0))
		for i = 1, 3 do
			local lamp = Kit.box(m, switch.CFrame * C(-0.6 + (i - 1) * 0.6, 1.5, -0.75), V(0.5, 0.5, 0.3), Color3.fromRGB(40, 0, 0), Mat.Neon, { Decor = true })
			lamp:SetAttribute("GateLamp", i)
		end
		local siren = Kit.ball(m, C(-7, 16.5, -1), 1, Color3.fromRGB(80, 10, 10), Mat.Glass, { Decor = true })
		siren.Name = "Siren"
		local sirenLight = Kit.spotLight(siren, Color3.fromRGB(255, 30, 20), 30, 60, 4, Enum.NormalId.Front)
		sirenLight.Name = "SirenLight"
		sirenLight.Enabled = false
		-- Коридор за воротами и зона побега
		Kit.box(m, C(0, -0.5, 15.75), V(12, 1, 30), Color3.fromRGB(50, 45, 40), Mat.Ground)
		for _, x in { -6.75, 6.75 } do
			Kit.box(m, C(x, 6, 15.75), V(1.5, 12, 30), P.Concrete, Mat.Concrete)
		end
		local escape = Kit.box(m, C(0, 6, 24), V(12, 12, 10), Color3.new(1, 1, 1), Mat.ForceField, { Decor = true, Transparency = 0.6 })
		escape.Name = "EscapeZone"
		Kit.pointLight(escape, Color3.new(1, 1, 1), 40, 2)
		m:SetAttribute("Powered", false)
		m:SetAttribute("Progress", 0)
		m:SetAttribute("Open", false)
		return m
	end,
}

return MapProps
