--!strict
-- Ubicación en Roblox Studio: ServerScriptService/Modules/DefenseManager (ModuleScript)

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GameConfig"))
local BaseManager = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("BaseManager"))
local PlayerSession = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("PlayerSession"))
local StealManager = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("StealManager"))

local DefenseManager = {}

type BaseDefenseVisuals = {
	ShieldDome: BasePart,
	ShieldBillboardLabel: TextLabel,
	ShieldPrompt: ProximityPrompt,
	ChainsPrompt: ProximityPrompt,
	CannonPrompt: ProximityPrompt,
	CannonBarrel: BasePart,
	LastCannonShot: number,
}

local visualsByBase: { [BaseManager.BaseData]: BaseDefenseVisuals } = {}

local function notifyPlayer(player: Player, message: string, color: Color3?)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local notifyEvent = if remotes then remotes:FindFirstChild("NotifyEvent") :: RemoteEvent? else nil
	if notifyEvent then
		notifyEvent:FireClient(player, message, color or Color3.fromRGB(255, 255, 255))
	end
end

-- Actualiza el tiempo de robo (HoldDuration) y aros visuales de cadenas en todos los pedestales del barco
local function applyChainsToBaseSlots(baseData: BaseManager.BaseData)
	local chainsLvl = baseData.ChainsLevel
	local chainInfo = if chainsLvl > 0 then GameConfig.Defenses.Chains.Levels[chainsLvl] else nil
	local extraHold = if chainInfo then chainInfo.ExtraHoldTime else 0

	for _, slot in baseData.Slots do
		-- Actualizar o crear el aro visual de cadenas en el pedestal
		local chainRing = slot.Part:FindFirstChild("ChainVisual") :: BasePart?
		if chainsLvl > 0 then
			if not chainRing then
				chainRing = Instance.new("Part")
				chainRing.Name = "ChainVisual"
				chainRing.Shape = Enum.PartType.Cylinder
				chainRing.Size = Vector3.new(0.35, 4.6, 4.6)
				chainRing.CFrame = slot.Part.CFrame * CFrame.new(0, 0.4, 0) * CFrame.Angles(0, 0, math.rad(90))
				chainRing.Material = Enum.Material.CorrodedMetal
				chainRing.Anchored = true
				chainRing.CanCollide = false
				chainRing.Parent = slot.Part
			end

			if chainsLvl == 1 then
				chainRing.Color = Color3.fromRGB(170, 110, 60) -- Bronce
			elseif chainsLvl == 2 then
				chainRing.Color = Color3.fromRGB(180, 195, 210) -- Acero
			else
				chainRing.Color = Color3.fromRGB(45, 55, 85) -- Kairoseki (Hierro Marino Oscuro)
			end
		elseif chainRing then
			chainRing:Destroy()
		end

		-- Actualizar el ProximityPrompt de robo si hay una fruta colocada
		if slot.FruitModel then
			local primary = slot.FruitModel.PrimaryPart or slot.FruitModel:FindFirstChildWhichIsA("BasePart")
			local stealPrompt = if primary then primary:FindFirstChild("StealFruitPrompt") :: ProximityPrompt? else nil
			if stealPrompt then
				stealPrompt.HoldDuration = GameConfig.Stealing.StealHoldDuration + extraHold
				stealPrompt.ActionText = if chainsLvl > 0
					then "⛓️ Robar Fruta (Cadenas Nv." .. tostring(chainsLvl) .. ")"
					else "🏴‍☠️ Robar Fruta"
			end
		end
	end
end

