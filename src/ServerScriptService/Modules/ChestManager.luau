--!strict
-- Ubicación en Roblox Studio: ServerScriptService/Modules/ChestManager (ModuleScript)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GameConfig"))
local BaseManager = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("BaseManager"))
local PlayerSession = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("PlayerSession"))

local ChestManager = {}

local rng = Random.new()

-- Callback registrado por StealManager (Sistema 4) para procesar robos sin dependencias circulares
local onStealAttemptCallback: ((thief: Player, victimOwner: Player, slotData: BaseManager.SlotData, fruitId: string) -> ())? = nil

function ChestManager.SetStealCallback(
	callback: (thief: Player, victimOwner: Player, slotData: BaseManager.SlotData, fruitId: string) -> ()
)
	onStealAttemptCallback = callback
end

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
end

local notifyRemote = remotesFolder:FindFirstChild("NotifyEvent") :: RemoteEvent?
if not notifyRemote then
	notifyRemote = Instance.new("RemoteEvent")
	notifyRemote.Name = "NotifyEvent"
	notifyRemote.Parent = remotesFolder
end

local function notifyPlayer(player: Player, message: string, color: Color3?)
	if notifyRemote then
		notifyRemote:FireClient(player, message, color or Color3.fromRGB(255, 255, 255))
	end
end

function ChestManager.RollRarity(weights: { [string]: number }, luckMultiplier: number): string
	local adjustedWeights: { [string]: number } = {}
	local totalWeight = 0

	for rarityKey, baseWeight in weights do
		if baseWeight > 0 then
			local weight = baseWeight
			local rarityInfo = GameConfig.Rarities[rarityKey]
			if rarityInfo and rarityInfo.Order >= 3 and luckMultiplier > 1 then
				weight = baseWeight * luckMultiplier
			end
			adjustedWeights[rarityKey] = weight
			totalWeight += weight
		end
	end

	local roll = rng:NextNumber(0, totalWeight)
	local cumulative = 0

	for rarityKey, weight in adjustedWeights do
		cumulative += weight
		if roll <= cumulative then
			return rarityKey
		end
	end

	return "Comun"
end

