--!strict
-- Ubicación en Roblox Studio: ServerScriptService/Modules/StealManager (ModuleScript)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GameConfig"))
local BaseManager = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("BaseManager"))
local ChestManager = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("ChestManager"))
local PlayerSession = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("PlayerSession"))
local ProductionManager = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("ProductionManager"))

local StealManager = {}

export type ActiveHeist = {
	Thief: Player,
	VictimOwner: Player,
	VictimSlot: BaseManager.SlotData,
	FruitId: string,
	CarriedModel: Model?,
}

-- Registro en servidor de quién lleva una fruta robada en este instante
local activeHeistsByThief: { [Player]: ActiveHeist } = {}
local weaponCooldowns: { [Player]: number } = {}

local function notifyPlayer(player: Player, message: string, color: Color3?)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local notifyEvent = if remotes then remotes:FindFirstChild("NotifyEvent") :: RemoteEvent? else nil
	if notifyEvent then
		notifyEvent:FireClient(player, message, color or Color3.fromRGB(255, 255, 255))
	end
end

-- Calcula y aplica la velocidad correcta del jugador según si lleva fruta o tiene GamePass
function StealManager.UpdatePlayerWalkSpeed(player: Player)
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local session = PlayerSession.Get(player)
	local speedMult = if session and session.DoubleSpeed then 1.6 else 1.0

	if activeHeistsByThief[player] ~= nil then
		humanoid.WalkSpeed = GameConfig.Stealing.CarryingWalkSpeed * speedMult
	else
		humanoid.WalkSpeed = GameConfig.Stealing.DefaultWalkSpeed * speedMult
	end
end

-- Oculta o muestra el modelo de la fruta en el pedestal original mientras está en robo
local function setSlotModelGhostState(slotData: BaseManager.SlotData, isGhost: boolean)
	if not slotData.FruitModel then return end

	for _, desc in slotData.FruitModel:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Transparency = if isGhost then 0.75 else 0
		elseif desc:IsA("ProximityPrompt") then
			desc.Enabled = not isGhost
		end
	end
end

-- Crea el modelo de la fruta sobre la cabeza del ladrón para que todos vean que está robando
local function attachCarriedFruitToThief(thief: Player, fruitInfo: GameConfig.FruitInfo): Model?
	local character = thief.Character
	if not character then return nil end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then return nil end

	local carriedModel = ChestManager.CreateFruitVisualModel(fruitInfo)
	carriedModel.Name = "StolenFruitCarried"

	-- Ajustar propiedades físicas para que no altere las colisiones del jugador
	for _, desc in carriedModel:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Anchored = false
			desc.CanCollide = false
			desc.Massless = true
		elseif desc:IsA("ProximityPrompt") then
			desc:Destroy()
		end
	end

	local primary = carriedModel.PrimaryPart or carriedModel:FindFirstChildWhichIsA("BasePart")
	if not primary then
		carriedModel:Destroy()
		return nil
	end

	-- Soldar tallo o partes secundarias al Handle principal
	for _, desc in carriedModel:GetDescendants() do
		if desc:IsA("BasePart") and desc ~= primary then
			local weldPart = Instance.new("WeldConstraint")
			weldPart.Part0 = primary
			weldPart.Part1 = desc
			weldPart.Parent = primary
		end
	end

	-- Posicionar encima de la cabeza del ladrón
	carriedModel:PivotTo(rootPart.CFrame * CFrame.new(0, 3.6, 0))
	carriedModel.Parent = character

	local weld = Instance.new("WeldConstraint")
	weld.Name = "CarryWeld"
	weld.Part0 = rootPart
	weld.Part1 = primary
	weld.Parent = primary

	-- Cambiar texto del cartel flotante a ALERTA DE LADRÓN
	local billboard = primary:FindFirstChild("FruitBillboard") :: BillboardGui?
	if billboard then
		local title = billboard:FindFirstChild("Title") :: TextLabel?
		if title then
			title.Text = "🚨 ¡ROBANDO " .. string.upper(fruitInfo.DisplayName) .. "! 🚨"
			title.TextColor3 = Color3.fromRGB(255, 60, 60)
		end
	end

	return carriedModel
