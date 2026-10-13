-- Визуальные состояния объектов карты. Игровые системы вызывают только эти функции,
-- поэтому внутреннее устройство моделей (Art/*) можно менять свободно.
--
-- Соглашения для моделей (проверяются Art/Contract.lua):
--   * подвижные детали: атрибуты FX = "<группа>", CF0/CF1 = положения относительно model:GetPivot()
--     (см. Kit.movable). Группы: LockerDoor, HatchDoor, TrapJaw, ChestLid, GateDoor, GateLever, Skull.
--   * генератор: детали с атрибутом ProgressLight = 1..4, деталь с атрибутом Bulb (внутри PointLight),
--     Attachment "FX" (точка для искр/дыма), детали поршней — атрибут AnimatedPiston (анимирует клиент).
--   * ворота: детали GateLamp = 1..3, деталь "Siren" с SpotLight "SirenLight", деталь "Switch".
--   * тотем: детали HexFlame (гаснут), SkullEye (темнеют), группа Skull (череп падает).
--   * люк/сундук: PointLight с именем "Glow" где-нибудь внутри модели.
local TweenService = game:GetService("TweenService")

local Kit = require(script.Parent.Art.Kit)
local MapProps = require(script.Parent.Art.MapProps)

local PropFX = {}

------------------------------------------------------------------------
-- Общие подвижные группы
------------------------------------------------------------------------

function PropFX.parts(model: Instance, group: string): { BasePart }
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("FX") == group then
			table.insert(out, d)
		end
	end
	return out
end

function PropFX.setGroup(model: Model, group: string, alpha: number)
	local pivot = model:GetPivot()
	for _, part in PropFX.parts(model, group) do
		local cf0 = part:GetAttribute("CF0") :: CFrame?
		local cf1 = part:GetAttribute("CF1") :: CFrame?
		if cf0 and cf1 then
			part.CFrame = (pivot * cf0):Lerp(pivot * cf1, math.clamp(alpha, 0, 1))
		end
	end
	model:SetAttribute("FX_" .. group, alpha)
end

-- Плавно перевести группу в состояние alpha (сервер, все видят)
function PropFX.tweenGroup(model: Model, group: string, alpha: number, duration: number, style: Enum.EasingStyle?): Tween?
	local from = (model:GetAttribute("FX_" .. group) :: number?) or 0
	local value = Instance.new("NumberValue")
	value.Value = from
	value.Changed:Connect(function(v)
		if model.Parent then
			PropFX.setGroup(model, group, v)
		end
	end)
	local tw = TweenService:Create(value, TweenInfo.new(duration, style or Enum.EasingStyle.Quad), { Value = alpha })
	tw.Completed:Connect(function()
		if model.Parent then
			PropFX.setGroup(model, group, alpha)
		end
		value:Destroy()
	end)
	tw:Play()
	return tw
end

local function findLight(model: Instance, name: string): Light?
	for _, d in model:GetDescendants() do
		if d:IsA("Light") and d.Name == name then
			return d
		end
	end
	return nil
end

------------------------------------------------------------------------
-- Генератор
------------------------------------------------------------------------

local LIGHT_OFF = Color3.fromRGB(45, 40, 30)
local LIGHT_ON = Color3.fromRGB(255, 220, 120)

function PropFX.genProgress(gen: Model, progress: number)
	for _, d in gen:GetDescendants() do
		local i = d:GetAttribute("ProgressLight")
		if i and d:IsA("BasePart") then
			local on = progress >= (i :: number) / 4 - 0.001
			d.Color = on and LIGHT_ON or LIGHT_OFF
			d.Material = on and Enum.Material.Neon or Enum.Material.Glass
		end
	end
end

function PropFX.genDone(gen: Model)
	PropFX.genProgress(gen, 1)
	for _, d in gen:GetDescendants() do
		if d:GetAttribute("Bulb") and d:IsA("BasePart") then
			d.Color = Color3.fromRGB(255, 230, 140)
			d.Material = Enum.Material.Neon
			for _, l in d:GetChildren() do
				if l:IsA("Light") then
					l.Enabled = true
				end
			end
		end
	end
end

local function fxAttachment(model: Model): Attachment?
	for _, d in model:GetDescendants() do
		if d:IsA("Attachment") and d.Name == "FX" then
			return d
		end
	end
	return nil
end

-- Взрыв при проваленной проверке навыка: искры и дым
function PropFX.genExplode(gen: Model)
	local att = fxAttachment(gen)
	if not att then
		return
	end
	local sparks = att:FindFirstChild("Sparks") :: ParticleEmitter?
	if not sparks then
		sparks = Kit.emitter(att, "Sparks")
		sparks.Enabled = false
	end
	local smoke = att:FindFirstChild("Smoke") :: ParticleEmitter?
	if not smoke then
		smoke = Kit.emitter(att, "Smoke", 1.4)
		smoke.Enabled = false
	end
	;(sparks :: ParticleEmitter):Emit(45)
	local s = smoke :: ParticleEmitter
	s.Enabled = true
	task.delay(2.5, function()
		if s.Parent then
			s.Enabled = false
		end
	end)
end

------------------------------------------------------------------------
-- Ворота
------------------------------------------------------------------------

function PropFX.gateProgress(gate: Model, progress: number)
	for _, d in gate:GetDescendants() do
		local i = d:GetAttribute("GateLamp")
		if i and d:IsA("BasePart") then
			local on = progress >= (i :: number) / 3
			d.Color = on and Color3.fromRGB(255, 40, 40) or Color3.fromRGB(40, 0, 0)
			d.Material = Enum.Material.Neon
		end
	end
	PropFX.setGroup(gate, "GateLever", progress)
end

function PropFX.gatePowered(gate: Model)
	local sw = gate:FindFirstChild("Switch", true) :: BasePart?
	if sw then
		sw.Color = Color3.fromRGB(150, 130, 40)
	end
	for _, d in gate:GetDescendants() do
		if d:GetAttribute("PowerLight") and d:IsA("BasePart") then
			d.Material = Enum.Material.Neon
			d.Color = Color3.fromRGB(255, 200, 90)
		end
	end
end

function PropFX.gateSiren(gate: Model, on: boolean)
	local siren = gate:FindFirstChild("Siren", true)
	local light = siren and siren:FindFirstChild("SirenLight") :: Light?
	if light then
		light.Enabled = on
	end
	if siren and siren:IsA("BasePart") then
		siren.Material = on and Enum.Material.Neon or Enum.Material.Glass
		siren.Color = on and Color3.fromRGB(255, 40, 30) or Color3.fromRGB(80, 10, 10)
	end
end

function PropFX.gateOpen(gate: Model)
	PropFX.gateProgress(gate, 1)
	for _, p in PropFX.parts(gate, "GateDoor") do
		p.CanCollide = false
	end
	PropFX.tweenGroup(gate, "GateDoor", 1, 2.5)
end

------------------------------------------------------------------------
-- Шкафчик, люк, капкан, сундук
------------------------------------------------------------------------

function PropFX.lockerDoor(locker: Model, alpha: number)
	PropFX.setGroup(locker, "LockerDoor", alpha)
end

-- Открыть дверь и закрыть через holdTime
function PropFX.swingLockerDoor(locker: Model, holdTime: number, onSound: (() -> ())?)
	PropFX.tweenGroup(locker, "LockerDoor", 1, 0.2)
	if onSound then
		onSound()
	end
	task.delay(0.2 + holdTime, function()
		if locker.Parent then
			PropFX.tweenGroup(locker, "LockerDoor", 0, 0.25)
			if onSound then
				task.delay(0.25, onSound)
			end
		end
	end)
end

function PropFX.hatch(hatch: Model, open: boolean)
	PropFX.tweenGroup(hatch, "HatchDoor", open and 1 or 0, 0.6, Enum.EasingStyle.Back)
	local glow = findLight(hatch, "Glow")
	if glow then
		glow.Enabled = open
	end
end

-- armed = true: челюсти раскрыты (CF0), false: захлопнуты (CF1)
function PropFX.trap(trap: Model, armed: boolean)
	PropFX.setGroup(trap, "TrapJaw", armed and 0 or 1)
end

function PropFX.chestOpen(chest: Model)
	PropFX.tweenGroup(chest, "ChestLid", 1, 0.5, Enum.EasingStyle.Back)
	local glow = findLight(chest, "Glow")
	if glow then
		glow.Enabled = true
	end
end

------------------------------------------------------------------------
-- Тотем
------------------------------------------------------------------------

function PropFX.totemCleansed(totem: Model)
	for _, d in totem:GetDescendants() do
		if d:GetAttribute("HexFlame") then
			d:Destroy()
		elseif d:GetAttribute("SkullEye") and d:IsA("BasePart") then
			d.Color = Color3.fromRGB(20, 20, 22)
			d.Material = Enum.Material.SmoothPlastic
		end
	end
	PropFX.tweenGroup(totem, "Skull", 1, 0.6, Enum.EasingStyle.Bounce)
end

------------------------------------------------------------------------
-- Паллета
------------------------------------------------------------------------

local function tweenModel(model: Model, target: CFrame, duration: number)
	local value = Instance.new("CFrameValue")
	value.Value = model:GetPivot()
	value.Changed:Connect(function(cf)
		if model.Parent then
			model:PivotTo(cf)
		end
	end)
	local tw = TweenService:Create(value, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = target })
	tw.Completed:Connect(function()
		if model.Parent then
			model:PivotTo(target)
		end
		value:Destroy()
	end)
	tw:Play()
end

function PropFX.palletDrop(pallet: Model)
	local dropCF = pallet:GetAttribute("DropCFrame") :: CFrame
	local hitbox = pallet.PrimaryPart
	if hitbox then
		hitbox.CanCollide = true
	end
	tweenModel(pallet, dropCF, 0.25)
end

-- Обломки разлетаются и исчезают
function PropFX.palletBreak(pallet: Model, debrisParent: Instance?)
	for _, d in pallet:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.AssemblyLinearVelocity = Vector3.new(math.random(-15, 15), math.random(8, 18), math.random(-15, 15))
		end
	end
	if debrisParent then
		pallet.Parent = debrisParent
	end
	task.delay(2, function()
		pallet:Destroy()
	end)
end

------------------------------------------------------------------------
-- Сущность на крюке
------------------------------------------------------------------------

PropFX.EntityBuilder = MapProps.entityLegs :: ((hangPoint: CFrame) -> Model)?

function PropFX.entity(hook: Model, on: boolean)
	local existing = hook:FindFirstChild("EntityLegs")
	if not on then
		if existing then
			existing:Destroy()
		end
		return
	end
	if existing then
		return
	end
	local hp = hook:FindFirstChild("HangPoint", true) :: BasePart?
	if not hp or not PropFX.EntityBuilder then
		return
	end
	local legs = PropFX.EntityBuilder(hp.CFrame)
	legs.Name = "EntityLegs"
	legs.Parent = hook
end

return PropFX
