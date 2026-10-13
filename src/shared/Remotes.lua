-- Создаёт (на сервере) или находит (на клиенте) все RemoteEvent'ы игры.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	"Attack", -- клиент -> сервер: маньяк бьёт
	"Sprint", -- клиент -> сервер: бег (true/false)
	"BeginAction", -- клиент -> сервер: начать действие (kind, target)
	"EndAction", -- клиент -> сервер: отпустить кнопку
	"SkillCheck", -- сервер -> клиент: показать проверку; клиент -> сервер: результат
	"Notify", -- сервер -> клиент: сообщение на экране
	"Noise", -- сервер -> маньяку: подсветить место шума (взрыв генератора)
	"Results", -- сервер -> клиенту: итоги раунда
	"Crouch", -- клиент -> сервер: присесть (true/false)
	"UsePower", -- клиент -> сервер: способность маньяка (нажата?, направление)
	"UseItem", -- клиент -> сервер: предмет выжившего (нажата?, направление)
	"Sfx", -- сервер -> клиенту: проиграть звук (имя, где)
	"Score", -- сервер -> клиенту: +очки крови
	"LobbyChoice", -- клиент -> сервер: выбор в лобби
	"Projectile", -- сервер -> клиенту: полёт топора (id, старт, скорость, гравитация)
	"ProjectileEnd", -- сервер -> клиенту: топор остановился (id, позиция)
	"Effect", -- сервер -> клиенту: экранный эффект (ослепление, тряска, интро)
}

local Remotes = {}

local folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in NAMES do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

local isServer = RunService:IsServer()
for _, name in NAMES do
	Remotes[name] = if isServer then folder:FindFirstChild(name) else folder:WaitForChild(name)
end

return Remotes
