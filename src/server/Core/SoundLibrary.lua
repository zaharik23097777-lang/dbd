-- Поиск настоящих звуков в публичной библиотеке Creator Store (AssetService:SearchAudioAsync).
-- Звуки и музыка Roblox из этой библиотеки бесплатны для любой игры.
-- Для каждого слота Sounds.List с полем Search ищем подходящие звуки и публикуем найденные ID
-- в ReplicatedStorage.SoundLibrary: атрибут <слот> = "rbxassetid://1,rbxassetid://2",
-- атрибут Version растёт при каждой публикации, Status = Searching / Ready / Offline / Disabled.
-- Поиск идёт в фоне и никогда не задерживает старт игры. Без доступа к поиску (Studio без сети,
-- эмулятор тестов) ничего не публикуется — клиенты играют встроенные звуки.
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(ReplicatedStorage.Shared.Sounds)

local SoundLibrary = {}

export type Candidate = {
	Id: string,
	Title: string,
	Duration: number?,
	Endorsed: boolean,
	Roblox: boolean, -- загружен самим Roblox
	Rank: number, -- место в выдаче поиска
}

-- Названия полей результата не задокументированы — пробуем несколько вариантов
local ID_KEYS = { "Id", "AssetId", "id", "assetId", "ID" }
local TITLE_KEYS = { "Title", "Name", "title", "name", "DisplayName" }
local DURATION_KEYS = { "Duration", "duration", "Length", "TimeLength" }
local ENDORSED_KEYS = { "IsEndorsed", "Endorsed", "isEndorsed", "endorsed" }

-- Названия, с которыми звук точно не подходит хоррору (совпадение с начала слова)
local BAD_WORDS = {
	"meme", "earrape", "ear rape", "bass boost", "remix", "funny", "oof", "phonk",
	"tiktok", "lyrics", "nightcore", "troll", "cartoon", "8 bit", "8-bit",
}
local SFX_BAD_WORDS = { "song", "music", "beat drop" }

local ROBLOX_USER_ID = 1

local loggedKeys = false
local warnedFormat = false
local started = false
local queryCache: { [string]: { any } } = {}

local function field(r: { [any]: any }, keys: { string }): any
	for _, k in keys do
		local v = r[k]
		if v ~= nil then
			return v
		end
	end
	return nil
end

local function normalizeId(v: any): string?
	if type(v) == "number" then
		return v > 0 and ("rbxassetid://" .. string.format("%d", v)) or nil
	elseif type(v) == "string" then
		local digits = v:match("^rbxassetid://(%d+)$") or v:match("^(%d+)$")
		return digits and ("rbxassetid://" .. digits) or nil
	end
	return nil
end

local function isRoblox(r: { [any]: any }): boolean
	local creator = r.Creator or r.creator
	if type(creator) == "table" then
		local id = tonumber(creator.Id or creator.id or creator.CreatorTargetId or creator.UserId)
		local name = creator.Name or creator.name
		if id == ROBLOX_USER_ID or name == "Roblox" then
			return true
		end
	end
	return tonumber(r.CreatorId or r.CreatorTargetId) == ROBLOX_USER_ID or r.CreatorName == "Roblox"
end

-- Читает один результат поиска; nil — если у него нет понятного ID
function SoundLibrary.readResult(r: any, rank: number): Candidate?
	if type(r) ~= "table" then
		return nil
	end
	local id = normalizeId(field(r, ID_KEYS))
	if not id then
		return nil
	end
	local endorsed = field(r, ENDORSED_KEYS)
	return {
		Id = id,
		Title = tostring(field(r, TITLE_KEYS) or ""),
		Duration = tonumber(field(r, DURATION_KEYS)),
		Endorsed = endorsed == true,
		Roblox = isRoblox(r),
		Rank = rank,
	}
end

-- Есть ли в названии слово, начинающееся с одного из words ("oof" не задевает "roof")
local function hasWord(title: string, words: { string }): boolean
	for _, w in words do
		if title:find("%f[%w]" .. (w:gsub("%p", "%%%0"))) then
			return true
		end
	end
	return false