function ChestManager.RollFruitFromRarity(targetRarity: string): GameConfig.FruitInfo
	local pool: { GameConfig.FruitInfo } = {}

	for _, fruitData in GameConfig.Fruits do
		if fruitData.Rarity == targetRarity then
			table.insert(pool, fruitData)
		end
	end

	if #pool == 0 then
		return GameConfig.Fruits.FrutaBrisa
	end

	local randomIndex = rng:NextInteger(1, #pool)
	return pool[randomIndex]
end

function ChestManager.CreateFruitVisualModel(fruitInfo: GameConfig.FruitInfo): Model
	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	local fruitsFolder = if assetsFolder then assetsFolder:FindFirstChild("Fruits") else nil
	local template = if fruitsFolder then fruitsFolder:FindFirstChild(fruitInfo.Id) else nil

	local model: Model
	if template and template:IsA("Model") then
		model = template:Clone()
	else
		model = Instance.new("Model")
		model.Name = fruitInfo.Id

		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Shape = Enum.PartType.Ball
		handle.Size = Vector3.new(2.2, 2.2, 2.2)
		handle.Material = Enum.Material.Neon
		handle.Color = fruitInfo.Color
		handle.Anchored = true
		handle.CanCollide = false
		handle.Parent = model

		local stem = Instance.new("Part")
		stem.Name = "Stem"
		stem.Size = Vector3.new(0.3, 0.8, 0.3)
		stem.Material = Enum.Material.Wood
		stem.Color = Color3.fromRGB(90, 60, 30)
		stem.Anchored = true
		stem.CanCollide = false
		stem.CFrame = handle.CFrame * CFrame.new(0, 1.2, 0)
		stem.Parent = model

		model.PrimaryPart = handle
	end

	local rarityInfo = GameConfig.Rarities[fruitInfo.Rarity]
	local rarityColor = if rarityInfo then rarityInfo.Color else Color3.fromRGB(255, 255, 255)
	local rarityName = if rarityInfo then rarityInfo.DisplayName else fruitInfo.Rarity

	local highlight = Instance.new("Highlight")
	highlight.FillColor = fruitInfo.Color
	highlight.OutlineColor = rarityColor
	highlight.FillTransparency = 0.65
	highlight.OutlineTransparency = 0.1
	highlight.Parent = model

	local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if primary then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "FruitBillboard"
		billboard.Size = UDim2.fromOffset(180, 75)
		billboard.StudsOffset = Vector3.new(0, 3.2, 0)
		billboard.AlwaysOnTop = false
		billboard.MaxDistance = 45
		billboard.Parent = primary

		local listLayout = Instance.new("UIListLayout")
		listLayout.SortOrder = Enum.SortOrder.LayoutOrder
		listLayout.Parent = billboard

		local function makeLabel(name: string, text: string, color: Color3, order: number, scaleY: number)
			local lbl = Instance.new("TextLabel")
			lbl.Name = name
			lbl.Size = UDim2.fromScale(1, scaleY)
			lbl.BackgroundTransparency = 1
			lbl.Font = Enum.Font.FredokaOne
			lbl.TextScaled = true
			lbl.TextStrokeTransparency = 0.15
			lbl.TextColor3 = color
			lbl.Text = text
			lbl.LayoutOrder = order
			lbl.Parent = billboard
		end

		makeLabel("Title", fruitInfo.DisplayName, Color3.fromRGB(255, 255, 255), 1, 0.38)
		makeLabel("Rarity", "[" .. string.upper(rarityName) .. "]", rarityColor, 2, 0.32)
		makeLabel("Production", "💰 +" .. tostring(fruitInfo.BerriesPerSecond) .. " Berries/s", Color3.fromRGB(100, 255, 120), 3, 0.30)
	end

	return model
end

function ChestManager.PlaceFruitInSlot(owner: Player, slotData: BaseManager.SlotData, fruitId: string): boolean
	local fruitInfo = GameConfig.Fruits[fruitId]
	if not fruitInfo then
		warn("[ChestManager] No existe la fruta con ID: " .. tostring(fruitId))
		return false
	end

	if slotData.FruitModel then
		slotData.FruitModel:Destroy()
		slotData.FruitModel = nil
	end

	local fruitModel = ChestManager.CreateFruitVisualModel(fruitInfo)
	fruitModel:SetAttribute("FruitId", fruitId)
	fruitModel:SetAttribute("OwnerUserId", owner.UserId)
	fruitModel:SetAttribute("SlotIndex", slotData.Index)

	local targetCFrame = slotData.Part.CFrame * CFrame.new(0, (slotData.Part.Size.Y / 2) + 1.5, 0)
	fruitModel:PivotTo(targetCFrame)
	fruitModel.Parent = slotData.Part

	local primary = fruitModel.PrimaryPart or fruitModel:FindFirstChildWhichIsA("BasePart")
	if primary then
		-- 1. Prompt para que el dueño pueda VENDER su fruta (Tecla X)
		local sellPrompt = Instance.new("ProximityPrompt")
		sellPrompt.Name = "OwnerSellPrompt"
		sellPrompt.ActionText = "Vender (+" .. tostring(fruitInfo.SellPrice) .. " Berries)"
		sellPrompt.ObjectText = fruitInfo.DisplayName
		sellPrompt.HoldDuration = 1
		sellPrompt.KeyboardKeyCode = Enum.KeyCode.X
		sellPrompt.UIOffset = Vector2.new(0, -35)
		sellPrompt.MaxActivationDistance = 8
		sellPrompt.RequiresLineOfSight = false
		sellPrompt.Parent = primary

		sellPrompt.Triggered:Connect(function(triggerPlayer: Player)
			local playerBase = BaseManager.GetPlayerBase(triggerPlayer)
			if not playerBase or playerBase.Owner ~= owner or slotData.FruitId ~= fruitId or slotData.IsStolenInTransit then
				notifyPlayer(triggerPlayer, "⛔ ¡Solo el dueño puede vender esta fruta si no está siendo robada!", Color3.fromRGB(255, 80, 80))
				return
			end

			slotData.FruitId = nil
			slotData.IsStolenInTransit = false
			if slotData.FruitModel then
				slotData.FruitModel:Destroy()
				slotData.FruitModel = nil
			end
			BaseManager.RefreshSlotVisual(slotData)

			PlayerSession.AddBerries(owner, fruitInfo.SellPrice)
			notifyPlayer(owner, "💸 Vendiste " .. fruitInfo.DisplayName .. " por " .. fruitInfo.SellPrice .. " Berries.", Color3.fromRGB(120, 255, 120))
		end)

		-- 2. Prompt para que OTROS jugadores puedan ROBAR esta fruta (Tecla E)
		local ownerBase = BaseManager.GetPlayerBase(owner)
		local extraHold = if ownerBase then ownerBase.ChainsLevel * 0.75 else 0

		local stealPrompt = Instance.new("ProximityPrompt")
		stealPrompt.Name = "StealFruitPrompt"
		stealPrompt.ActionText = "🏴‍☠️ Robar Fruta"
		stealPrompt.ObjectText = fruitInfo.DisplayName
		stealPrompt.HoldDuration = GameConfig.Stealing.StealHoldDuration + extraHold
		stealPrompt.KeyboardKeyCode = Enum.KeyCode.E
		stealPrompt.UIOffset = Vector2.new(0, 35)
		stealPrompt.MaxActivationDistance = 8
		stealPrompt.RequiresLineOfSight = false
		stealPrompt.Parent = primary

		stealPrompt.Triggered:Connect(function(thief: Player)
			if thief == owner then
				notifyPlayer(thief, "⚓ ¡Esta fruta ya es tuya! Usa la tecla X si quieres venderla.", Color3.fromRGB(255, 220, 100))
				return
			end

			if onStealAttemptCallback then
				onStealAttemptCallback(thief, owner, slotData, fruitId)
			end
		end)
	end

	slotData.FruitId = fruitId
	slotData.IsStolenInTransit = false
	slotData.FruitModel = fruitModel
	BaseManager.RefreshSlotVisual(slotData)

	return true
end

function ChestManager.TryOpenChest(player: Player, chestId: string)
	local chestData = GameConfig.Chests[chestId]
	if not chestData then return end

	local session = PlayerSession.Get(player)
	if not session then return end

	local freeSlot = BaseManager.GetFirstAvailableSlot(player)
	if not freeSlot then
		notifyPlayer(player, "⚠️ ¡Tu barco no tiene pedestales libres! Vende una fruta (Tecla X) o desbloquea otro slot.", Color3.fromRGB(255, 180, 50))
		return
	end

	if not PlayerSession.SpendBerries(player, chestData.Cost) then
		notifyPlayer(player, "❌ No tienes suficientes Berries. Necesitas " .. tostring(chestData.Cost) .. " Berries.", Color3.fromRGB(255, 80, 80))
		return
	end

	local wonRarity = ChestManager.RollRarity(chestData.Weights, session.LuckMultiplier)
	local wonFruit = ChestManager.RollFruitFromRarity(wonRarity)
	local rarityInfo = GameConfig.Rarities[wonRarity]

	ChestManager.PlaceFruitInSlot(player, freeSlot, wonFruit.Id)

	local rarityText = if rarityInfo then rarityInfo.DisplayName else wonRarity
	local color = if rarityInfo then rarityInfo.Color else Color3.fromRGB(255, 255, 255)

	notifyPlayer(
		player,
		string.format("🎉 ¡Obtuviste %s [%s]! Ya está produciendo en tu barco.", wonFruit.DisplayName, rarityText),
		color
	)

	if wonRarity == "Legendaria" or wonRarity == "Mitica" then
		for _, otherPlayer in Players:GetPlayers() do
			if otherPlayer ~= player then
				notifyPlayer(
					otherPlayer,
					string.format("🔥 ¡%s acaba de conseguir una %s [%s]!", player.DisplayName, wonFruit.DisplayName, rarityText),
					color
				)
			end
		end
	end
end

function ChestManager.Init()
	local mapFolder = Workspace:FindFirstChild("Mapa")
	if not mapFolder then
		warn("[ChestManager] No se encontró la carpeta Workspace.Mapa")
		return
	end

	local chestShop = mapFolder:FindFirstChild("ChestShop")
	if not chestShop then
		warn("[ChestManager] No se encontró el modelo Workspace.Mapa.ChestShop")
		return
	end

	for chestId, chestData in GameConfig.Chests do
		local chestPart = chestShop:FindFirstChild(chestId)
		if not chestPart then
			warn("[ChestManager] Falta la parte '" .. chestId .. "' dentro de Workspace.Mapa.ChestShop")
			continue
		end

		local targetPart: BasePart? = if chestPart:IsA("BasePart")
			then chestPart
			elseif chestPart:IsA("Model") then (chestPart.PrimaryPart or chestPart:FindFirstChildWhichIsA("BasePart"))
			else nil

		if not targetPart then continue end

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "BuyChestPrompt"
		prompt.ActionText = "Abrir por " .. tostring(chestData.Cost) .. " Berries"
		prompt.ObjectText = chestData.DisplayName
		prompt.HoldDuration = 0.25
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = targetPart

		local debounce: { [Player]: boolean } = {}

		prompt.Triggered:Connect(function(player: Player)
			if debounce[player] then return end
			debounce[player] = true

			ChestManager.TryOpenChest(player, chestId)

			task.delay(0.4, function()
				debounce[player] = nil
			end)
		end)
	end
end

return ChestManager
