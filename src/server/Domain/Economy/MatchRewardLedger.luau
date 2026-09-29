--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local RewardPolicy = require(script.Parent.RewardPolicy)

type PlayerData = PlayerDataTypes.PlayerData

local MAX_RECENT_MATCH_IDS = 64
local MatchRewardLedger = {}

function MatchRewardLedger.Apply(data: PlayerData, matchId: string, didWin: boolean): boolean
	assert(matchId ~= "", "A match reward requires a match ID")
	local recent = data.Statistics.RecentMatchIds
	if table.find(recent, matchId) ~= nil then
		return false
	end

	local reward = RewardPolicy.ForMatchOutcome(didWin)
	data.Currencies.Cash += reward.Cash
	data.Currencies.Tickets += reward.Tickets
	data.Progression.Experience += reward.Experience
	data.Progression.Fame += reward.Fame
	if didWin then
		data.Statistics.Wins += 1
	else
		data.Statistics.Losses += 1
	end

	table.insert(recent, matchId)
	if #recent > MAX_RECENT_MATCH_IDS then
		table.remove(recent, 1)
	end
	return true
end

return table.freeze(MatchRewardLedger)
