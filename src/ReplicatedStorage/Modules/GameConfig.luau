--!strict
-- Ubicación en Roblox Studio: ReplicatedStorage/Modules/GameConfig (ModuleScript)

local GameConfig = {}

GameConfig.StartingBerries = 100

-- Configuración general de las bases
GameConfig.Bases = {
	BaseSlots = 4,
	MaxSlots = 6,
	ExtraSlotCost = 2500,
}

-- Configuración del Sistema de Robo (Sistema 4)
GameConfig.Stealing = {
	DefaultWalkSpeed = 16,
	CarryingWalkSpeed = 11,      -- Más lento al cargar una fruta robada para dar oportunidad al dueño
	StealHoldDuration = 1.5,     -- Segundos manteniendo E para robar una fruta ajena
	WeaponCooldown = 0.8,        -- Cooldown del Sable de Abordaje
	HitboxRange = 6.5,           -- Alcance del golpe para atrapar al ladrón
	StunDuration = 2.0,          -- Tiempo que el ladrón queda aturdido al ser golpeado
}

-- Configuración del Sistema de Defensas (Sistema 5)
GameConfig.Defenses = {
	Shield = {
		Cost = 600,
		DurationSeconds = 60,     -- 1 minuto de protección comprando con Berries
		CooldownSeconds = 90,     -- Cooldown para evitar spam infinito con Berries (no aplica a Robux)
	},
	Chains = {
		MaxLevel = 3,
		Levels = {
			[1] = { Cost = 800, ExtraHoldTime = 1.0, DisplayName = "Cadenas de Bronce (+1.0s robo)" },
			[2] = { Cost = 2200, ExtraHoldTime = 2.0, DisplayName = "Cadenas de Acero (+2.0s robo)" },
			[3] = { Cost = 5500, ExtraHoldTime = 3.5, DisplayName = "Cadenas de Kairoseki (+3.5s robo)" },
		},
	},
	Cannon = {
		MaxLevel = 3,
		Levels = {
			[1] = { Cost = 1500, FireInterval = 5.5, Range = 32, DisplayName = "Cañón de Cubierta Nv.1" },
			[2] = { Cost = 4000, FireInterval = 4.0, Range = 42, DisplayName = "Cañón Doble Nv.2" },
			[3] = { Cost = 9500, FireInterval = 2.5, Range = 55, DisplayName = "Cañón Real de Asedio Nv.3" },
		},
	},
}

-- Configuración de Monetización (Sistema 8)
-- NOTA: Reemplaza estos IDs con los IDs reales creados en el Creator Dashboard de tu juego
GameConfig.GamePasses = {
	DoubleMoney = {
		Id = 1000001,
		DisplayName = "Doble Berries x2",
		Description = "Duplica permanentemente todos los ingresos de tus frutas",
	},
	DoubleSpeed = {
		Id = 1000002,
		DisplayName = "Velocidad Pirata x2",
		Description = "Corre más rápido incluso al escapar cargando fruta",
	},
	AutoCollect = {
		Id = 1000003,
		DisplayName = "Auto-Recolector",
		Description = "Las Berries van directo a tu cuenta cada segundo sin pisar la DropZone",
	},
	ExtraSlot = {
		Id = 1000004,
		DisplayName = "Slot VIP #6",
		Description = "Desbloquea el pedestal número 6 en tu barco para una fruta extra",
	},
	PermanentShield = {
		Id = 1000005,
		DisplayName = "Escudo Permanente",
		Description = "Cúpula de protección total infinita para tu barco",
	},
}

GameConfig.DeveloperProducts = {
	BerriesPackSmall = {
		Id = 2000001,
		Amount = 1500,
		DisplayName = "Bolsa de 1,500 Berries",
	},
	BerriesPackMedium = {
		Id = 2000002,
		Amount = 7500,
		DisplayName = "Cofre de 7,500 Berries",
	},
	BerriesPackLarge = {
		Id = 2000003,
		Amount = 25000,
		DisplayName = "Tesoro de 25,000 Berries",
	},
	LuckPotion = {
		Id = 2000004,
		Multiplier = 2,
		DisplayName = "Poción de Suerte x2",
		Description = "Duplica la probabilidad de frutas Legendarias y Míticas en cofres",
	},
	Shield10Min = {
		Id = 2000005,
		DurationSeconds = 600,
		DisplayName = "Escudo de 10 Minutos",
		Description = "Protección impenetrable durante 10 minutos continuos",
	},
}