end

-- Devuelve la fruta robada a su dueño original (cuando golpean al ladrón, muere o sale del juego)
function StealManager.ReturnStolenFruit(thief: Player, reasonMessage: string?)
	local heist = activeHeistsByThief[thief]
	if not heist then return end

	activeHeistsByThief[thief] = nil
	thief:SetAttribute("CarryingFruit", nil)

	if heist.CarriedModel then
		heist.CarriedModel:Destroy()
		heist.CarriedModel = nil
	end

	StealManager.UpdatePlayerWalkSpeed(thief)

	-- Si el dueño original sigue en el servidor y el slot sigue siendo suyo, restauramos su fruta
	local victimBase = BaseManager.GetPlayerBase(heist.VictimOwner)
	if victimBase and victimBase.Owner == heist.VictimOwner then
		heist.VictimSlot.IsStolenInTransit = false
		setSlotModelGhostState(heist.VictimSlot, false)
		BaseManager.RefreshSlotVisual(heist.VictimSlot)

		local fruitInfo = GameConfig.Fruits[heist.FruitId]
		local fruitName = if fruitInfo then fruitInfo.DisplayName else "Fruta"

		notifyPlayer(
			heist.VictimOwner,
			"🛡️ ¡Recuperaste tu " .. fruitName .. "! Ha vuelto a salvo a tu barco.",
			Color3.fromRGB(100, 255, 140)
		)
	end

	if reasonMessage and thief.Parent == Players then
		notifyPlayer(thief, reasonMessage, Color3.fromRGB(255, 90, 90))
	end
end

-- Inicia un robo cuando un jugador completa el ProximityPrompt en un barco ajeno
function StealManager.TryStartSteal(
	thief: Player,
	victimOwner: Player,
	slotData: BaseManager.SlotData,
	fruitId: string
)
	-- 1. Validar que no sea su propio barco y que ambos sigan activos
	if thief == victimOwner then return end
	if activeHeistsByThief[thief] ~= nil then
		notifyPlayer(thief, "⚠️ ¡Ya llevas una fruta robada en las manos! Llévala a tu barco primero.", Color3.fromRGB(255, 190, 60))
		return
	end

	-- 2. Validar que la fruta siga ahí y no esté siendo robada por otro
	if slotData.FruitId ~= fruitId or slotData.IsStolenInTransit then
		notifyPlayer(thief, "❌ ¡Alguien más ya se está llevando esta fruta!", Color3.fromRGB(255, 90, 90))
		return
	end

	-- 3. Validar que el barco víctima no tenga Escudo activo (Sistema 5 / GamePass)
	local victimBase = BaseManager.GetPlayerBase(victimOwner)
	if not victimBase or victimBase.Owner ~= victimOwner then return end

	if victimBase.ShieldActive then
		notifyPlayer(thief, "🛡️ ¡El barco de " .. victimOwner.DisplayName .. " está protegido por un Escudo Místico!", Color3.fromRGB(80, 200, 255))
		return
	end

	-- 4. Validar que el ladrón tenga al menos un pedestal libre en su barco
	local thiefFreeSlot = BaseManager.GetFirstAvailableSlot(thief)
	if not thiefFreeSlot then
		notifyPlayer(thief, "⚠️ ¡Tu barco está lleno! Libera un pedestal en tu barco antes de robar.", Color3.fromRGB(255, 180, 60))
		return
	end

	-- 5. Validación Anti-Exploit de distancia en el servidor
	local thiefChar = thief.Character
	local thiefRoot = if thiefChar then thiefChar:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if not thiefRoot then return end

	local distance = (thiefRoot.Position - slotData.Part.Position).Magnitude
	if distance > 14 then
		warn("[Anti-Exploit] " .. thief.Name .. " intentó robar desde una distancia inválida: " .. tostring(distance))
		return
	end

	local fruitInfo = GameConfig.Fruits[fruitId]
	if not fruitInfo then return end

	-- 6. Marcar slot como "En Robo" y colocar la fruta en manos del ladrón
	slotData.IsStolenInTransit = true
	setSlotModelGhostState(slotData, true)
	BaseManager.RefreshSlotVisual(slotData)

	local carriedModel = attachCarriedFruitToThief(thief, fruitInfo)

	activeHeistsByThief[thief] = {
		Thief = thief,
		VictimOwner = victimOwner,
		VictimSlot = slotData,
		FruitId = fruitId,
		CarriedModel = carriedModel,
	}

	thief:SetAttribute("CarryingFruit", fruitId)
	StealManager.UpdatePlayerWalkSpeed(thief)

	-- 7. Alertar a la víctima y al ladrón
	notifyPlayer(
		thief,
		"🏴‍☠️ ¡Tienes la " .. fruitInfo.DisplayName .. "! ¡Corre a la DropZone verde de tu barco antes de que te golpeen!",
		Color3.fromRGB(255, 210, 70)
	)
	notifyPlayer(
		victimOwner,
		"🚨 ¡ALERTA PIRATA! ¡" .. thief.DisplayName .. " está robando tu " .. fruitInfo.DisplayName .. "! ¡Usa tu Sable de Abordaje para golpearlo!",
		Color3.fromRGB(255, 60, 60)
	)
