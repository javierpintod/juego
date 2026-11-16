--!strict
-- Ubicación en Roblox Studio: ServerScriptService/Modules/ProductionManager (ModuleScript)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GameConfig"))
local BaseManager = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("BaseManager"))
local PlayerSession = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("PlayerSession"))

local ProductionManager = {}

-- Callback opcional para que StealManager procese cuando un jugador pisa su DropZone con una fruta robada
local onOwnerTouchedDropZone: ((player: Player) -> ())? = nil

function ProductionManager.SetDropZoneDeliveryCallback(callback: (player: Player) -> ())
	onOwnerTouchedDropZone = callback
end

function ProductionManager.GetBaseProductionRate(baseData: BaseManager.BaseData): number
	local totalPerSecond = 0

	for _, slot in baseData.Slots do
		if slot.Unlocked and slot.FruitId ~= nil and not slot.IsStolenInTransit then
			local fruitInfo = GameConfig.Fruits[slot.FruitId]
			if fruitInfo then
				totalPerSecond += fruitInfo.BerriesPerSecond
			end
		end
	end

	return totalPerSecond
end

local function updateDropZoneVisual(baseData: BaseManager.BaseData, ratePerSecond: number)
	local dropZone = baseData.Model:FindFirstChild("DropZone") :: BasePart?
	if not dropZone then return end

	local billboard = dropZone:FindFirstChild("CollectorGui") :: BillboardGui?
	if not billboard then
		billboard = Instance.new("BillboardGui")
		billboard.Name = "CollectorGui"
		billboard.Size = UDim2.fromOffset(200, 70)
		billboard.StudsOffset = Vector3.new(0, 3.5, 0)
		billboard.AlwaysOnTop = false
		billboard.MaxDistance = 50
		billboard.Parent = dropZone

		local list = Instance.new("UIListLayout")
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = billboard

		local titleLabel = Instance.new("TextLabel")
		titleLabel.Name = "AmountLabel"
		titleLabel.Size = UDim2.fromScale(1, 0.6)
		titleLabel.BackgroundTransparency = 1
		titleLabel.Font = Enum.Font.FredokaOne
		titleLabel.TextScaled = true
		titleLabel.TextStrokeTransparency = 0.15
		titleLabel.TextColor3 = Color3.fromRGB(255, 230, 80)
		titleLabel.LayoutOrder = 1
		titleLabel.Parent = billboard

		local rateLabel = Instance.new("TextLabel")
		rateLabel.Name = "RateLabel"
		rateLabel.Size = UDim2.fromScale(1, 0.4)
		rateLabel.BackgroundTransparency = 1
		rateLabel.Font = Enum.Font.FredokaOne
		rateLabel.TextScaled = true
		rateLabel.TextStrokeTransparency = 0.2
		rateLabel.TextColor3 = Color3.fromRGB(140, 255, 140)
		rateLabel.LayoutOrder = 2
		rateLabel.Parent = billboard
	end

	local amountLabel = billboard:FindFirstChild("AmountLabel") :: TextLabel
	local rateLabel = billboard:FindFirstChild("RateLabel") :: TextLabel

	if baseData.Owner == nil then
		amountLabel.Text = "💰 Botín: 0"
		rateLabel.Text = "+0 Berries/s"
		return
	end

	local session = PlayerSession.Get(baseData.Owner)
	if session and session.AutoCollect then
		amountLabel.Text = "⚡ Auto-Recolector Activo"
	else
		amountLabel.Text = "💰 Botín: " .. tostring(baseData.StoredBerries) .. " Berries"
	end

	local displayRate = if session and session.DoubleMoney then ratePerSecond * 2 else ratePerSecond
	rateLabel.Text = "📈 +" .. tostring(displayRate) .. " Berries/s"
end

function ProductionManager.CollectBaseBerries(player: Player)
	local baseData = BaseManager.GetPlayerBase(player)
	if not baseData or baseData.Owner ~= player then return end

	-- Si trae una fruta robada en las manos, se asegura al pisar/usar su DropZone
	if onOwnerTouchedDropZone then
		onOwnerTouchedDropZone(player)
	end

	if baseData.StoredBerries <= 0 then return end

	local amountToCollect = baseData.StoredBerries
	baseData.StoredBerries = 0

	PlayerSession.AddBerries(player, amountToCollect)

	local currentRate = ProductionManager.GetBaseProductionRate(baseData)
	updateDropZoneVisual(baseData, currentRate)
end

local function setupDropZoneInteractions(baseData: BaseManager.BaseData)
	local dropZone = baseData.Model:FindFirstChild("DropZone") :: BasePart?
	if not dropZone then
		warn("[ProductionManager] Falta 'DropZone' en " .. baseData.Model.Name)
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CollectPrompt"
	prompt.ObjectText = "Cofre de Botín / Entrega"
	prompt.ActionText = "Recolectar / Asegurar Fruta"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = dropZone

	prompt.Triggered:Connect(function(player: Player)
		if baseData.Owner == player then
			ProductionManager.CollectBaseBerries(player)
		end
	end)

	local touchCooldown: { [Player]: boolean } = {}
	dropZone.Touched:Connect(function(hit: BasePart)
		local character = hit.Parent
		if not character then return end

		local player = Players:GetPlayerFromCharacter(character)
		if not player or baseData.Owner ~= player then return end

		if touchCooldown[player] then return end
		touchCooldown[player] = true

		ProductionManager.CollectBaseBerries(player)

		task.delay(0.5, function()
			touchCooldown[player] = nil
		end)
	end)

	updateDropZoneVisual(baseData, 0)
end

function ProductionManager.Init()
	for _, baseData in BaseManager.GetAllBases() do
		setupDropZoneInteractions(baseData)
	end

	task.spawn(function()
		while true do
			task.wait(1)

			for _, baseData in BaseManager.GetAllBases() do
				local owner = baseData.Owner
				if not owner then
					updateDropZoneVisual(baseData, 0)
					continue
				end

				local rate = ProductionManager.GetBaseProductionRate(baseData)
				local session = PlayerSession.Get(owner)

				if session then
					local effectiveRate = if session.DoubleMoney then rate * 2 else rate
					owner:SetAttribute("BerriesPerSecond", effectiveRate)

					if rate > 0 then
						if session.AutoCollect then
							PlayerSession.AddBerries(owner, rate)
						else
							baseData.StoredBerries += rate
						end
					end
				end

				updateDropZoneVisual(baseData, rate)
			end
		end
	end)
end

return ProductionManager
