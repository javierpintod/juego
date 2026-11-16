--!strict
-- Ubicación en Roblox Studio: ServerScriptService/Modules/PlayerSession (ModuleScript)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GameConfig"))

local PlayerSession = {}

export type SessionData = {
	Berries: number,
	LuckMultiplier: number,
	DoubleMoney: boolean,
	AutoCollect: boolean,
	DoubleSpeed: boolean,
	LeaderstatsValue: IntValue,
}

local sessions: { [Player]: SessionData } = {}

function PlayerSession.SetupPlayer(player: Player): SessionData
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local berriesValue = Instance.new("IntValue")
	berriesValue.Name = "Berries"
	berriesValue.Value = GameConfig.StartingBerries
	berriesValue.Parent = leaderstats

	local data: SessionData = {
		Berries = GameConfig.StartingBerries,
		LuckMultiplier = 1,
		DoubleMoney = false,
		AutoCollect = false,
		DoubleSpeed = false,
		LeaderstatsValue = berriesValue,
	}

	sessions[player] = data
	player:SetAttribute("Berries", data.Berries)
	return data
end

function PlayerSession.CleanupPlayer(player: Player)
	sessions[player] = nil
end

function PlayerSession.Get(player: Player): SessionData?
	return sessions[player]
end

function PlayerSession.GetBerries(player: Player): number
	local session = sessions[player]
	return if session then session.Berries else 0
end

function PlayerSession.AddBerries(player: Player, amount: number)
	local session = sessions[player]
	if not session or amount <= 0 then return end

	local finalAmount = if session.DoubleMoney then amount * 2 else amount
	session.Berries = math.floor(session.Berries + finalAmount)
	session.LeaderstatsValue.Value = session.Berries
	player:SetAttribute("Berries", session.Berries)
end

function PlayerSession.SpendBerries(player: Player, cost: number): boolean
	local session = sessions[player]
	if not session or cost < 0 then return false end

	if session.Berries >= cost then
		session.Berries -= math.floor(cost)
		session.LeaderstatsValue.Value = session.Berries
		player:SetAttribute("Berries", session.Berries)
		return true
	end

	return false
end

return PlayerSession
