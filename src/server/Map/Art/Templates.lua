-- Реестр шаблонов объектов. Каждый объект строится ОДИН раз (с CSG) в начале работы сервера
-- в нескольких вариантах, хранится в ServerStorage, а на карту попадают копии (Clone + PivotTo).
local ServerStorage = game:GetService("ServerStorage")

local MapProps = require(script.Parent.MapProps)

local Templates = {}

export type Def = {
	Build: (rng: Random, variant: number) -> Model,
	Variants: number?,
}

local defs: { [string]: Def } = {}
local built: { [string]: { Model } } = {}

local storage: Folder?

local function getStorage(): Folder
	if storage and storage.Parent then
		return storage
	end
	local f = ServerStorage:FindFirstChild("PropTemplates") :: Folder?
	if not f then
		f = Instance.new("Folder")
		f.Name = "PropTemplates"
		f.Parent = ServerStorage
	end
	storage = f
	return f :: Folder
end

function Templates.register(name: string, def: Def)
	defs[name] = def
end

for name, def in MapProps.Templates do
	Templates.register(name, def)
end

function Templates.names(): { string }
	local list = {}
	for name in defs do
		table.insert(list, name)
	end
	table.sort(list)
	return list
end

-- Построить все варианты шаблона (CSG требует, чтобы детали были в workspace — строим в «мастерской» под картой)
function Templates.build(name: string): { Model }
	if built[name] then
		return built[name]
	end
	local def = defs[name]
	assert(def, "нет шаблона " .. name)
	local list = {}
	local workshop = Instance.new("Model")
	workshop.Name = "TemplateWorkshop"
	workshop.Parent = workspace
	for v = 1, def.Variants or 1 do
		local rng = Random.new(v * 7919 + #name * 131)
		local model = def.Build(rng, v)
		model.Name = name
		model.Parent = workshop
		model:SetAttribute("Template", name)
		model.Parent = getStorage()
		table.insert(list, model)
	end
	workshop:Destroy()
	built[name] = list
	return list
end

function Templates.prebuild()
	for name in defs do
		Templates.build(name)
	end
end

-- Поставить копию шаблона. cframe — опора модели (земля в центре, -Z = «перед»).
function Templates.spawn(name: string, cframe: CFrame, parent: Instance, rng: Random?): Model
	local list = Templates.build(name)
	local index = rng and rng:NextInteger(1, #list) or 1
	local model = list[index]:Clone()
	model:PivotTo(cframe)
	model:SetAttribute("Origin", cframe)
	model.Parent = parent
	return model
end

-- Для тестов: последний построенный вариант (без копирования)
function Templates.get(name: string, variant: number?): Model
	local list = Templates.build(name)
	return list[variant or 1]
end

return Templates
