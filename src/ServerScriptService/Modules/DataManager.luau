--!strict
-- Ubicación en Roblox Studio: ServerScriptService/Modules/DataManager (ModuleScript)

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GameConfig"))
local BaseManager = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("BaseManager"))
local ChestManager = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("ChestManager"))
local DefenseManager = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("DefenseManager"))
local PlayerSession = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("PlayerSession"))

local DataManager = {}

-- Nombre y versión del DataStore
local DATA_STORE_NAME = "RoubaAFruta_PlayerData_v1"
local AUTOSAVE_INTERVAL = 120 -- Auto-guardado periódico cada 2 minutos
local MAX_RETRIES = 3

-- Obtenemos el DataStore de forma segura
local PlayerDataStore: GlobalDataStore? = nil
local isDataStoreEnabled = true

local successInit, errInit = pcall(function()
	PlayerDataStore = DataStoreService:GetDataStore(DATA_STORE_NAME)
end)

if not successInit or not PlayerDataStore then
	warn("⚠️ [DataManager] DataStore no disponible (¿Habilitaste 'Enable Studio Access to API Services'?). Se usarán datos de sesión temporales.")
	isDataStoreEnabled = false
end

-- Estructura de guardado
export type SavedSlot = {
	FruitId: string?,
	Unlocked: boolean,
}

export type PlayerSaveData = {
	Version: number,
	Berries: number,
	ChainsLevel: number,
	CannonLevel: number,
	Slots: { [string]: SavedSlot }, -- Claves "1", "2", etc.
	LastDailyReward: number?,
	ConsecutiveDays: number?,
}

-- Función auxiliar para reintentos con retroceso exponencial
local function retryOperation<T>(operation: () -> T, maxRetries: number): (boolean, any)
	local attempts = 0
	local success = false
	local result: any = nil

	while attempts < maxRetries and not success do
		attempts += 1
		success, result = pcall(operation)
		if not success and attempts < maxRetries then
			task.wait(1.5 * attempts)
		end
	end

	return success, result
end

-- Convierte el estado actual del jugador en el servidor a una tabla serializable
function DataManager.CreateSavePayload(player: Player): PlayerSaveData
	local session = PlayerSession.Get(player)
	local berries = if session then session.Berries else GameConfig.StartingBerries

	local baseData = BaseManager.GetPlayerBase(player)
	local chainsLvl = if baseData then baseData.ChainsLevel else 0
	local cannonLvl = if baseData then baseData.CannonLevel else 0

	local slotsData: { [string]: SavedSlot } = {}
	if baseData then
		for i = 1, GameConfig.Bases.MaxSlots do
			local slot = baseData.Slots[i]
			if slot then
				slotsData[tostring(i)] = {
					FruitId = slot.FruitId,
					Unlocked = slot.Unlocked,
				}
			end
		end
	end

	return {
		Version = 1,
		Berries = berries,
		ChainsLevel = chainsLvl,
		CannonLevel = cannonLvl,
		Slots = slotsData,
		LastDailyReward = player:GetAttribute("LastDailyReward") or 0,
		ConsecutiveDays = player:GetAttribute("ConsecutiveDays") or 0,
	}
end

