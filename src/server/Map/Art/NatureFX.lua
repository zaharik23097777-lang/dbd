-- Огонь и туман: только частицы со встроенными текстурами и один тёплый свет.
local Kit = require(script.Parent.Kit)

local FX = {}

-- Невидимая деталь-источник для частиц
local function source(parent: Instance, name: string, cf: CFrame, size: Vector3): BasePart
	local p = Kit.box(parent, cf, size, Color3.new(0, 0, 0), Kit.Mat.SmoothPlastic, { Decor = true, Transparency = 1 })
	p.Name = name
	return p
end

local function attachment(parent: BasePart, offset: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Position = offset
	a.Parent = parent
	return a
end

-- Огонь: яркое ядро, языки пламени, искры, дым над огнём и тёплый неподвижный свет.
-- size — ширина очага (1 — бочка, 2-2.5 — костёр). Возвращает невидимую деталь-источник.
function FX.fire(parent: Instance, cf: CFrame, size: number): BasePart
	local p = source(parent, "FireSource", cf, Vector3.new(size, 0.4, size))
	local lift = math.sqrt(size) -- скорость подъёма: пламя костра ~2-3 стада, бочки ~1-1.5
	-- Ядро: маленькое, светлое, частое
	local core = Kit.emitter(p, "Fire", size * 0.7)
	core.Name = "FireCore"
	core.Color = ColorSequence.new(Color3.fromRGB(255, 214, 120), Color3.fromRGB(255, 120, 40))
	core.Lifetime = NumberRange.new(0.35, 0.7)
	core.Speed = NumberRange.new(1.2 * lift, 2.4 * lift)
	core.Rate = 24
	-- Языки: крупнее, темнее, выше, с лёгким сносом
	local flames = Kit.emitter(p, "Fire", size)
	flames.Name = "Flames"
	flames.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 150, 50)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(220, 70, 20)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 30, 10)),
	})
	flames.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.5, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	flames.Lifetime = NumberRange.new(0.6, 1.1)
	flames.Speed = NumberRange.new(1.5 * lift, 3 * lift)
	flames.Rate = 14
	flames.Acceleration = Vector3.new(0.4, 1.5, 0)
	-- Искры
	local embers = Kit.emitter(p, "Embers", size)
	embers.Rate = 4 + 3 * size
	-- Дым поднимается над языками пламени
	local smokeAt = attachment(p, Vector3.new(0, 1.6 * size, 0))
	local smoke = Kit.emitter(smokeAt, "Smoke", size * 0.8)
	smoke.Rate = 2 + size
	smoke.Color = ColorSequence.new(Color3.fromRGB(46, 42, 40), Color3.fromRGB(30, 30, 32))
	smoke.Acceleration = Vector3.new(0.6, 0.8, 0)
	-- Тёплый свет; тени — только у большого костра (там они окупаются)
	local light = Kit.pointLight(p, Color3.fromRGB(255, 136, 60), math.clamp(10 + 8 * size, 14, 30), 1.8, size >= 2)
	light.Name = "FireLight"
	return p
end

-- Туман у земли (одна деталь): медленные широкие клубы, иногда светлячки или пыль
function FX.fog(parent: Instance, pos: Vector3, rng: Random): BasePart
	local p = source(parent, "FogEmitter", CFrame.new(pos), Vector3.new(22, 1, 22))
	local fog = Kit.emitter(p, "Fog", rng:NextNumber(0.9, 1.3))
	fog.Color = ColorSequence.new(Color3.fromRGB(138, 146, 164), Color3.fromRGB(112, 118, 136))
	fog.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 0.84),
		NumberSequenceKeypoint.new(0.7, 0.88),
		NumberSequenceKeypoint.new(1, 1),
	})
	fog.Rate = rng:NextNumber(0.5, 0.8)
	fog.Lifetime = NumberRange.new(12, 18)
	fog.Acceleration = Vector3.new(rng:NextNumber(-0.06, 0.06), -0.02, rng:NextNumber(-0.06, 0.06))
	fog.LightInfluence = 0.7
	local roll = rng:NextNumber()
	if roll < 0.35 then
		local flies = Kit.emitter(p, "Fireflies")
		flies.Rate = rng:NextNumber(0.8, 1.6)
		flies.Acceleration = Vector3.new(0, 0.15, 0)
	elseif roll < 0.55 then
		-- Пыль/пыльца, медленно оседающая в свете фонарей
		local dust = Kit.emitter(p, "Dust", 0.4)
		dust.Rate = 2
		dust.Speed = NumberRange.new(0.1, 0.4)
		dust.Lifetime = NumberRange.new(5, 8)
		dust.Transparency = NumberSequence.new(0.75, 1)
		dust.Acceleration = Vector3.new(0, -0.05, 0)
		dust.LightInfluence = 0.8
	end
	return p
end

return FX