-- Actualiza los textos de los 3 botones de defensa en el barco
local function refreshDefensePrompts(baseData: BaseManager.BaseData)
	local vis = visualsByBase[baseData]
	if not vis then return end

	-- 1. Prompt de Escudo
	if baseData.PermanentShield then
		vis.ShieldPrompt.ObjectText = "Escudo Permanente VIP"
		vis.ShieldPrompt.ActionText = "🛡️ Activo para siempre"
	elseif baseData.ShieldActive then
		local remaining = math.max(0, math.ceil(baseData.ShieldExpiresAt - os.clock()))
		vis.ShieldPrompt.ObjectText = "Escudo Místico Activo"
		vis.ShieldPrompt.ActionText = "🛡️ Tiempo restante: " .. tostring(remaining) .. "s"
	else
		local cooldownLeft = math.ceil(baseData.ShieldCooldownUntil - os.clock())
		if cooldownLeft > 0 then
			vis.ShieldPrompt.ObjectText = "Escudo Recargándose"
			vis.ShieldPrompt.ActionText = "⏳ Disponible en " .. tostring(cooldownLeft) .. "s"
		else
			vis.ShieldPrompt.ObjectText = "Escudo Temporal (" .. tostring(GameConfig.Defenses.Shield.DurationSeconds) .. "s)"
			vis.ShieldPrompt.ActionText = "Activar por " .. tostring(GameConfig.Defenses.Shield.Cost) .. " Berries"
		end
	end

	-- 2. Prompt de Cadenas
	local nextChainsLvl = baseData.ChainsLevel + 1
	local nextChainsData = GameConfig.Defenses.Chains.Levels[nextChainsLvl]
	if nextChainsData then
		vis.ChainsPrompt.ObjectText = nextChainsData.DisplayName
		vis.ChainsPrompt.ActionText = "Mejorar (" .. tostring(nextChainsData.Cost) .. " Berries)"
	else
		vis.ChainsPrompt.ObjectText = "Cadenas de Kairoseki (MÁX)"
		vis.ChainsPrompt.ActionText = "✅ Nivel Máximo Alcanzado"
	end

	-- 3. Prompt de Cañón
	local nextCannonLvl = baseData.CannonLevel + 1
	local nextCannonData = GameConfig.Defenses.Cannon.Levels[nextCannonLvl]
	if nextCannonData then
		vis.CannonPrompt.ObjectText = nextCannonData.DisplayName
		vis.CannonPrompt.ActionText = "Mejorar (" .. tostring(nextCannonData.Cost) .. " Berries)"
	else
		vis.CannonPrompt.ObjectText = "Cañón Real de Asedio (MÁX)"
		vis.CannonPrompt.ActionText = "✅ Nivel Máximo Alcanzado"
	end

	-- Mostrar u ocultar el cañón según si ya compró el Nivel 1+
	vis.CannonBarrel.Transparency = if baseData.CannonLevel > 0 then 0 else 0.7
	if baseData.CannonLevel == 1 then
		vis.CannonBarrel.Color = Color3.fromRGB(60, 60, 65)
	elseif baseData.CannonLevel == 2 then
		vis.CannonBarrel.Color = Color3.fromRGB(180, 140, 50)
	elseif baseData.CannonLevel >= 3 then
		vis.CannonBarrel.Color = Color3.fromRGB(255, 70, 70)
	end
end

-- Activa el escudo del barco (sirve para Berries, Developer Product de 10 min o GamePass Permanente)
function DefenseManager.ActivateShield(player: Player, durationSeconds: number, isPermanent: boolean?)
	local baseData = BaseManager.GetPlayerBase(player)
	if not baseData then return end

	local vis = visualsByBase[baseData]
	if not vis then return end

	if isPermanent then
		baseData.PermanentShield = true
		baseData.ShieldActive = true
		vis.ShieldDome.Transparency = 0.65
		vis.ShieldBillboardLabel.Text = "🛡️ ESCUDO VIP PERMANENTE"
		refreshDefensePrompts(baseData)
		return
	end

	local now = os.clock()
	local currentEnd = if baseData.ShieldActive then math.max(now, baseData.ShieldExpiresAt) else now
	baseData.ShieldExpiresAt = currentEnd + durationSeconds
	baseData.ShieldActive = true

	vis.ShieldDome.Transparency = 0.65
	refreshDefensePrompts(baseData)
end

