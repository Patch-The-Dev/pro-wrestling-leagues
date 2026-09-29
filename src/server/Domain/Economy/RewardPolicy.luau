--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local MatchConfig = require(ReplicatedStorage.Shared.Config.MatchConfig)
local MatchTypes = require(ReplicatedStorage.Shared.Types.MatchTypes)

type MatchEndReason = MatchTypes.MatchEndReason

type Reward = {
	Cash: number,
	Tickets: number,
	Experience: number,
	Fame: number,
}

local RewardPolicy = {}

function RewardPolicy.IsEligible(reason: MatchEndReason, durationSeconds: number): boolean
	if reason == "Vote" or reason == "Cancelled" then
		return false
	end
	if durationSeconds < MatchConfig.MinimumRewardDurationSeconds then
		return false
	end
	return true
end

function RewardPolicy.ForMatchOutcome(didWin: boolean): Reward
	local configured = if didWin
		then EconomyConfig.MatchRewards.Win
		else EconomyConfig.MatchRewards.Loss
	return table.clone(configured)
end

return RewardPolicy
