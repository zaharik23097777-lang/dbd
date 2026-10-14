-- Мини-окружение Roblox для Lune: загружает скрипты прямо из собранного .rbxlx
-- и выполняет require() по экземплярам ModuleScript, как в настоящем Roblox.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Harness = {}

local RandomShim = {}
RandomShim.__index = RandomShim
function RandomShim.new(seed)
	local self = setmetatable({}, RandomShim)
	self.state = math.floor((seed or os.clock() * 1000) % 2147483647)
	if self.state <= 0 then
		self.state = 12345
	end
	return self
end
function RandomShim:_next()
	-- LCG (Park-Miller)
	self.state = (self.state * 48271) % 2147483647
	return self.state / 2147483647
end
function RandomShim:NextNumber(a, b)
	a = a or 0
	b = b or 1
	return a + (b - a) * self:_next()
end
function RandomShim:NextInteger(a, b)
	return math.floor(a + (b - a + 1) * self:_next())
end

local noop = function() end
local signalStub = { Connect = noop, Wait = noop, Once = noop }
local STUBS = {
	TweenService = {
		Create = function()
			return { Play = noop, Cancel = noop, Completed = signalStub }
		end,
	},
	Debris = { AddItem = noop },
	RunService = {
		IsServer = function()
			return true
		end,
		IsStudio = function()
			return true
		end,
	},
}

Harness.STUBS = STUBS

function Harness.load(placePath)
	local realGame = roblox.deserializePlace(fs.readFile(placePath))
	-- Сервисы с методами движка, которых нет в Lune, заменяем заглушками
	local game = setmetatable({}, {
		__index = function(_, key)
			if key == "GetService" then
				return function(_, name)
					return STUBS[name] or realGame:GetService(name)
				end
			end
			local v = realGame[key]
			if type(v) == "function" then
				return function(_, ...)
					return v(realGame, ...)
				end
			end
			return v
		end,
	})
	local cache = {}
	local env
	local function requireModule(module)
		local key = module:GetFullName()
		if cache[key] ~= nil then
			return cache[key]
		end
		assert(module.ClassName == "ModuleScript", "require() expects a ModuleScript, got " .. tostring(module))
		local chunk = luau.load(module.Source, {
			debugName = module:GetFullName(),
			environment = (function()
				local e = table.clone(env)
				e.script = module
				return e
			end)(),
		})
		local result = chunk()
		cache[key] = result
		return result
	end
	env = setmetatable({
		game = game,
		workspace = realGame:GetService("Workspace"),
		TweenInfo = { new = function() return {} end },
		Instance = roblox.Instance,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		Enum = roblox.Enum,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		ColorSequence = roblox.ColorSequence,
		NumberRange = roblox.NumberRange,
		Random = RandomShim,
		require = requireModule,
		typeof = roblox.typeof or typeof,
		task = require("@lune/task"),
	}, nil)
	return realGame, requireModule
end

return Harness