-- Compra de Escudo con Berries desde el barco o GUI
function DefenseManager.TryBuyBerryShield(player: Player)
	local baseData = BaseManager.GetPlayerBase(player)
	if not baseData or baseData.Owner ~= player then return end

	if baseData.PermanentShield then
		notifyPlayer(player, "🛡️ ¡Ya tienes el Escudo Permanente activo!", Color3.fromRGB(100, 220, 255))
		return
	end

	if baseData.ShieldActive then
		notifyPlayer(player, "🛡️ ¡El escudo de tu barco ya está activo!", Color3.fromRGB(100, 220, 255))
		return
	end

	local now = os.clock()
	if now < baseData.ShieldCooldownUntil then
		local waitSecs = math.ceil(baseData.ShieldCooldownUntil - now)
		notifyPlayer(
			player,
			"⏳ El generador de escudo se está enfriando. Espera " .. tostring(waitSecs) .. "s.",
			Color3.fromRGB(255, 180, 60)
		)
		return
	end

	local cost = GameConfig.Defenses.Shield.Cost
	if not PlayerSession.SpendBerries(player, cost) then
		notifyPlayer(player, "❌ Necesitas " .. tostring(cost) .. " Berries para activar el Escudo.", Color3.fromRGB(255, 80, 80))
		return
	end

	local duration = GameConfig.Defenses.Shield.DurationSeconds
	baseData.ShieldCooldownUntil = now + duration + GameConfig.Defenses.Shield.CooldownSeconds
	DefenseManager.ActivateShield(player, duration, false)

	notifyPlayer(
		player,
		"🛡️ ¡Escudo Místico activado por " .. tostring(duration) .. " segundos! Nadie puede robar tus frutas.",
		Color3.fromRGB(80, 220, 255)
	)
end

-- Mejora el nivel de Cadenas del barco
function DefenseManager.TryUpgradeChains(player: Player)
	local baseData = BaseManager.GetPlayerBase(player)
	if not baseData or baseData.Owner ~= player then return end

	local nextLvl = baseData.ChainsLevel + 1
	local nextData = GameConfig.Defenses.Chains.Levels[nextLvl]
	if not nextData then
		notifyPlayer(player, "⛓️ ¡Tus cadenas ya están al nivel máximo!", Color3.fromRGB(255, 215, 0))
		return
	end

	if not PlayerSession.SpendBerries(player, nextData.Cost) then
		notifyPlayer(
			player,
			"❌ Necesitas " .. tostring(nextData.Cost) .. " Berries para mejorar a " .. nextData.DisplayName .. ".",
			Color3.fromRGB(255, 80, 80)
		)
		return
	end

	DefenseManager.SetChainsLevel(player, nextLvl)
	notifyPlayer(player, "⛓️ ¡Mejoraste tus defensas a " .. nextData.DisplayName .. "!", Color3.fromRGB(120, 255, 140))
end

function DefenseManager.SetChainsLevel(player: Player, level: number)
	local baseData = BaseManager.GetPlayerBase(player)
	if not baseData then return end

	baseData.ChainsLevel = math.clamp(level, 0, GameConfig.Defenses.Chains.MaxLevel)
	applyChainsToBaseSlots(baseData)
	refreshDefensePrompts(baseData)
end

-- Mejora el nivel del Cañón del barco
function DefenseManager.TryUpgradeCannon(player: Player)
	local baseData = BaseManager.GetPlayerBase(player)
	if not baseData or baseData.Owner ~= player then return end

	local nextLvl = baseData.CannonLevel + 1
	local nextData = GameConfig.Defenses.Cannon.Levels[nextLvl]
	if not nextData then
		notifyPlayer(player, "💣 ¡Tu Cañón Pirata ya está al nivel máximo!", Color3.fromRGB(255, 215, 0))
		return
	end

	if not PlayerSession.SpendBerries(player, nextData.Cost) then
		notifyPlayer(
			player,
			"❌ Necesitas " .. tostring(nextData.Cost) .. " Berries para mejorar a " .. nextData.DisplayName .. ".",
			Color3.fromRGB(255, 80, 80)
		)
		return
	end

	DefenseManager.SetCannonLevel(player, nextLvl)
	notifyPlayer(player, "💣 ¡Instalaste " .. nextData.DisplayName .. " en tu barco!", Color3.fromRGB(120, 255, 140))
end

