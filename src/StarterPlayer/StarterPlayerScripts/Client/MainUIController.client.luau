--!strict
-- Ubicación en Roblox Studio: StarterPlayer/StarterPlayerScripts/Client/MainUIController (LocalScript)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

local GameConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GameConfig"))
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")

local notifyEvent = remotesFolder:WaitForChild("NotifyEvent") :: RemoteEvent
local buyRemote = remotesFolder:WaitForChild("BuyShopItemEvent") :: RemoteEvent
local promptPurchaseEvent = remotesFolder:WaitForChild("PromptPurchaseEvent") :: RemoteEvent

--------------------------------------------------------------------------------
-- 1. CONSTRUCCIÓN AUTOMÁTICA DE LA INTERFAZ (ScreenGui)
--------------------------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RoubaAFruta_MainGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- A. CONTADOR DE DINERO Y PRODUCCIÓN
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.fromOffset(260, 75)
topBar.Position = UDim2.new(0, 20, 0, 20)
topBar.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
topBar.BorderSizePixel = 0
topBar.Parent = screenGui

local topBarCorner = Instance.new("UICorner")
topBarCorner.CornerRadius = UDim.new(0, 14)
topBarCorner.Parent = topBar

local topBarStroke = Instance.new("UIStroke")
topBarStroke.Color = Color3.fromRGB(240, 190, 50)
topBarStroke.Thickness = 2
topBarStroke.Parent = topBar

local berryIcon = Instance.new("TextLabel")
berryIcon.Name = "BerryIcon"
berryIcon.Size = UDim2.fromOffset(45, 45)
berryIcon.Position = UDim2.new(0, 10, 0.5, -22)
berryIcon.BackgroundTransparency = 1
berryIcon.Font = Enum.Font.FredokaOne
berryIcon.TextScaled = true
berryIcon.Text = "🪙"
berryIcon.Parent = topBar

local berriesLabel = Instance.new("TextLabel")
berriesLabel.Name = "BerriesLabel"
berriesLabel.Size = UDim2.new(1, -65, 0.55, 0)
berriesLabel.Position = UDim2.new(0, 60, 0, 8)
berriesLabel.BackgroundTransparency = 1
berriesLabel.Font = Enum.Font.FredokaOne
berriesLabel.TextScaled = true
berriesLabel.TextColor3 = Color3.fromRGB(255, 230, 80)
berriesLabel.TextXAlignment = Enum.TextXAlignment.Left
berriesLabel.Text = "0 Berries"
berriesLabel.Parent = topBar

local rateLabel = Instance.new("TextLabel")
rateLabel.Name = "RateLabel"
rateLabel.Size = UDim2.new(1, -65, 0.35, 0)
rateLabel.Position = UDim2.new(0, 60, 0.55, 0)
rateLabel.BackgroundTransparency = 1
rateLabel.Font = Enum.Font.FredokaOne
rateLabel.TextScaled = true
rateLabel.TextColor3 = Color3.fromRGB(130, 255, 130)
rateLabel.TextXAlignment = Enum.TextXAlignment.Left
rateLabel.Text = "+0 Berries/s"
rateLabel.Parent = topBar

-- B. BOTONES LATERALES
local sideMenu = Instance.new("Frame")
sideMenu.Name = "SideMenu"
sideMenu.Size = UDim2.fromOffset(65, 210)
sideMenu.Position = UDim2.new(1, -80, 0.5, -105)
sideMenu.BackgroundTransparency = 1
sideMenu.Parent = screenGui

local function createSideButton(name: string, icon: string, order: number, color: Color3): TextButton
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.fromOffset(55, 55)
	btn.Position = UDim2.new(0, 0, 0, (order - 1) * 65)
	btn.BackgroundColor3 = color
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.FredokaOne
	btn.TextScaled = true
	btn.Text = icon
	btn.Parent = sideMenu

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = btn

	return btn
end

local shopButton = createSideButton("ShopButton", "🛒", 1, Color3.fromRGB(40, 120, 220))
local robuxButton = createSideButton("RobuxButton", "💎", 2, Color3.fromRGB(220, 170, 30))
local invButton = createSideButton("InvButton", "🏴‍☠️", 3, Color3.fromRGB(200, 70, 70))

-- C. NOTIFICACIONES FLOTANTES
local notifContainer = Instance.new("Frame")
notifContainer.Name = "Notifications"
notifContainer.Size = UDim2.fromOffset(450, 200)
notifContainer.Position = UDim2.new(0.5, -225, 0, 30)
notifContainer.BackgroundTransparency = 1
notifContainer.Parent = screenGui

