--!strict
-- Ubicación en Roblox Studio: ServerScriptService/Core/GameServer (Script)

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local modules = ServerScriptService:WaitForChild("Modules")
local BaseManager = require(modules:WaitForChild("BaseManager"))
local PlayerSession = require(modules:WaitForChild("PlayerSession"))
local ChestManager = require(modules:WaitForChild("ChestManager"))
local ProductionManager = require(modules:WaitForChild("ProductionManager"))
local StealManager = require(modules:WaitForChild("StealManager"))

-- 1. Inicializar todos los sistemas del servidor en orden
BaseManager.Init()
ChestManager.Init()
ProductionManager.Init()
StealManager.Init()

-- 2. Configurar a cada jugador que entra al servidor
local function onPlayerAdded(player: Player)
	PlayerSession.SetupPlayer(player)
	StealManager.SetupPlayer(player)

	local assignedBase = BaseManager.AssignBaseToPlayer(player)
	if not assignedBase then return end

	player.CharacterAdded:Connect(function(character: Model)
		BaseManager.TeleportPlayerToBase(player, character)
	end)

	if player.Character then
		BaseManager.TeleportPlayerToBase(player, player.Character)
		StealManager.GiveDefenseWeapon(player)
	end
end

-- 3. Limpiar datos y devolver frutas en tránsito si un jugador sale
local function onPlayerRemoving(player: Player)
	StealManager.CleanupPlayer(player)
	BaseManager.ReleasePlayerBase(player)
	PlayerSession.CleanupPlayer(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

print("✅ [Rouba a Fruta] Sistemas 1 a 4 (Barcos, Cofres, Producción y Robo PvP) activos.")
