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
local DefenseManager = require(modules:WaitForChild("DefenseManager"))
local DataManager = require(modules:WaitForChild("DataManager"))
local ShopService = require(modules:WaitForChild("ShopService"))

-- 1. Inicializar todos los sistemas del servidor en orden
BaseManager.Init()
ChestManager.Init()
ProductionManager.Init()
StealManager.Init()
DefenseManager.Init()
DataManager.Init()
ShopService.Init()

-- 2. Configurar y cargar datos para cada jugador que entra al servidor
local function onPlayerAdded(player: Player)
	DataManager.LoadPlayerData(player)
	StealManager.SetupPlayer(player)

	player.CharacterAdded:Connect(function(character: Model)
		BaseManager.TeleportPlayerToBase(player, character)
	end)

	if player.Character then
		BaseManager.TeleportPlayerToBase(player, player.Character)
		StealManager.GiveDefenseWeapon(player)
	end
end

-- 3. Guardar datos en DataStore y limpiar cuando un jugador sale
local function onPlayerRemoving(player: Player)
	local baseData = BaseManager.GetPlayerBase(player)
	StealManager.CleanupPlayer(player)
	DataManager.SavePlayerData(player)

	if baseData then
		DefenseManager.ResetBaseDefenses(baseData)
	end

	BaseManager.ReleasePlayerBase(player)
	PlayerSession.CleanupPlayer(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

print("✅ [Rouba a Fruta] Sistemas 1 a 7 (Barcos, Cofres, Producción, Robo, Defensas, DataStore y ShopService) activos.")