end

-- Оценка кандидата; nil — не подходит (длительность, плохие слова)
function SoundLibrary.score(c: Candidate, spec: Sounds.Search, keyword: string, total: number): number?
	local d = c.Duration
	if d and ((spec.Min and d < spec.Min) or (spec.Max and d > spec.Max)) then
		return nil
	end
	local title = c.Title:lower()
	if hasWord(title, BAD_WORDS) or (spec.Avoid and hasWord(title, spec.Avoid)) then
		return nil
	end
	if not spec.Music and hasWord(title, SFX_BAD_WORDS) then
		return nil
	end
	local s = 0
	if c.Endorsed then
		s += 6
	end
	if c.Roblox then
		s += 4
	end
	for word in keyword:lower():gmatch("%a+") do
		if title:find(word, 1, true) then
			s += 1.5
		end
	end
	if not d then
		s -= 1 -- длительность неизвестна: чуть ниже проверенных
	end
	-- Порядок выдачи поиска (релевантность)
	return s + (1 - (c.Rank - 1) / math.max(total, 1)) * 2
end

-- Лучшие кандидаты из страницы результатов (без повторов ID), лучший первым
function SoundLibrary.pick(results: { any }, spec: Sounds.Search, keyword: string, count: number): { Candidate }
	local scored = {}
	for i, r in results do
		local c = SoundLibrary.readResult(r, i)
		if c then
			local s = SoundLibrary.score(c, spec, keyword, #results)
			if s then
				table.insert(scored, { C = c, S = s })
			end
		end
	end
	table.sort(scored, function(a, b)
		if a.S ~= b.S then
			return a.S > b.S
		end
		return a.C.Rank < b.C.Rank
	end)
	local out, seen = {}, {}
	for _, e in scored do
		if #out >= count then
			break
		end
		if not seen[e.C.Id] then
			seen[e.C.Id] = true
			table.insert(out, e.C)
		end
	end
	return out
end

local function logFormat(results: { any })
	local first = results[1]
	if loggedKeys or type(first) ~= "table" then
		return
	end
	loggedKeys = true
	local keys = {}
	for k in first do
		table.insert(keys, tostring(k))
	end
	table.sort(keys)
	if not SoundLibrary.readResult(first, 1) and not warnedFormat then
		warnedFormat = true
		warn("[SoundLibrary] не удалось прочитать ID результата поиска, поля: " .. table.concat(keys, ", "))
	else
		print("[SoundLibrary] поля результата поиска: " .. table.concat(keys, ", "))
	end
end

local function isRateLimit(err: string): boolean
	local e = err:lower()
	return e:find("429", 1, true) ~= nil or e:find("too many", 1, true) ~= nil or e:find("throttl", 1, true) ~= nil
end

-- Один запрос поиска с повторами; кэшируется на весь сервер
function SoundLibrary.query(keyword: string, spec: Sounds.Search, deadline: number): (boolean, any)
	local key = table.concat({ keyword, spec.Music and "M" or "S", tostring(spec.Min), tostring(spec.Max) }, "|")
	local cached = queryCache[key]
	if cached then
		return true, cached
	end
	local err: any = nil
	for attempt = 0, Config.SoundSearchRetries do
		local ok, result = pcall(function()
			local params = Instance.new("AudioSearchParams")
			params.SearchKeyword = keyword
			params.AudioSubType = if spec.Music then Enum.AudioSubType.Music else Enum.AudioSubType.SoundEffect
			if spec.Min then
				params.MinDuration = math.floor(spec.Min)
			end
			if spec.Max then
				params.MaxDuration = math.ceil(spec.Max)
			end
			local pages = AssetService:SearchAudioAsync(params)
			params:Destroy()
			return pages:GetCurrentPage()
		end)
		if ok and type(result) == "table" then
			queryCache[key] = result
			logFormat(result)
			return true, result
		end
		err = if ok then "пустой ответ" else result
		local wait = 1.5 * 2 ^ attempt * (if isRateLimit(tostring(err)) then 3 else 1)
		if attempt == Config.SoundSearchRetries or os.clock() + wait > deadline then
			break
		end
		task.wait(wait)
	end
	return false, err
end

-- Ищет звуки одного слота. Возвращает ID (может быть пустым) или nil и ошибку
function SoundLibrary.findSlot(def: Sounds.Def, deadline: number): ({ string }?, any)
	local spec = def.Search :: Sounds.Search
	local count = spec.Count or 1
	local ids, seen = {}, {}
	for _, keyword in spec.Keywords do
		if #ids >= count or os.clock() > deadline then
			break
		end
		local ok, results = SoundLibrary.query(keyword, spec, deadline)
		if not ok then
			if #ids > 0 then
				break
			end
			return nil, results
		end
		for _, c in SoundLibrary.pick(results, spec, keyword, count - #ids) do
			if not seen[c.Id] then
				seen[c.Id] = true
				table.insert(ids, c.Id)
			end
		end
	end
	return ids, nil
end

function SoundLibrary.folder(): Folder
	local folder = ReplicatedStorage:FindFirstChild(Sounds.LibraryFolder) :: Folder?
	if not folder then
		local f = Instance.new("Folder")
		f.Name = Sounds.LibraryFolder
		f:SetAttribute("Version", 0)
		f.Parent = ReplicatedStorage
		folder = f
	end
	return folder :: Folder
end

local function publish(folder: Folder, name: string, ids: { string })
	folder:SetAttribute(name, Sounds.encodeIds(ids))
	folder:SetAttribute("Version", (tonumber(folder:GetAttribute("Version")) or 0) + 1)
end

-- Весь поиск (yields). Обычно вызывается через SoundLibrary.start()
function SoundLibrary.run()
	local folder = SoundLibrary.folder()
	if not Config.SoundLibraryEnabled then
		folder:SetAttribute("Status", "Disabled")
		return
	end
	folder:SetAttribute("Status", "Searching")
	local startTime = os.clock()
	local deadline = startTime + Config.SoundSearchTimeLimit
	local queue = {}
	for _, def in Sounds.List do
		local override = Config.SoundOverrides[def.Name]
		if def.Search and not override then
			table.insert(queue, def)
		end
	end
	local total = #queue
	local found, failStreak, running = 0, 0, 0
	local stop = false
	local lastError: any = nil

	local function worker()
		while not stop and #queue > 0 and os.clock() < deadline do
			local def = table.remove(queue, 1) :: Sounds.Def
			local ids, err = SoundLibrary.findSlot(def, deadline)
			if ids then
				failStreak = 0
				if #ids > 0 then
					found += 1
					publish(folder, def.Name, ids)
				end
			else
				lastError = err
				failStreak += 1
				-- Несколько запросов подряд с ошибкой: поиск недоступен, не тратим время
				if failStreak >= 3 then
					stop = true
				end
			end
			task.wait(0.3)
		end
		running -= 1
	end

	for _ = 1, math.max(Config.SoundSearchWorkers, 1) do
		running += 1
		task.spawn(worker)
	end
	while running > 0 do
		task.wait(0.25)
	end

	local offline = found == 0 and lastError ~= nil
	folder:SetAttribute("Status", if offline then "Offline" else "Ready")
	if offline then
		print("[SoundLibrary] поиск звуков недоступен (" .. tostring(lastError) .. ") — играют встроенные звуки")
	else
		print(string.format("[SoundLibrary] найдено звуков: %d из %d за %.0f с", found, total, os.clock() - startTime))
	end
end

-- Запускает поиск в фоне один раз на сервер (результаты остаются в папке до конца жизни сервера)
function SoundLibrary.start()
	if started then
		return
	end
	started = true
	task.spawn(SoundLibrary.run)
end

return SoundLibrary
