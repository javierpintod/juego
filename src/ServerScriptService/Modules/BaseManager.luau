--!strict
-- Ubicación en Roblox Studio: ServerScriptService/Modules/BaseManager (ModuleScript)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GameConfig"))
local PlayerSession = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("PlayerSession"))

local BaseManager = {}

export type SlotData = {
	Index: number,
	Part: BasePart,
	Unlocked: boolean,
	FruitId: string?,
	FruitModel: Model?,
	IsStolenInTransit: boolean,
	UnlockPrompt: ProximityPrompt?,
}

export type BaseData = {
	Model: Model,
	Owner: Player?,
	Slots: { [number]: SlotData },
	ShieldActive: boolean,
	PermanentShield: boolean,
	ShieldExpiresAt: number,
	ShieldCooldownUntil: number,
	ChainsLevel: number,
	CannonLevel: number,
	StoredBerries: number,
}

local basesByName: { [string]: BaseData } = {}
local playerToBase: { [Player]: BaseData } = {}

local basesFolder = Workspace:WaitForChild("Bases")

local function notifyPlayer(player: Player, message: string, color: Color3?)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local notifyEvent = if remotes then remotes:FindFirstChild("NotifyEvent") :: RemoteEvent? else nil
	if notifyEvent then
		notifyEvent:FireClient(player, message, color or Color3.fromRGB(255, 255, 255))
	end
end

local function updateBaseSign(baseData: BaseData)
	local signPart = baseData.Model:FindFirstChild("SignPart")
	if not signPart then return end

	local ownerGui = signPart:FindFirstChild("OwnerGui")
	if not ownerGui then return end

	local ownerText = ownerGui:FindFirstChild("OwnerText") :: TextLabel?
	if not ownerText then return end

	if baseData.Owner then
		ownerText.Text = "🏴‍☠️ Barco de " .. baseData.Owner.DisplayName
		ownerText.TextColor3 = Color3.fromRGB(255, 230, 100)
	else
		ownerText.Text = "⚓ Barco Libre"
		ownerText.TextColor3 = Color3.fromRGB(200, 200, 200)
	end
end

local function updateSlotVisual(slotData: SlotData)
	local billboard = slotData.Part:FindFirstChild("SlotInfoGui") :: BillboardGui?
	if not billboard then
		billboard = Instance.new("BillboardGui")
		billboard.Name = "SlotInfoGui"
		billboard.Size = UDim2.fromOffset(140, 45)
		billboard.StudsOffset = Vector3.new(0, 2.5, 0)
		billboard.AlwaysOnTop = false
		billboard.MaxDistance = 35
		billboard.Parent = slotData.Part

		local label = Instance.new("TextLabel")
		label.Name = "StatusLabel"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.TextStrokeTransparency = 0.2
		label.Parent = billboard
	end

	local statusLabel = billboard:FindFirstChild("StatusLabel") :: TextLabel

	if slotData.UnlockPrompt then
		slotData.UnlockPrompt.Enabled = not slotData.Unlocked
	end

	if not slotData.Unlocked then
		slotData.Part.Color = Color3.fromRGB(90, 40, 40)
		if slotData.Index == 5 then
			statusLabel.Text = "🔒 Slot 5 (" .. tostring(GameConfig.Bases.ExtraSlotCost) .. " Berries)"
		else
			statusLabel.Text = "🔒 Slot VIP (GamePass)"
		end
		statusLabel.TextColor3 = Color3.fromRGB(255, 110, 110)
	elseif slotData.IsStolenInTransit then
		slotData.Part.Color = Color3.fromRGB(220, 70, 40)
		statusLabel.Text = "🚨 ¡EN ROBO!"
		statusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
	elseif slotData.FruitId == nil then
		slotData.Part.Color = Color3.fromRGB(80, 160, 90)
		statusLabel.Text = "Pedestal Libre"
		statusLabel.TextColor3 = Color3.fromRGB(180, 255, 180)
	else
		slotData.Part.Color = Color3.fromRGB(210, 170, 60)
		statusLabel.Text = ""
	end
end

local function setupSlotUnlockPrompt(baseData: BaseData, slotData: SlotData)
	if slotData.Index <= GameConfig.Bases.BaseSlots then return end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "UnlockSlotPrompt"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false

	if slotData.Index == 5 then
		prompt.ObjectText = "Pedestal Extra #5"
		prompt.ActionText = "Desbloquear (" .. tostring(GameConfig.Bases.ExtraSlotCost) .. " Berries)"
	else
		prompt.ObjectText = "Pedestal VIP #6"
		prompt.ActionText = "Requiere Pase Slot Extra"
	end

	prompt.Parent = slotData.Part
	slotData.UnlockPrompt = prompt

	prompt.Triggered:Connect(function(player: Player)
		if baseData.Owner ~= player then
			notifyPlayer(player, "⛔ Este barco no te pertenece.", Color3.fromRGB(255, 80, 80))
			return
		end

		if slotData.Unlocked then return end

		if slotData.Index == 5 then
			if PlayerSession.SpendBerries(player, GameConfig.Bases.ExtraSlotCost) then
				slotData.Unlocked = true
				updateSlotVisual(slotData)
				notifyPlayer(player, "🔓 ¡Has desbloqueado el Pedestal #5!", Color3.fromRGB(100, 255, 140))
			else
				notifyPlayer(
					player,
					"❌ Necesitas " .. tostring(GameConfig.Bases.ExtraSlotCost) .. " Berries para desbloquear este pedestal.",
					Color3.fromRGB(255, 80, 80)
				)
			end
		elseif slotData.Index == 6 then
			notifyPlayer(player, "⭐ El Pedestal #6 se desbloquea con el GamePass 'Slot Extra'.", Color3.fromRGB(255, 215, 0))
		end
	end)