function DefenseManager.SetCannonLevel(player: Player, level: number)
	local baseData = BaseManager.GetPlayerBase(player)
	if not baseData then return end

	baseData.CannonLevel = math.clamp(level, 0, GameConfig.Defenses.Cannon.MaxLevel)
	refreshDefensePrompts(baseData)
end

-- Reinicia las defensas visuales cuando un jugador abandona el barco
function DefenseManager.ResetBaseDefenses(baseData: BaseManager.BaseData)
	baseData.ShieldActive = false
	baseData.PermanentShield = false
	baseData.ShieldExpiresAt = 0
	baseData.ShieldCooldownUntil = 0
	baseData.ChainsLevel = 0
	baseData.CannonLevel = 0

	local vis = visualsByBase[baseData]
	if vis then
		vis.ShieldDome.Transparency = 1
		vis.ShieldBillboardLabel.Text = ""
	end

	applyChainsToBaseSlots(baseData)
	refreshDefensePrompts(baseData)
end

-- Dispara una bala de cañón visual hacia el ladrón y lo derriba
local function fireCannonAtTarget(baseData: BaseManager.BaseData, vis: BaseDefenseVisuals, targetPlayer: Player, targetRoot: BasePart)
	-- Orientar el cañón hacia el ladrón
	local barrelPos = vis.CannonBarrel.Position
	vis.CannonBarrel.CFrame = CFrame.lookAt(barrelPos, targetRoot.Position)

	-- Crear bala de cañón animada
	local cannonball = Instance.new("Part")
	cannonball.Name = "Cannonball"
	cannonball.Shape = Enum.PartType.Ball
	cannonball.Size = Vector3.new(1.8, 1.8, 1.8)
	cannonball.Material = Enum.Material.Metal
	cannonball.Color = Color3.fromRGB(30, 30, 35)
	cannonball.Anchored = true
	cannonball.CanCollide = false
	cannonball.Position = barrelPos
	cannonball.Parent = Workspace

	local fireEffect = Instance.new("Fire")
	fireEffect.Size = 4
	fireEffect.Heat = 8
	fireEffect.Parent = cannonball

	local travelTime = math.clamp((targetRoot.Position - barrelPos).Magnitude / 95, 0.15, 0.45)
	local tween = TweenService:Create(cannonball, TweenInfo.new(travelTime, Enum.EasingStyle.Linear), {
		Position = targetRoot.Position,
	})
	tween:Play()
	Debris:AddItem(cannonball, travelTime + 0.1)

	task.delay(travelTime, function()
		if not targetPlayer.Character then return end
		local hum = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
		local root = targetPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hum or not root or hum.Health <= 0 then return end

		-- Empujar al ladrón con el impacto del cañonazo
		local dir = (root.Position - barrelPos).Unit
		root.AssemblyLinearVelocity = (dir * 45) + Vector3.new(0, 28, 0)

		-- Si llevaba una fruta robada, la suelta y vuelve al barco dueño
		local heist = StealManager.GetActiveHeist(targetPlayer)
		if heist then
			StealManager.ReturnStolenFruit(
				targetPlayer,
				"💣 ¡El Cañón Pirata de " .. (if baseData.Owner then baseData.Owner.DisplayName else "la base") .. " te derribó y recuperó la fruta!"
			)
		else
			notifyPlayer(targetPlayer, "💣 ¡Cuidado! El cañón defensor del barco te disparó.", Color3.fromRGB(255, 120, 60))
		end

		hum.PlatformStand = true
		task.delay(GameConfig.Stealing.StunDuration, function()
			if hum and hum.Parent then
				hum.PlatformStand = false
			end
		end)
	end)
end

