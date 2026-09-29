--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)

type Reward = {
	Cash: number,
	Tickets: number,
	Experience: number,
	Fame: number,
}

local RewardPolicy = {}

function RewardPolicy.ForMatchOutcome(didWin: boolean): Reward
	local configured = if didWin then EconomyConfig.MatchRewards.Win else EconomyConfig.MatchRewards.Loss
	return table.clone(configured)
end

return RewardPolicy