-- Rarezas y probabilidades base (Común 50%, Rara 30%, Épica 15%, Legendaria 4%, Mítica 1%)
GameConfig.Rarities = {
	Comun = {
		DisplayName = "Común",
		Chance = 50,
		Color = Color3.fromRGB(180, 180, 180),
		Order = 1,
	},
	Rara = {
		DisplayName = "Rara",
		Chance = 30,
		Color = Color3.fromRGB(50, 150, 255),
		Order = 2,
	},
	Epica = {
		DisplayName = "Épica",
		Chance = 15,
		Color = Color3.fromRGB(170, 50, 255),
		Order = 3,
	},
	Legendaria = {
		DisplayName = "Legendaria",
		Chance = 4,
		Color = Color3.fromRGB(255, 190, 0),
		Order = 4,
	},
	Mitica = {
		DisplayName = "Mítica",
		Chance = 1,
		Color = Color3.fromRGB(255, 40, 80),
		Order = 5,
	},
}

export type FruitInfo = {
	Id: string,
	DisplayName: string,
	Rarity: string,
	BerriesPerSecond: number,
	SellPrice: number,
	Color: Color3,
}

GameConfig.Fruits = {
	-- COMUNES (50%)
	FrutaBrisa = {
		Id = "FrutaBrisa",
		DisplayName = "Fruta Brisa Marina",
		Rarity = "Comun",
		BerriesPerSecond = 2,
		SellPrice = 25,
		Color = Color3.fromRGB(190, 230, 220),
	},
	FrutaRoca = {
		Id = "FrutaRoca",
		DisplayName = "Fruta Coral de Roca",
		Rarity = "Comun",
		BerriesPerSecond = 3,
		SellPrice = 35,
		Color = Color3.fromRGB(150, 140, 130),
	},

	-- RARAS (30%)
	FrutaMarea = {
		Id = "FrutaMarea",
		DisplayName = "Fruta Marea Viva",
		Rarity = "Rara",
		BerriesPerSecond = 8,
		SellPrice = 100,
		Color = Color3.fromRGB(40, 140, 255),
	},
	FrutaChispa = {
		Id = "FrutaChispa",
		DisplayName = "Fruta Chispa Solar",
		Rarity = "Rara",
		BerriesPerSecond = 12,
		SellPrice = 140,
		Color = Color3.fromRGB(255, 130, 40),
	},

	-- ÉPICAS (15%)
	FrutaTempestad = {
		Id = "FrutaTempestad",
		DisplayName = "Fruta Tempestad Eléctrica",
		Rarity = "Epica",
		BerriesPerSecond = 35,
		SellPrice = 400,
		Color = Color3.fromRGB(160, 70, 255),
	},
	FrutaEspejismo = {
		Id = "FrutaEspejismo",
		DisplayName = "Fruta Espejismo Astral",
		Rarity = "Epica",
		BerriesPerSecond = 45,
		SellPrice = 500,
		Color = Color3.fromRGB(250, 80, 210),
	},

	-- LEGENDARIAS (4%)
	FrutaAbismo = {
		Id = "FrutaAbismo",
		DisplayName = "Fruta Abismo Oscuro",
		Rarity = "Legendaria",
		BerriesPerSecond = 150,
		SellPrice = 1800,
		Color = Color3.fromRGB(255, 195, 0),
	},
	FrutaFenix = {
		Id = "FrutaFenix",
		DisplayName = "Fruta Ave Celeste",
		Rarity = "Legendaria",
		BerriesPerSecond = 200,
		SellPrice = 2400,
		Color = Color3.fromRGB(0, 240, 255),
	},

	-- MÍTICAS (1%)
	FrutaKraken = {
		Id = "FrutaKraken",
		DisplayName = "Fruta Leviatán Ancestral",
		Rarity = "Mitica",
		BerriesPerSecond = 750,
		SellPrice = 9000,
		Color = Color3.fromRGB(255, 30, 70),
	},
}

GameConfig.Chests = {
	CofreBasico = {
		DisplayName = "Cofre de Marinero",
		Cost = 50,
		Weights = {
			Comun = 50,
			Rara = 30,
			Epica = 15,
			Legendaria = 4,
			Mitica = 1,
		},
	},
	CofrePirata = {
		DisplayName = "Cofre de Capitán",
		Cost = 500,
		Weights = {
			Comun = 20,
			Rara = 45,
			Epica = 25,
			Legendaria = 8,
			Mitica = 2,
		},
	},
	CofreEmperador = {
		DisplayName = "Cofre de Leyenda",
		Cost = 4500,
		Weights = {
			Comun = 0,
			Rara = 35,
			Epica = 45,
			Legendaria = 15,
			Mitica = 5,
		},
	},
}

return GameConfig