-- Construye automáticamente los puestos de defensa y la cúpula de escudo en cada barco
local function setupBaseDefenseObjects(baseData: BaseManager.BaseData)
	local spawnPoint = baseData.Model:FindFirstChild("SpawnPoint") :: BasePart?
	if not spawnPoint then return end

	local stationFolder = baseData.Model:FindFirstChild("DefenseStation")
	if not stationFolder then
		stationFolder = Instance.new("Folder")
		stationFolder.Name = "DefenseStation"
		stationFolder.Parent = baseData.Model
	end

	-- Función auxiliar para crear un pedestal de compra si no existe en Studio
	local function getOrCreatePedestal(name: string, offset: Vector3, color: Color3, labelTitle: string): (BasePart, ProximityPrompt)
		local part = stationFolder:FindFirstChild(name) :: BasePart?
		if not part then
			part = Instance.new("Part")
			part.Name = name
			part.Size = Vector3.new(3, 3.2, 2)
			part.CFrame = spawnPoint.CFrame * CFrame.new(offset)
			part.Anchored = true
			part.Material = Enum.Material.SmoothPlastic
			part.Color = color
			part.Parent = stationFolder

			local bGui = Instance.new("BillboardGui")
			bGui.Size = UDim2.fromOffset(140, 40)
			bGui.StudsOffset = Vector3.new(0, 2.6, 0)
			bGui.MaxDistance = 35
			bGui.Parent = part

			local txt = Instance.new("TextLabel")
			txt.Size = UDim2.fromScale(1, 1)
			txt.BackgroundTransparency = 1
			txt.Font = Enum.Font.FredokaOne
			txt.TextScaled = true
			txt.TextStrokeTransparency = 0.2
			txt.TextColor3 = color
			txt.Text = labelTitle
			txt.Parent = bGui
		end

		local prompt = Instance.new("ProximityPrompt")
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt.Parent = part

		return part, prompt
	end

	local _, shieldPrompt = getOrCreatePedestal("ShieldTerminal", Vector3.new(-8, 1, -4), Color3.fromRGB(70, 190, 255), "🛡️ Escudo Místico")
	local _, chainsPrompt = getOrCreatePedestal("ChainsTerminal", Vector3.new(-8, 1, 0), Color3.fromRGB(190, 195, 210), "⛓️ Cadenas")
	local _, cannonPrompt = getOrCreatePedestal("CannonTerminal", Vector3.new(-8, 1, 4), Color3.fromRGB(255, 130, 60), "💣 Cañón Pirata")

	-- Crear el Cañón en la cubierta del barco
	local cannonBarrel = stationFolder:FindFirstChild("CannonBarrel") :: BasePart?
	if not cannonBarrel then
		cannonBarrel = Instance.new("Part")
		cannonBarrel.Name = "CannonBarrel"
		cannonBarrel.Size = Vector3.new(2.2, 2.2, 5.0)
		cannonBarrel.CFrame = spawnPoint.CFrame * CFrame.new(0, 2.5, -10)
		cannonBarrel.Anchored = true
		cannonBarrel.CanCollide = false
		cannonBarrel.Material = Enum.Material.Metal
		cannonBarrel.Color = Color3.fromRGB(60, 60, 65)
		cannonBarrel.Transparency = 0.7
		cannonBarrel.Parent = stationFolder
	end

	-- Crear la Cúpula del Escudo Místico
	local shieldDome = stationFolder:FindFirstChild("ShieldDome") :: BasePart?
	if not shieldDome then
		shieldDome = Instance.new("Part")
		shieldDome.Name = "ShieldDome"
		shieldDome.Shape = Enum.PartType.Ball
		shieldDome.Size = Vector3.new(46, 46, 46)
		shieldDome.CFrame = spawnPoint.CFrame
		shieldDome.Anchored = true
		shieldDome.CanCollide = false
		shieldDome.Material = Enum.Material.ForceField
		shieldDome.Color = Color3.fromRGB(60, 195, 255)
		shieldDome.Transparency = 1
		shieldDome.Parent = stationFolder
	end

	local domeBillboard = Instance.new("BillboardGui")
	domeBillboard.Name = "ShieldTimerGui"
	domeBillboard.Size = UDim2.fromOffset(220, 50)
	domeBillboard.StudsOffset = Vector3.new(0, 16, 0)
	domeBillboard.MaxDistance = 90
	domeBillboard.Parent = shieldDome

	local domeLabel = Instance.new("TextLabel")
	domeLabel.Size = UDim2.fromScale(1, 1)
	domeLabel.BackgroundTransparency = 1
	domeLabel.Font = Enum.Font.FredokaOne
	domeLabel.TextScaled = true
	domeLabel.TextStrokeTransparency = 0.15
	domeLabel.TextColor3 = Color3.fromRGB(100, 230, 255)
	domeLabel.Text = ""
	domeLabel.Parent = domeBillboard

	-- Conectar compras de cada terminal validando que sea el dueño del barco
	shieldPrompt.Triggered:Connect(function(player: Player)
		if baseData.Owner ~= player then
			notifyPlayer(player, "⛔ Solo el capitán de este barco puede usar sus defensas.", Color3.fromRGB(255, 80, 80))
			return
		end
		DefenseManager.TryBuyBerryShield(player)
	end)

	chainsPrompt.Triggered:Connect(function(player: Player)
		if baseData.Owner ~= player then
			notifyPlayer(player, "⛔ Solo el capitán de este barco puede mejorar sus cadenas.", Color3.fromRGB(255, 80, 80))
			return
		end
		DefenseManager.TryUpgradeChains(player)
	end)

	cannonPrompt.Triggered:Connect(function(player: Player)
		if baseData.Owner ~= player then
			notifyPlayer(player, "⛔ Solo el capitán de este barco puede mejorar su cañón.", Color3.fromRGB(255, 80, 80))
			return
		end
		DefenseManager.TryUpgradeCannon(player)
	end)

	visualsByBase[baseData] = {
		ShieldDome = shieldDome,
		ShieldBillboardLabel = domeLabel,
		ShieldPrompt = shieldPrompt,
		ChainsPrompt = chainsPrompt,
		CannonPrompt = cannonPrompt,
		CannonBarrel = cannonBarrel,
		LastCannonShot = 0,
	}

	refreshDefensePrompts(baseData)
