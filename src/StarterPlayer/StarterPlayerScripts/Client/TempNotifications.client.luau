--!strict
-- Ubicación en Roblox Studio: StarterPlayer/StarterPlayerScripts/Client/TempNotifications (LocalScript)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local notifyEvent = remotes:WaitForChild("NotifyEvent") :: RemoteEvent

notifyEvent.OnClientEvent:Connect(function(message: string, color: Color3)
	pcall(function()
		StarterGui:SetCore("ChatMakeSystemMessage", {
			Text = message,
			Color = color,
			Font = Enum.Font.FredokaOne,
		})
	end)
	print("[Notificación]:", message)
end)