local notifLayout = Instance.new("UIListLayout")
notifLayout.SortOrder = Enum.SortOrder.LayoutOrder
notifLayout.Padding = UDim.new(0, 8)
notifLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
notifLayout.Parent = notifContainer

-- D. VENTANA DE TIENDA (Berries)
local shopWindow = Instance.new("Frame")
shopWindow.Name = "ShopWindow"
shopWindow.Size = UDim2.fromOffset(520, 400)
shopWindow.Position = UDim2.new(0.5, -260, 0.5, -200)
shopWindow.BackgroundColor3 = Color3.fromRGB(22, 24, 32)
shopWindow.BorderSizePixel = 0
shopWindow.Visible = false
shopWindow.Parent = screenGui

local shopCorner = Instance.new("UICorner")
shopCorner.CornerRadius = UDim.new(0, 16)
shopCorner.Parent = shopWindow

local shopStroke = Instance.new("UIStroke")
shopStroke.Color = Color3.fromRGB(60, 140, 240)
shopStroke.Thickness = 3
shopStroke.Parent = shopWindow

local shopTitle = Instance.new("TextLabel")
shopTitle.Name = "Title"
shopTitle.Size = UDim2.new(1, -60, 0, 45)
shopTitle.Position = UDim2.new(0, 20, 0, 10)
shopTitle.BackgroundTransparency = 1
shopTitle.Font = Enum.Font.FredokaOne
shopTitle.TextScaled = true
shopTitle.TextColor3 = Color3.fromRGB(255, 235, 120)
shopTitle.TextXAlignment = Enum.TextXAlignment.Left
shopTitle.Text = "🛒 Tienda de Piratas (Berries)"
shopTitle.Parent = shopWindow

local shopClose = Instance.new("TextButton")
shopClose.Name = "CloseBtn"
shopClose.Size = UDim2.fromOffset(35, 35)
shopClose.Position = UDim2.new(1, -45, 0, 10)
shopClose.BackgroundColor3 = Color3.fromRGB(210, 50, 50)
shopClose.Font = Enum.Font.FredokaOne
shopClose.Text = "X"
shopClose.TextColor3 = Color3.fromRGB(255, 255, 255)
shopClose.TextScaled = true
shopClose.Parent = shopWindow

local shopCloseCorner = Instance.new("UICorner")
shopCloseCorner.CornerRadius = UDim.new(0, 8)
shopCloseCorner.Parent = shopClose

local shopScroll = Instance.new("ScrollingFrame")
shopScroll.Name = "ItemList"
shopScroll.Size = UDim2.new(1, -30, 1, -75)
shopScroll.Position = UDim2.new(0, 15, 0, 60)
shopScroll.BackgroundTransparency = 1
shopScroll.ScrollBarThickness = 6
shopScroll.Parent = shopWindow

local shopLayout = Instance.new("UIListLayout")
shopLayout.Padding = UDim.new(0, 10)
shopLayout.SortOrder = Enum.SortOrder.LayoutOrder
shopLayout.Parent = shopScroll

-- E. VENTANA DE MONETIZACIÓN (Robux - GamePasses y Productos)
local robuxWindow = Instance.new("Frame")
robuxWindow.Name = "RobuxWindow"
robuxWindow.Size = UDim2.fromOffset(540, 420)
robuxWindow.Position = UDim2.new(0.5, -270, 0.5, -210)
robuxWindow.BackgroundColor3 = Color3.fromRGB(26, 24, 34)
robuxWindow.BorderSizePixel = 0
robuxWindow.Visible = false
robuxWindow.Parent = screenGui

local robuxCorner = Instance.new("UICorner")
robuxCorner.CornerRadius = UDim.new(0, 16)
robuxCorner.Parent = robuxWindow

local robuxStroke = Instance.new("UIStroke")
robuxStroke.Color = Color3.fromRGB(240, 190, 40)
robuxStroke.Thickness = 3
robuxStroke.Parent = robuxWindow

local robuxTitle = Instance.new("TextLabel")
robuxTitle.Name = "Title"
robuxTitle.Size = UDim2.new(1, -60, 0, 45)
robuxTitle.Position = UDim2.new(0, 20, 0, 10)
robuxTitle.BackgroundTransparency = 1
robuxTitle.Font = Enum.Font.FredokaOne
robuxTitle.TextScaled = true
robuxTitle.TextColor3 = Color3.fromRGB(255, 215, 60)
robuxTitle.TextXAlignment = Enum.TextXAlignment.Left
robuxTitle.Text = "💎 Tienda VIP (GamePasses y Ventajas)"
robuxTitle.Parent = robuxWindow

