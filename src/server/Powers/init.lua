-- Диспетчер способностей маньяков.
-- Каждый модуль может определить: Setup, Press, Release, Update, CanAttack, SpeedOverride,
-- TerrorRadius, OnStun, OnBlind, OnHit, OnLockerSearched, Cleanup.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local State = require(script.Parent.Core.State)

local Powers = {}

local modules = {
	Trapper = require(script.Trapper),
	Huntress = require(script.Huntress),
	Wraith = require(script.Wraith),
}

function Powers.module(kdata)
	return kdata and modules[kdata.KillerType]
end

-- Вызывает функцию способности, если она есть. Возвращает её результат или nil.
function Powers.call(kdata, fnName: string, ...): any
	local m = Powers.module(kdata)
	local fn = m and m[fnName]
	if fn then
		return fn(kdata, ...)
	end
	return nil
end

function Powers.update(dt: number)
	local k = State.Killer
	if k and k.Status == "Playing" then
		Powers.call(k, "Update", dt)
	end
end

local function validAim(aim: any): Vector3?
	if typeof(aim) ~= "Vector3" then
		return nil
	end
	local m = aim.Magnitude
	if m ~= m or m < 0.5 or m > 1.5 then
		return nil
	end
	return aim.Unit
end

Remotes.UsePower.OnServerEvent:Connect(function(player, isDown, aim)
	local data = State.get(player)
	if not State.Active or not data or data.Role ~= "Killer" or data.Status ~= "Playing" then
		return
	end
	if isDown == true then
		Powers.call(data, "Press", validAim(aim))
	else
		Powers.call(data, "Release", validAim(aim))
	end
end)

return Powers
