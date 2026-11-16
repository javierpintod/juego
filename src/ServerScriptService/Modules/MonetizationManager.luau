--!strict
-- Ubicación en Roblox Studio: ServerScriptService/Modules/MonetizationManager (ModuleScript)

local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GameConfig"))
local BaseManager = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("BaseManager"))
local DefenseManager = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("DefenseManager"))
local PlayerSession = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("PlayerSession"))
local StealManager = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("StealManager"))

local MonetizationManager = {}

-- DataStore para evitar compras duplicadas de Developer Products si hay cuelgues
local PurchaseHistoryStore: GlobalDataStore? = nil
pcall(function()
	PurchaseHistoryStore = DataStoreService:GetDataStore("RoubaAFruta_PurchaseHistory_v1")
end)

local function notifyPlayer(player: Player, message: string, color: Color3?)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local notifyEvent = if remotes then remotes:FindFirstChild("NotifyEvent") :: RemoteEvent? else nil
	if notifyEvent then
		notifyEvent:FireClient(player, message, color or Color3.fromRGB(255, 255, 255))
	end
end

--------------------------------------------------------------------------------
-- 1. APLICACIÓN DE GAMEPASSES
--------------------------------------------------------------------------------
function MonetizationManager.ApplyGamePass(player: Player, passId: number)
	local session = PlayerSession.Get(player)
	if not session then return end

	local gpConfig = GameConfig.GamePasses

	if passId == gpConfig.DoubleMoney.Id then
		session.DoubleMoney = true
		notifyPlayer(player, "⭐ ¡GamePass Activado: Doble Berries x2!", Color3.fromRGB(255, 215, 0))
	elseif passId == gpConfig.DoubleSpeed.Id then
		session.DoubleSpeed = true
		StealManager.UpdatePlayerWalkSpeed(player)
		notifyPlayer(player, "⭐ ¡GamePass Activado: Velocidad Pirata x2!", Color3.fromRGB(255, 215, 0))
	elseif passId == gpConfig.AutoCollect.Id then
		session.AutoCollect = true
		notifyPlayer(player, "⭐ ¡GamePass Activado: Auto-Recolector de Berries!", Color3.fromRGB(255, 215, 0))
	elseif passId == gpConfig.ExtraSlot.Id then
		BaseManager.UnlockSlot(player, 6)
		notifyPlayer(player, "⭐ ¡GamePass Activado: Pedestal VIP #6 Desbloqueado!", Color3.fromRGB(255, 215, 0))
	elseif passId == gpConfig.PermanentShield.Id then
		DefenseManager.ActivateShield(player, 0, true)
		notifyPlayer(player, "⭐ ¡GamePass Activado: Escudo Permanente Activo!", Color3.fromRGB(100, 220, 255))
	end
end

-- Verifica la posesión de GamePasses al entrar al servidor
function MonetizationManager.CheckPlayerGamePasses(player: Player)
	for _, passData in GameConfig.GamePasses do
		task.spawn(function()
			local hasPass = false
			local success, result = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passData.Id)
			end)

			if success and result then
				hasPass = true
			end

			if hasPass and player.Parent == Players then
				MonetizationManager.ApplyGamePass(player, passData.Id)
			end
		end)
	end
end

--------------------------------------------------------------------------------
-- 2. ENTREGA DE DEVELOPER PRODUCTS
--------------------------------------------------------------------------------
local function awardProduct(player: Player, productId: number): boolean
	local session = PlayerSession.Get(player)
	if not session then return false end

	local devConfig = GameConfig.DeveloperProducts

	if productId == devConfig.BerriesPackSmall.Id then
		PlayerSession.AddBerries(player, devConfig.BerriesPackSmall.Amount)
		notifyPlayer(player, "💰 ¡Recibiste 1,500 Berries!", Color3.fromRGB(120, 255, 120))
		return true
	elseif productId == devConfig.BerriesPackMedium.Id then
		PlayerSession.AddBerries(player, devConfig.BerriesPackMedium.Amount)
		notifyPlayer(player, "💰 ¡Recibiste 7,500 Berries!", Color3.fromRGB(120, 255, 120))
		return true
	elseif productId == devConfig.BerriesPackLarge.Id then
		PlayerSession.AddBerries(player, devConfig.BerriesPackLarge.Amount)
		notifyPlayer(player, "💰 ¡Recibiste 25,000 Berries!", Color3.fromRGB(120, 255, 120))
		return true
	elseif productId == devConfig.LuckPotion.Id then
		session.LuckMultiplier = devConfig.LuckPotion.Multiplier
		notifyPlayer(player, "🍀 ¡Poción de Suerte x2 activada para tus cofres!", Color3.fromRGB(255, 215, 0))
		return true
	elseif productId == devConfig.Shield10Min.Id then
		DefenseManager.ActivateShield(player, devConfig.Shield10Min.DurationSeconds, false)
		notifyPlayer(player, "🛡️ ¡Escudo Místico de 10 minutos desplegado en tu barco!", Color3.fromRGB(100, 220, 255))
		return true
	end

	warn("[MonetizationManager] Producto no reconocido: " .. tostring(productId))
	return false
end

--------------------------------------------------------------------------------
-- 3. PROCESAMIENTO A PRUEBA DE FALLOS CON ProcessReceipt
--------------------------------------------------------------------------------
local function processReceipt(receiptInfo: {
	PurchaseId: string,
	PlayerId: number,
	ProductId: number,
	CurrencySpent: number,
})
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		-- El jugador se desconectó antes de recibir la compra. Retornamos NotProcessedYet
		-- para que Roblox reintente cuando vuelva a entrar.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Evitar duplicados revisando PurchaseHistoryStore
	local purchaseKey = "Purchase_" .. receiptInfo.PurchaseId
	local alreadyGranted = false

	if PurchaseHistoryStore then
		local ok, saved = pcall(function()
			return (PurchaseHistoryStore :: GlobalDataStore):GetAsync(purchaseKey)
		end)
		if ok and saved == true then
			alreadyGranted = true
		end
	end

	if alreadyGranted then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- Otorgar la compra al jugador
	local successAward = awardProduct(player, receiptInfo.ProductId)
	if not successAward then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Registrar en DataStore como entregado
	if PurchaseHistoryStore then
		pcall(function()
			(PurchaseHistoryStore :: GlobalDataStore):SetAsync(purchaseKey, true)
		end)
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

--------------------------------------------------------------------------------
-- 4. INICIALIZACIÓN Y EVENTOS
--------------------------------------------------------------------------------
function MonetizationManager.Init()
	-- Asignar el callback oficial de MarketplaceService
	MarketplaceService.ProcessReceipt = processReceipt

	-- Detectar cuando un jugador compra un GamePass mientras está dentro del juego
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, wasPurchased: boolean)
		if wasPurchased then
			MonetizationManager.ApplyGamePass(player, passId)
		end
	end)

	-- Evento remoto para que el cliente pueda abrir el prompt de compra
	local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
	local promptRemote = remotesFolder:FindFirstChild("PromptPurchaseEvent") :: RemoteEvent?
	if not promptRemote then
		promptRemote = Instance.new("RemoteEvent")
		promptRemote.Name = "PromptPurchaseEvent"
		promptRemote.Parent = remotesFolder
	end

	promptRemote.OnServerEvent:Connect(function(player: Player, purchaseType: string, id: number)
		if purchaseType == "GamePass" then
			MarketplaceService:PromptGamePassPurchase(player, id)
		elseif purchaseType == "Product" then
			MarketplaceService:PromptProductPurchase(player, id)
		end
	end)
end

return MonetizationManager
