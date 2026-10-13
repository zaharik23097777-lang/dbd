-- Общие функции для сервера и клиента.
local Util = {}

function Util.getRoot(player: Player?): BasePart?
	local char = player and player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function Util.getHumanoid(player: Player?): Humanoid?
	local char = player and player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

function Util.flatDist(a: Vector3, b: Vector3): number
	local d = a - b
	return Vector3.new(d.X, 0, d.Z).Magnitude
end

-- Позиция объекта взаимодействия (одинаково считается на сервере и клиенте)
function Util.objectPosition(obj: Instance?): Vector3?
	if typeof(obj) ~= "Instance" or not obj.Parent then
		return nil
	end
	if obj:IsA("Player") then
		local root = Util.getRoot(obj)
		return root and root.Position
	end
	local kind = obj:GetAttribute("Kind")
	if kind == "Pallet" then
		local cf = obj:GetAttribute("DropCFrame")
		return cf and (cf :: CFrame).Position
	elseif kind == "Hook" then
		local hp = obj:FindFirstChild("HangPoint") :: BasePart?
		return hp and hp.Position
	elseif kind == "ExitGate" then
		local sw = obj:FindFirstChild("Switch") :: BasePart?
		return sw and sw.Position
	elseif kind == "Locker" then
		local inside = obj:FindFirstChild("Inside") :: BasePart?
		return inside and inside.Position
	end
	if obj:IsA("Model") then
		return obj:GetPivot().Position
	elseif obj:IsA("BasePart") then
		return obj.Position
	end
	return nil
end

function Util.isInGameStatus(status: string?): boolean
	return status == "Playing" or status == "Carried" or status == "Hooked"
end

function Util.weld(part0: BasePart, part1: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = part0
	w.Part1 = part1
	w.Parent = part1
	return w
end

return Util