local robuxClose = Instance.new("TextButton")
robuxClose.Name = "CloseBtn"
robuxClose.Size = UDim2.fromOffset(35, 35)
robuxClose.Position = UDim2.new(1, -45, 0, 10)
robuxClose.BackgroundColor3 = Color3.fromRGB(210, 50, 50)
robuxClose.Font = Enum.Font.FredokaOne
robuxClose.Text = "X"
robuxClose.TextColor3 = Color3.fromRGB(255, 255, 255)
robuxClose.TextScaled = true
robuxClose.Parent = robuxWindow

local robuxCloseCorner = Instance.new("UICorner")
robuxCloseCorner.CornerRadius = UDim.new(0, 8)
robuxCloseCorner.Parent = robuxClose

local robuxScroll = Instance.new("ScrollingFrame")
robuxScroll.Name = "ItemList"
robuxScroll.Size = UDim2.new(1, -30, 1, -75)
robuxScroll.Position = UDim2.new(0, 15, 0, 60)
robuxScroll.BackgroundTransparency = 1
robuxScroll.ScrollBarThickness = 6
robuxScroll.Parent = robuxWindow

local robuxLayout = Instance.new("UIListLayout")
robuxLayout.Padding = UDim.new(0, 10)
robuxLayout.SortOrder = Enum.SortOrder.LayoutOrder
robuxLayout.Parent = robuxScroll

-- F. VENTANA DE INVENTARIO / BASE
local invWindow = Instance.new("Frame")
invWindow.Name = "InventoryWindow"
invWindow.Size = UDim2.fromOffset(450, 320)
invWindow.Position = UDim2.new(0.5, -225, 0.5, -160)
invWindow.BackgroundColor3 = Color3.fromRGB(22, 24, 32)
invWindow.BorderSizePixel = 0
invWindow.Visible = false
invWindow.Parent = screenGui

local invCorner = Instance.new("UICorner")
invCorner.CornerRadius = UDim.new(0, 16)
invCorner.Parent = invWindow

local invStroke = Instance.new("UIStroke")
invStroke.Color = Color3.fromRGB(220, 80, 80)
invStroke.Thickness = 3
invStroke.Parent = invWindow

local invTitle = Instance.new("TextLabel")
invTitle.Name = "Title"
invTitle.Size = UDim2.new(1, -60, 0, 45)
invTitle.Position = UDim2.new(0, 20, 0, 10)
invTitle.BackgroundTransparency = 1
invTitle.Font = Enum.Font.FredokaOne
invTitle.TextScaled = true
invTitle.TextColor3 = Color3.fromRGB(255, 120, 120)
invTitle.TextXAlignment = Enum.TextXAlignment.Left
invTitle.Text = "🏴‍☠️ Estado de Tu Barco"
invTitle.Parent = invWindow

local invClose = Instance.new("TextButton")
invClose.Name = "CloseBtn"
invClose.Size = UDim2.fromOffset(35, 35)
invClose.Position = UDim2.new(1, -45, 0, 10)
invClose.BackgroundColor3 = Color3.fromRGB(210, 50, 50)
invClose.Font = Enum.Font.FredokaOne
invClose.Text = "X"
invClose.TextColor3 = Color3.fromRGB(255, 255, 255)
invClose.TextScaled = true
invClose.Parent = invWindow

local invCloseCorner = Instance.new("UICorner")
invCloseCorner.CornerRadius = UDim.new(0, 8)
invCloseCorner.Parent = invClose

local invDesc = Instance.new("TextLabel")
invDesc.Name = "Desc"
invDesc.Size = UDim2.new(1, -40, 1, -80)
invDesc.Position = UDim2.new(0, 20, 0, 65)
invDesc.BackgroundTransparency = 1
invDesc.Font = Enum.Font.FredokaOne
invDesc.TextSize = 18
invDesc.TextColor3 = Color3.fromRGB(230, 230, 230)
invDesc.TextXAlignment = Enum.TextXAlignment.Left
invDesc.TextYAlignment = Enum.TextYAlignment.Top
invDesc.TextWrapped = true
invDesc.Parent = invWindow