end

function BaseManager.Init()
	for _, baseInstance in basesFolder:GetChildren() do
		if not baseInstance:IsA("Model") then continue end

		local slotsFolder = baseInstance:FindFirstChild("Slots")
		if not slotsFolder then
			warn("[BaseManager] La base " .. baseInstance.Name .. " no tiene carpeta 'Slots'")
			continue
		end

		local slotsTable: { [number]: SlotData } = {}

		local newBaseData: BaseData = {
			Model = baseInstance,
			Owner = nil,
			Slots = slotsTable,
			ShieldActive = false,
			PermanentShield = false,
			ShieldExpiresAt = 0,
			ShieldCooldownUntil = 0,
			ChainsLevel = 0,
			CannonLevel = 0,
			StoredBerries = 0,
		}

		for i = 1, GameConfig.Bases.MaxSlots do
			local slotPart = slotsFolder:FindFirstChild("Slot_" .. i) :: BasePart?
			if slotPart then
				local unlockedByDefault = (i <= GameConfig.Bases.BaseSlots)
				local slotData: SlotData = {
					Index = i,
					Part = slotPart,
					Unlocked = unlockedByDefault,
					FruitId = nil,
					FruitModel = nil,
					IsStolenInTransit = false,
					UnlockPrompt = nil,
				}
				slotsTable[i] = slotData
				setupSlotUnlockPrompt(newBaseData, slotData)
				updateSlotVisual(slotData)
			else
				warn(string.format("[BaseManager] Falta Slot_%d en %s", i, baseInstance.Name))
			end
		end

		basesByName[baseInstance.Name] = newBaseData
		updateBaseSign(newBaseData)
	end
end

function BaseManager.AssignBaseToPlayer(player: Player): BaseData?
	if playerToBase[player] then
		return playerToBase[player]
	end

	for _, baseData in basesByName do
		if baseData.Owner == nil then
			baseData.Owner = player
			baseData.StoredBerries = 0
			baseData.ShieldActive = false
			baseData.PermanentShield = false
			baseData.ShieldExpiresAt = 0
			baseData.ShieldCooldownUntil = 0
			baseData.ChainsLevel = 0
			baseData.CannonLevel = 0
			playerToBase[player] = baseData

			player:SetAttribute("AssignedBase", baseData.Model.Name)
			baseData.Model:SetAttribute("OwnerUserId", player.UserId)

			for i, slot in baseData.Slots do
				slot.Unlocked = (i <= GameConfig.Bases.BaseSlots)
				slot.FruitId = nil
				slot.IsStolenInTransit = false
				if slot.FruitModel then
					slot.FruitModel:Destroy()
					slot.FruitModel = nil
				end
				updateSlotVisual(slot)
			end

			updateBaseSign(baseData)
			return baseData
		end
	end

	warn("[BaseManager] ¡No hay barcos disponibles para " .. player.Name .. "!")
	return nil
end

function BaseManager.TeleportPlayerToBase(player: Player, character: Model)
	local baseData = playerToBase[player]
	if not baseData then return end

	local spawnPoint = baseData.Model:FindFirstChild("SpawnPoint") :: BasePart?
	if spawnPoint then
		task.defer(function()
			if character.Parent then
				character:PivotTo(spawnPoint.CFrame + Vector3.new(0, 3.5, 0))
			end
		end)
	end
end

function BaseManager.ReleasePlayerBase(player: Player)
	local baseData = playerToBase[player]
	if not baseData then return end

	for i, slot in baseData.Slots do
		if slot.FruitModel then
			slot.FruitModel:Destroy()
			slot.FruitModel = nil
		end
		slot.FruitId = nil
		slot.IsStolenInTransit = false
		slot.Unlocked = (i <= GameConfig.Bases.BaseSlots)
		updateSlotVisual(slot)
	end

	baseData.Owner = nil
	baseData.ShieldActive = false
	baseData.PermanentShield = false
	baseData.ShieldExpiresAt = 0
	baseData.ShieldCooldownUntil = 0
	baseData.ChainsLevel = 0
	baseData.CannonLevel = 0
	baseData.StoredBerries = 0
	baseData.Model:SetAttribute("OwnerUserId", nil)
	playerToBase[player] = nil

	updateBaseSign(baseData)
end

function BaseManager.GetFirstAvailableSlot(player: Player): SlotData?
	local baseData = playerToBase[player]
	if not baseData then return nil end

	for i = 1, GameConfig.Bases.MaxSlots do
		local slot = baseData.Slots[i]
		if slot and slot.Unlocked and slot.FruitId == nil and not slot.IsStolenInTransit then
			return slot
		end
	end

	return nil
end

function BaseManager.GetPlayerBase(player: Player): BaseData?
	return playerToBase[player]
end

function BaseManager.GetAllBases(): { [string]: BaseData }
	return basesByName
end

function BaseManager.RefreshSlotVisual(slotData: SlotData)
	updateSlotVisual(slotData)
end

function BaseManager.UnlockSlot(player: Player, slotIndex: number)
	local baseData = playerToBase[player]
	if not baseData then return end

	local slot = baseData.Slots[slotIndex]
	if slot then
		slot.Unlocked = true
		updateSlotVisual(slot)
	end
end

return BaseManager
