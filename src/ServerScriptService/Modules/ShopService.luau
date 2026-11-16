--!strict
-- Ubicación en Roblox Studio: ServerScriptService/Modules/ShopService (ModuleScript)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ChestManager = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("ChestManager"))
local DefenseManager = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("DefenseManager"))

local ShopService = {}

function ShopService.Init()
	local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")

	local buyRemote = remotesFolder:FindFirstChild("BuyShopItemEvent") :: RemoteEvent?
	if not buyRemote then
		buyRemote = Instance.new("RemoteEvent")
		buyRemote.Name = "BuyShopItemEvent"
		buyRemote.Parent = remotesFolder
	end

	buyRemote.OnServerEvent:Connect(function(player: Player, itemType: string, itemId: string)
		if itemType == "Chest" then
			ChestManager.TryOpenChest(player, itemId)
		elseif itemType == "Shield" then
			DefenseManager.TryBuyBerryShield(player)
		elseif itemType == "Chains" then
			DefenseManager.TryUpgradeChains(player)
		elseif itemType == "Cannon" then
			DefenseManager.TryUpgradeCannon(player)
		end
	end)
end

return ShopService