end

-- Completa el robo cuando el ladrón pisa su propia DropZone
function StealManager.TryCompleteHeist(thief: Player)
	local heist = activeHeistsByThief[thief]
	if not heist then return end

	local freeSlot = BaseManager.GetFirstAvailableSlot(thief)
	if not freeSlot then
		notifyPlayer(thief, "⚠️ ¡No tienes pedestales libres en tu barco para asegurar la fruta!", Color3.fromRGB(255, 180, 50))
		return
	end

	activeHeistsByThief[thief] = nil
	thief:SetAttribute("CarryingFruit", nil)

	if heist.CarriedModel then
		heist.CarriedModel:Destroy()
		heist.CarriedModel = nil
	end

	StealManager.UpdatePlayerWalkSpeed(thief)

	-- Eliminar definitivamente la fruta del barco de la víctima
	local victimBase = BaseManager.GetPlayerBase(heist.VictimOwner)
	if victimBase and victimBase.Owner == heist.VictimOwner then
		heist.VictimSlot.FruitId = nil
		heist.VictimSlot.IsStolenInTransit = false
		if heist.VictimSlot.FruitModel then
			heist.VictimSlot.FruitModel:Destroy()
			heist.VictimSlot.FruitModel = nil
		end
		BaseManager.RefreshSlotVisual(heist.VictimSlot)
	end

	-- Colocar la fruta en el pedestal del ladrón
	ChestManager.PlaceFruitInSlot(thief, freeSlot, heist.FruitId)

	local fruitInfo = GameConfig.Fruits[heist.FruitId]
	local fruitName = if fruitInfo then fruitInfo.DisplayName else "Fruta"

	notifyPlayer(
		thief,
		"🎉 ¡ROBO EXITOSO! Aseguraste la " .. fruitName .. " de " .. heist.VictimOwner.DisplayName .. " en tu barco.",
		Color3.fromRGB(100, 255, 130)
	)

	if heist.VictimOwner.Parent == Players then
		notifyPlayer(
			heist.VictimOwner,
			"💀 ¡" .. thief.DisplayName .. " llegó a su barco y se quedó con tu " .. fruitName .. "!",
			Color3.fromRGB(255, 70, 70)
		)
	end
end