--------------------------------------------------------------------------------
-- 2. FUNCIÓN DE NOTIFICACIONES ANIMADAS
--------------------------------------------------------------------------------
local function showNotification(message: string, color: Color3)
	local banner = Instance.new("Frame")
	banner.Size = UDim2.fromOffset(420, 48)
	banner.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	banner.BackgroundTransparency = 0.15
	banner.BorderSizePixel = 0
	banner.Parent = notifContainer

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = banner

	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 2
	stroke.Parent = banner

	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, -20, 1, 0)
	text.Position = UDim2.new(0, 10, 0, 0)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = color
	text.Text = message
	text.Parent = banner

	banner.Position = UDim2.new(0, 0, 0, -20)
	banner.BackgroundTransparency = 1
	text.TextTransparency = 1

	local fadeIn = TweenService:Create(banner, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 0.15,
	})
	local textFadeIn = TweenService:Create(text, TweenInfo.new(0.25), { TextTransparency = 0 })
	fadeIn:Play()
	textFadeIn:Play()

	task.delay(4, function()
		if banner.Parent then
			local fadeOut = TweenService:Create(banner, TweenInfo.new(0.3), { BackgroundTransparency = 1 })
			local textFadeOut = TweenService:Create(text, TweenInfo.new(0.3), { TextTransparency = 1 })
			fadeOut:Play()
			textFadeOut:Play()
			fadeOut.Completed:Connect(function()
				banner:Destroy()
			end)
		end
	end)
end

notifyEvent.OnClientEvent:Connect(function(msg: string, col: Color3)
	showNotification(msg, col)
end)

--------------------------------------------------------------------------------
-- 3. POBLAR TIENDAS
--------------------------------------------------------------------------------
-- A. Tienda de Berries
local function addShopRow(title: string, desc: string, priceText: string, itemType: string, itemId: string)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 60)
	row.BackgroundColor3 = Color3.fromRGB(32, 36, 48)
	row.BorderSizePixel = 0
	row.Parent = shopScroll

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = row

	local tLbl = Instance.new("TextLabel")
	tLbl.Size = UDim2.new(0.65, 0, 0.5, 0)
	tLbl.Position = UDim2.new(0, 12, 0, 6)
	tLbl.BackgroundTransparency = 1
	tLbl.Font = Enum.Font.FredokaOne
	tLbl.TextScaled = true
	tLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	tLbl.TextXAlignment = Enum.TextXAlignment.Left
	tLbl.Text = title
	tLbl.Parent = row

	local dLbl = Instance.new("TextLabel")
	dLbl.Size = UDim2.new(0.65, 0, 0.4, 0)
	dLbl.Position = UDim2.new(0, 12, 0.5, 0)
	dLbl.BackgroundTransparency = 1
	dLbl.Font = Enum.Font.FredokaOne
	dLbl.TextScaled = true
	dLbl.TextColor3 = Color3.fromRGB(180, 190, 205)
	dLbl.TextXAlignment = Enum.TextXAlignment.Left
	dLbl.Text = desc
	dLbl.Parent = row

	local buyBtn = Instance.new("TextButton")
	buyBtn.Size = UDim2.new(0.3, -15, 0.75, 0)
	buyBtn.Position = UDim2.new(0.7, 5, 0.125, 0)
	buyBtn.BackgroundColor3 = Color3.fromRGB(46, 160, 75)
	buyBtn.Font = Enum.Font.FredokaOne
	buyBtn.TextScaled = true
	buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	buyBtn.Text = priceText
	buyBtn.Parent = row

	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(0, 8)
	bCorner.Parent = buyBtn

	buyBtn.MouseButton1Click:Connect(function()
		buyRemote:FireServer(itemType, itemId)
	end)
end

for chestId, data in GameConfig.Chests do
	addShopRow(data.DisplayName, "Cofre con Frutas Místicas", tostring(data.Cost) .. " 🪙", "Chest", chestId)
end
addShopRow("🛡️ Escudo Temporal (60s)", "Protección total contra robos", tostring(GameConfig.Defenses.Shield.Cost) .. " 🪙", "Shield", "Default")
addShopRow("⛓️ Mejorar Cadenas", "Aumenta el tiempo para robarte", "Mejorar 🪙", "Chains", "Upgrade")
addShopRow("💣 Mejorar Cañón", "Dispara automáticamente a ladrones", "Mejorar 🪙", "Cannon", "Upgrade")

