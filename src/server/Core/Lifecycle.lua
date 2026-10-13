-- Выбывание из раунда (смерть, побег, выход) и «отцепление» от объектов
-- (крюк, шкафчик, капкан, руки маньяка). Системы регистрируют свои обработчики,
-- чтобы не было циклических require.
local State = require(script.Parent.State)
local Actions = require(script.Parent.Actions)
local Characters = require(script.Parent.Characters)

local Lifecycle = {}

local detachers = {} :: { (data: any) -> () }

-- fn(data) должна освободить игрока от своего объекта, если он к нему привязан
function Lifecycle.addDetach(fn: (data: any) -> ())
	table.insert(detachers, fn)
end

function Lifecycle.detach(data)
	for _, fn in detachers do
		fn(data)
	end
end

-- Убрать выжившего из игры. status = "Dead" / "Escaped" / "Left"
function Lifecycle.remove(data, status: string, text: string?, color: Color3?)
	if not State.isInGame(data) then
		return
	end
	Lifecycle.detach(data)
	Actions.cancel(data)
	data.Status = status
	data.Player:SetAttribute("Status", status)
	if text then
		State.notifyAll(text, color)
	end
	local player = data.Player
	if status ~= "Left" then
		task.delay(status == "Dead" and 1.8 or 0.3, function()
			if player.Parent and State.Participants[player] == data then
				Characters.spawnLobby(player)
			end
		end)
	end
end

return Lifecycle
