-- Контракт моделей: что игровая логика ожидает от каждой модели.
-- Тесты проверяют каждый шаблон через Contract.check.
local Contract = {}

-- Бюджеты деталей (ПК + телефоны)
Contract.Budget = {
	Generator = 75,
	Hook = 50,
	Pallet = 26,
	Locker = 40,
	Totem = 45,
	HexTotem = 50,
	Chest = 30,
	Hatch = 30,
	Trap = 32,
	Crow = 14,
	ExitGate = 130,
}

local function hasAttr(inst: Instance, name: string): boolean
	return inst:GetAttribute(name) ~= nil
end

local function countAttr(model: Instance, name: string): number
	local n = 0
	for _, d in model:GetDescendants() do
		if d:GetAttribute(name) ~= nil then
			n += 1
		end
	end
	return n
end

local function groupCount(model: Instance, group: string): number
	local n = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("FX") == group then
			n += 1
			if not (d:GetAttribute("CF0") and d:GetAttribute("CF1")) then
				return -1
			end
		end
	end
	return n
end

local function child(model: Instance, name: string, className: string?): Instance?
	local c = model:FindFirstChild(name, true)
	if c and className and not c:IsA(className) then
		return nil
	end
	return c
end

local function partCount(model: Instance): number
	local n = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

local function hasLight(model: Instance, name: string?): boolean
	for _, d in model:GetDescendants() do
		if d:IsA("Light") and (name == nil or d.Name == name) then
			return true
		end
	end
	return false
end

-- Проверяет модель шаблона. Возвращает список ошибок (пустой = всё хорошо).
function Contract.check(name: string, model: Model): { string }
	local errors = {}
	local function need(cond: boolean, msg: string)
		if not cond then
			table.insert(errors, name .. ": " .. msg)
		end
	end
	need(model:IsA("Model"), "должна быть Model")
	need(model.PrimaryPart ~= nil, "нужен PrimaryPart")
	if model.PrimaryPart then
		need(model.PrimaryPart:GetAttribute("FX") == nil or name == "Pallet", "PrimaryPart не должен быть подвижным")
	end
	local kind = model:GetAttribute("Kind")
	local budget = Contract.Budget[name]
	if budget then
		need(partCount(model) <= budget, ("деталей %d > бюджет %d"):format(partCount(model), budget))
	end

	if name == "Generator" then
		need(kind == "Generator", "Kind=Generator")
		for _, a in { "Progress", "Done", "Regressing" } do
			need(hasAttr(model, a), "атрибут " .. a)
		end
		need(countAttr(model, "ProgressLight") >= 4, "4 детали ProgressLight")
		need(countAttr(model, "Bulb") >= 1, "деталь Bulb")
		need(child(model, "FX", "Attachment") ~= nil, "Attachment FX")
		need(model.PrimaryPart ~= nil and model.PrimaryPart.CanCollide, "PrimaryPart сталкивается")
	elseif name == "Hook" then
		need(kind == "Hook", "Kind=Hook")
		need(model:GetAttribute("Occupant") == 0, "Occupant=0")
		need(child(model, "HangPoint", "BasePart") ~= nil, "деталь HangPoint")
	elseif name == "Pallet" then
		need(kind == "Pallet", "Kind=Pallet")
		need(model:GetAttribute("State") == "Up", "State=Up")
		local hb = model.PrimaryPart
		need(hb ~= nil and hb.Name == "Hitbox", "PrimaryPart = Hitbox")
		if hb then
			need((hb.Size - Vector3.new(5.6, 3, 1.2)).Magnitude < 0.05, "Hitbox 5.6x3x1.2")
			need(hb.CanCollide == false, "Hitbox изначально не сталкивается")
		end
	elseif name == "Locker" then
		need(kind == "Locker", "Kind=Locker")
		need(model:GetAttribute("Occupant") == 0, "Occupant=0")
		need(child(model, "Inside", "BasePart") ~= nil, "деталь Inside")
		need(groupCount(model, "LockerDoor") > 0, "группа LockerDoor с CF0/CF1")
	elseif name == "Totem" or name == "HexTotem" then
		need(kind == "Totem", "Kind=Totem")
		need(hasAttr(model, "Hex") and hasAttr(model, "Progress") and hasAttr(model, "Cleansed"), "атрибуты Hex/Progress/Cleansed")
		need(groupCount(model, "Skull") > 0, "группа Skull с CF0/CF1")
		if name == "HexTotem" then
			need(model:GetAttribute("Hex") == true, "Hex=true")
			need(countAttr(model, "HexFlame") > 0, "огни HexFlame")
		end
	elseif name == "Chest" then
		need(kind == "Chest", "Kind=Chest")
		need(model:GetAttribute("Opened") == false, "Opened=false")
		need(groupCount(model, "ChestLid") > 0, "группа ChestLid")
		need(hasLight(model, "Glow"), "PointLight Glow")
	elseif name == "Hatch" then
		need(kind == "Hatch", "Kind=Hatch")
		need(model:GetAttribute("Open") == false and model:GetAttribute("Closed") == false, "Open/Closed=false")
		need(groupCount(model, "HatchDoor") > 0, "группа HatchDoor")
		need(hasLight(model, "Glow"), "PointLight Glow")
	elseif name == "Trap" then
		need(kind == "Trap", "Kind=Trap")
		need(model:GetAttribute("Armed") == true and model:GetAttribute("Caught") == 0, "Armed=true, Caught=0")
		need(groupCount(model, "TrapJaw") > 0, "группа TrapJaw")
	elseif name == "Crow" then
		need(kind == "Crow", "Kind=Crow")
	elseif name == "ExitGate" then
		need(kind == "ExitGate", "Kind=ExitGate")
		for _, a in { "Powered", "Progress", "Open" } do
			need(hasAttr(model, a), "атрибут " .. a)
		end
		need(child(model, "Switch", "BasePart") ~= nil, "деталь Switch")
		need(child(model, "EscapeZone", "BasePart") ~= nil, "деталь EscapeZone")
		need(child(model, "Siren", "BasePart") ~= nil, "деталь Siren")
		need(hasLight(model, "SirenLight"), "SpotLight SirenLight")
		need(countAttr(model, "GateLamp") >= 3, "3 лампы GateLamp")
		need(groupCount(model, "GateDoor") > 0, "группа GateDoor")
		need(groupCount(model, "GateLever") > 0, "группа GateLever")
	end
	return errors
end

return Contract