-- B. Tienda de Robux (GamePasses y Developer Products)
local function addRobuxRow(title: string, desc: string, purchaseType: string, targetId: number)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 60)
	row.BackgroundColor3 = Color3.fromRGB(38, 34, 48)
	row.BorderSizePixel = 0
	row.Parent = robuxScroll

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = row

	local tLbl = Instance.new("TextLabel")
	tLbl.Size = UDim2.new(0.68, 0, 0.5, 0)
	tLbl.Position = UDim2.new(0, 12, 0, 6)
	tLbl.BackgroundTransparency = 1
	tLbl.Font = Enum.Font.FredokaOne
	tLbl.TextScaled = true
	tLbl.TextColor3 = Color3.fromRGB(255, 215, 80)
	tLbl.TextXAlignment = Enum.TextXAlignment.Left
	tLbl.Text = title
	tLbl.Parent = row

	local dLbl = Instance.new("TextLabel")
	dLbl.Size = UDim2.new(0.68, 0, 0.4, 0)
	dLbl.Position = UDim2.new(0, 12, 0.5, 0)
	dLbl.BackgroundTransparency = 1
	dLbl.Font = Enum.Font.FredokaOne
	dLbl.TextScaled = true
	dLbl.TextColor3 = Color3.fromRGB(200, 195, 210)
	dLbl.TextXAlignment = Enum.TextXAlignment.Left
	dLbl.Text = desc
	dLbl.Parent = row

	local buyBtn = Instance.new("TextButton")
	buyBtn.Size = UDim2.new(0.28, -15, 0.75, 0)
	buyBtn.Position = UDim2.new(0.72, 5, 0.125, 0)
	buyBtn.BackgroundColor3 = Color3.fromRGB(220, 160, 30)
	buyBtn.Font = Enum.Font.FredokaOne
	buyBtn.TextScaled = true
	buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	buyBtn.Text = "Comprar R$"
	buyBtn.Parent = row

	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(0, 8)
	bCorner.Parent = buyBtn

	buyBtn.MouseButton1Click:Connect(function()
		promptPurchaseEvent:FireServer(purchaseType, targetId)
	end)
end

-- Agregar GamePasses
for _, passData in GameConfig.GamePasses do
	addRobuxRow("⭐ " .. passData.DisplayName, passData.Description, "GamePass", passData.Id)
end

-- Agregar Developer Products
for _, prodData in GameConfig.DeveloperProducts do
	local desc = (prodData :: any).Description or ("Añade " .. tostring((prodData :: any).Amount) .. " Berries al instante")
	addRobuxRow("💎 " .. prodData.DisplayName, desc, "Product", prodData.Id)
end

--------------------------------------------------------------------------------
-- 4. CONTROL DE VENTANAS Y ESTADÍSTICAS
--------------------------------------------------------------------------------
shopButton.MouseButton1Click:Connect(function()
	shopWindow.Visible = not shopWindow.Visible
	if shopWindow.Visible then
		robuxWindow.Visible = false
		invWindow.Visible = false
	end
end)

robuxButton.MouseButton1Click:Connect(function()
	robuxWindow.Visible = not robuxWindow.Visible
	if robuxWindow.Visible then
		shopWindow.Visible = false
		invWindow.Visible = false
	end
end)

invButton.MouseButton1Click:Connect(function()
	invWindow.Visible = not invWindow.Visible
	if invWindow.Visible then
		shopWindow.Visible = false
		robuxWindow.Visible = false
		local baseName = localPlayer:GetAttribute("AssignedBase") or "Buscando..."
		local bps = localPlayer:GetAttribute("BerriesPerSecond") or 0
		invDesc.Text = string.format(
			"⚓ Barco Asignado: %s\n\n💰 Generación Actual: +%d Berries/s\n\n💡 Consejos Piratas:\n• Vende frutas comunes en tus pedestales (Tecla X) para abrir espacio a cofres legendarios.\n• Lleva tu Sable de Abordaje equipado para perseguir ladrones.\n• Entrega frutas robadas en tu DropZone verde.",
			tostring(baseName),
			bps
		)
	end
end)

shopClose.MouseButton1Click:Connect(function() shopWindow.Visible = false end)
robuxClose.MouseButton1Click:Connect(function() robuxWindow.Visible = false end)
invClose.MouseButton1Click:Connect(function() invWindow.Visible = false end)

local function updateStats()
	local berries = localPlayer:GetAttribute("Berries") or 0
	local rate = localPlayer:GetAttribute("BerriesPerSecond") or 0
	berriesLabel.Text = string.format("%s Berries", tostring(berries))
	rateLabel.Text = string.format("+%s Berries/s", tostring(rate))
end

localPlayer:GetAttributeChangedSignal("Berries"):Connect(updateStats)
localPlayer:GetAttributeChangedSignal("BerriesPerSecond"):Connect(updateStats)
updateStats()