-- Crea y entrega la herramienta "Sable de Abordaje" para defender el barco y atrapar ladrones
function StealManager.GiveDefenseWeapon(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return end

	if backpack:FindFirstChild("SableAbordaje") then return end
	if player.Character and player.Character:FindFirstChild("SableAbordaje") then return end

	local tool = Instance.new("Tool")
	tool.Name = "SableAbordaje"
	tool.ToolTip = "Golpea a los ladrones para recuperar tus Frutas Místicas"
	tool.RequiresHandle = true
	tool.CanBeDropped = false

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 3.2, 0.8)
	handle.Material = Enum.Material.Metal
	handle.Color = Color3.fromRGB(210, 215, 225)
	handle.CanCollide = false
	handle.Parent = tool

	tool.GripPos = Vector3.new(0, -1.1, 0)

	tool.Activated:Connect(function()
		local now = os.clock()
		local lastSwing = weaponCooldowns[player] or 0
		if now - lastSwing < GameConfig.Stealing.WeaponCooldown then
			return
		end
		weaponCooldowns[player] = now

		local char = player.Character
		local root = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		local humanoid = if char then char:FindFirstChildOfClass("Humanoid") else nil
		if not root or not humanoid or humanoid.Health <= 0 then return end

		-- Animación rápida de tajo (compatible con R15 y R6)
		local toolAnim = Instance.new("StringValue")
		toolAnim.Name = "toolanim"
		toolAnim.Value = "Slash"
		toolAnim.Parent = tool

		-- Detectar en el servidor si hay un jugador enemigo dentro del rango del golpe
		for _, targetPlayer in Players:GetPlayers() do
			if targetPlayer == player then continue end

			local targetChar = targetPlayer.Character
			local targetRoot = if targetChar then targetChar:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
			local targetHum = if targetChar then targetChar:FindFirstChildOfClass("Humanoid") else nil

			if targetRoot and targetHum and targetHum.Health > 0 then
				local dist = (targetRoot.Position - root.Position).Magnitude
				if dist <= GameConfig.Stealing.HitboxRange then
					-- Empujar ligeramente al oponente y aturdirlo
					local knockbackDir = (targetRoot.Position - root.Position).Unit
					targetRoot.AssemblyLinearVelocity = (knockbackDir * 35) + Vector3.new(0, 20, 0)

					-- Si el objetivo lleva una fruta robada, la suelta inmediatamente y vuelve a su dueño
					if activeHeistsByThief[targetPlayer] ~= nil then
						StealManager.ReturnStolenFruit(
							targetPlayer,
							"💥 ¡" .. player.DisplayName .. " te golpeó con su Sable y perdiste la fruta robada!"
						)
						notifyPlayer(
							player,
							"⚔️ ¡Atrapaste a " .. targetPlayer.DisplayName .. "! La fruta robada fue devuelta a su barco.",
							Color3.fromRGB(100, 255, 150)
						)
					end

					-- Aturdir brevemente al ladrón golpeado
					targetHum.PlatformStand = true
					task.delay(GameConfig.Stealing.StunDuration, function()
						if targetHum and targetHum.Parent then
							targetHum.PlatformStand = false
						end
					end)
				end
			end
		end
	end)

	tool.Parent = backpack
end

-- Conecta los eventos de personaje (muerte, desconexión y entrega de sable)
function StealManager.SetupPlayer(player: Player)
	player.CharacterAdded:Connect(function(character: Model)
		-- Si reaparece, nos aseguramos de limpiar cualquier robo pendiente y darle su sable
		StealManager.ReturnStolenFruit(player, "💀 Moriste durante el escape y la fruta volvió a su dueño.")

		local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
		if humanoid then
			humanoid.Died:Connect(function()
				StealManager.ReturnStolenFruit(player, "💀 ¡Fuiste derribado! La fruta volvió al barco original.")
			end)
		end

		task.defer(function()
			StealManager.GiveDefenseWeapon(player)
			StealManager.UpdatePlayerWalkSpeed(player)
		end)
	end)
end

function StealManager.CleanupPlayer(player: Player)
	-- Si el jugador que se va tenía una fruta robada en la mano, la devolvemos
	StealManager.ReturnStolenFruit(player, nil)

	-- Si alguien estaba robándole a este jugador que se acaba de desconectar, cancelamos
	for thief, heist in activeHeistsByThief do
		if heist.VictimOwner == player then
			activeHeistsByThief[thief] = nil
			thief:SetAttribute("CarryingFruit", nil)
			if heist.CarriedModel then
				heist.CarriedModel:Destroy()
			end
			StealManager.UpdatePlayerWalkSpeed(thief)
			notifyPlayer(thief, "⚠️ El dueño del barco se desconectó del servidor.", Color3.fromRGB(255, 180, 60))
		end
	end

	weaponCooldowns[player] = nil
end

function StealManager.Init()
	ChestManager.SetStealCallback(StealManager.TryStartSteal)
	ProductionManager.SetDropZoneDeliveryCallback(StealManager.TryCompleteHeist)
end

return StealManager