end

function DefenseManager.Init()
	for _, baseData in BaseManager.GetAllBases() do
		setupBaseDefenseObjects(baseData)
	end

	-- Bucle de actualización de escudos y disparo automático de cañones (cada 0.5s)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local now = os.clock()

			for _, baseData in BaseManager.GetAllBases() do
				local vis = visualsByBase[baseData]
				if not vis then continue end

				if not baseData.Owner then
					continue
				end

				-- 1. Controlar duración del Escudo Temporal
				if baseData.ShieldActive and not baseData.PermanentShield then
					local remaining = math.ceil(baseData.ShieldExpiresAt - now)
					if remaining <= 0 then
						baseData.ShieldActive = false
						vis.ShieldDome.Transparency = 1
						vis.ShieldBillboardLabel.Text = ""
						notifyPlayer(baseData.Owner, "⚠️ ¡El Escudo Místico de tu barco ha expirado!", Color3.fromRGB(255, 180, 60))
					else
						vis.ShieldBillboardLabel.Text = "🛡️ ESCUDO ACTIVO: " .. tostring(remaining) .. "s"
					end
				end

				refreshDefensePrompts(baseData)

				-- 2. Disparo automático del Cañón Pirata si tiene nivel >= 1
				if baseData.CannonLevel > 0 then
					local cannonStats = GameConfig.Defenses.Cannon.Levels[baseData.CannonLevel]
					if cannonStats and (now - vis.LastCannonShot) >= cannonStats.FireInterval then
						-- Buscar si algún jugador enemigo está robando una fruta de este barco dentro del alcance
						local barrelPos = vis.CannonBarrel.Position
						for _, candidate in Players:GetPlayers() do
							if candidate == baseData.Owner then continue end

							local char = candidate.Character
							local root = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
							local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil

							if root and hum and hum.Health > 0 then
								local dist = (root.Position - barrelPos).Magnitude
								local heist = StealManager.GetActiveHeist(candidate)
								local isStealingFromThisBase = (heist ~= nil and heist.VictimOwner == baseData.Owner)
								local isIntruderOnDeck = (dist <= 22 and not baseData.ShieldActive)

								if dist <= cannonStats.Range and (isStealingFromThisBase or isIntruderOnDeck) then
									vis.LastCannonShot = now
									fireCannonAtTarget(baseData, vis, candidate, root)
									break
								end
							end
						end
					end
				end
			end
		end
	end)
end

return DefenseManager
