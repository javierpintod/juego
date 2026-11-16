# 🏴‍☠️ Rouba a Fruta (Roblox Luau)

Juego estilo **"Steal a Brainrot"** con temática pirata original para Roblox Studio.
Cada jugador posee un barco base donde coloca **Frutas Místicas** obtenidas en cofres para generar **Berries por segundo**, pudiendo infiltrarse en barcos rivales para robar sus frutas o defender su cubierta con su **Sable de Abordaje** y defensas.

## 📂 Estructura del Proyecto (`src/`)

- `src/ReplicatedStorage/Modules/GameConfig.luau`: Configuración central de rarezas (50%/30%/15%/4%/1%), frutas, cofres, bases y sistema de robo.
- `src/ServerScriptService/Modules/BaseManager.luau`: Sistema 1 - Asignación de barcos, pedestales (Slots 1-6) y estado visual.
- `src/ServerScriptService/Modules/PlayerSession.luau`: Sesión del jugador, `leaderstats` (Berries) y multiplicadores.
- `src/ServerScriptService/Modules/ChestManager.luau`: Sistema 2 - Apertura de cofres con RNG ponderado, generación de frutas y venta.
- `src/ServerScriptService/Modules/ProductionManager.luau`: Sistema 3 - Generación de Berries por segundo, cofre recolector (`DropZone`) y Auto-Collect.
- `src/ServerScriptService/Modules/StealManager.luau`: Sistema 4 - Robo de frutas entre barcos, penalización de velocidad, Sable de Abordaje para derribar ladrones y entrega en la `DropZone`.
- `src/ServerScriptService/Core/GameServer.server.luau`: Inicializador principal del servidor.
- `src/StarterPlayer/StarterPlayerScripts/Client/TempNotifications.client.luau`: Receptor de alertas en el cliente.