-- Carga los datos del jugador desde DataStore y restaura su progreso en su barco
function DataManager.LoadPlayerData(player: Player): boolean
	local session = PlayerSession.SetupPlayer(player)
	local assignedBase = BaseManager.AssignBaseToPlayer(player)
	if not assignedBase then
		warn("[DataManager] No se pudo asignar base para " .. player.Name)
		return false
	end

	DefenseManager.ResetBaseDefenses(assignedBase)

	local key = "Player_" .. player.UserId
	local rawData: PlayerSaveData? = nil

	if isDataStoreEnabled and PlayerDataStore then
		local ok, result = retryOperation(function()
			return (PlayerDataStore :: GlobalDataStore):GetAsync(key)
		end, MAX_RETRIES)

		if ok then
			rawData = result
		else
			warn("[DataManager] Error al cargar datos de " .. player.Name .. ": " .. tostring(result))
		end
	end

	-- Si es un jugador nuevo o falló la conexión, inicializar datos por defecto
	if not rawData then
		session.Berries = GameConfig.StartingBerries
		session.LeaderstatsValue.Value = session.Berries
		player:SetAttribute("Berries", session.Berries)
		player:SetAttribute("LastDailyReward", 0)
		player:SetAttribute("ConsecutiveDays", 0)

		-- Slots iniciales (1 a 4 desbloqueados y vacíos)
		for i = 1, GameConfig.Bases.MaxSlots do
			local slot = assignedBase.Slots[i]
			if slot then
				slot.Unlocked = (i <= GameConfig.Bases.BaseSlots)
				slot.FruitId = nil
				BaseManager.RefreshSlotVisual(slot)
			end
		end

		print("📦 [DataManager] Datos iniciales asignados para " .. player.Name)
		return true
	end

	-- Restaurar Berries
	if rawData.Berries ~= nil then
		session.Berries = math.max(0, math.floor(rawData.Berries))
		session.LeaderstatsValue.Value = session.Berries
		player:SetAttribute("Berries", session.Berries)
	end

	-- Restaurar atributos para el sistema de Recompensas Diarias
	player:SetAttribute("LastDailyReward", rawData.LastDailyReward or 0)
	player:SetAttribute("ConsecutiveDays", rawData.ConsecutiveDays or 0)

	-- Restaurar Defensas
	if rawData.ChainsLevel then
		DefenseManager.SetChainsLevel(player, rawData.ChainsLevel)
	end
	if rawData.CannonLevel then
		DefenseManager.SetCannonLevel(player, rawData.CannonLevel)
	end

	-- Restaurar Slots y Frutas Místicas en pedestales
	if rawData.Slots then
		for i = 1, GameConfig.Bases.MaxSlots do
			local savedSlot = rawData.Slots[tostring(i)]
			local slot = assignedBase.Slots[i]
			if slot then
				if savedSlot then
					slot.Unlocked = if savedSlot.Unlocked ~= nil then savedSlot.Unlocked else (i <= GameConfig.Bases.BaseSlots)
					slot.FruitId = nil

					if savedSlot.FruitId and GameConfig.Fruits[savedSlot.FruitId] then
						ChestManager.PlaceFruitInSlot(player, slot, savedSlot.FruitId)
					else
						BaseManager.RefreshSlotVisual(slot)
					end
				else
					slot.Unlocked = (i <= GameConfig.Bases.BaseSlots)
					slot.FruitId = nil
					BaseManager.RefreshSlotVisual(slot)
				end
			end
		end
	end

	print("✅ [DataManager] Progreso restaurado con éxito para " .. player.Name)
	return true
end

-- Guarda los datos del jugador de forma segura con UpdateAsync
function DataManager.SavePlayerData(player: Player): boolean
	if not isDataStoreEnabled or not PlayerDataStore then
		return false
	end

	-- Si el jugador no completó la carga inicial, evitamos sobreescribir con datos corruptos
	local baseData = BaseManager.GetPlayerBase(player)
	if not baseData or baseData.Owner ~= player then
		return false
	end

	local key = "Player_" .. player.UserId
	local currentPayload = DataManager.CreateSavePayload(player)

	local ok, err = retryOperation(function()
		return (PlayerDataStore :: GlobalDataStore):UpdateAsync(key, function(oldData: any)
			-- Podríamos validar versiones previas aquí si es necesario
			return currentPayload
		end)
	end, MAX_RETRIES)

	if not ok then
		warn("[DataManager] ❌ Error guardando datos de " .. player.Name .. ": " .. tostring(err))
		return false
	end

	return true
end

-- Inicializa el auto-guardado en bucle y BindToClose para cierre de servidor
function DataManager.Init()
	-- 1. Bucle de Auto-guardado
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for _, player in Players:GetPlayers() do
				task.spawn(function()
					DataManager.SavePlayerData(player)
				end)
			end
		end
	end)

	-- 2. BindToClose para garantizar guardado antes de que el servidor se apague
	game:BindToClose(function()
		print("🛑 [DataManager] Servidor cerrando... Guardando datos de todos los capitanes.")
		local activePlayers = Players:GetPlayers()
		local count = #activePlayers

		if count == 0 then return end

		local completed = 0
		for _, player in activePlayers do
			task.spawn(function()
				DataManager.SavePlayerData(player)
				completed += 1
			end)
		end

		local startTime = os.clock()
		-- Esperar hasta que todos guarden o se agote el tiempo de tolerancia de Roblox (30s)
		while completed < count and (os.clock() - startTime) < 25 do
			task.wait(0.2)
		end
		print("🏁 [DataManager] Guardado de apagado completado.")
	end)
end

return DataManager
