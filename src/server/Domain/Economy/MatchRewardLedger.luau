--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local SettlementTypes = require(script.Parent.Parent.Parent.Persistence.SettlementTypes)

type PlayerData = PlayerDataTypes.PlayerData

local MAX_RECENT_MATCH_IDS = 64
local MAX_SAFE_INTEGER = 9_007_199_254_740_991
local MatchRewardLedger = {}

function MatchRewardLedger.ApplySettlement(
	data: PlayerData,
	opponentId: number,
	sequence: number,
	matchId: string,
	didWin: boolean,
	reward: SettlementTypes.Reward
): boolean
	assert(
		opponentId ~= 0
			and math.abs(opponentId) <= MAX_SAFE_INTEGER
			and opponentId % 1 == 0
			and sequence > 0
			and sequence <= MAX_SAFE_INTEGER
			and sequence % 1 == 0,
		"Invalid settlement sequence"
	)
	local sequences = data.MatchRewardSequences or {}
	local key = tostring(opponentId)
	local previous = sequences[key] or 0
	if sequence <= previous then
		return true
	end
	if sequence ~= previous + 1 then
		return false
	end
	local amounts: { number } = { reward.Cash, reward.Tickets, reward.Experience, reward.Fame }
	for _, amount in amounts do
		assert(
			amount >= 0 and amount == amount and amount <= MAX_SAFE_INTEGER and amount % 1 == 0,
			"Invalid match reward"
		)
	end
	if table.find(data.Statistics.RecentMatchIds, matchId) == nil then
		local totals = {
			data.Currencies.Cash + reward.Cash,
			data.Currencies.Tickets + reward.Tickets,
			data.Progression.Experience + reward.Experience,
			data.Progression.Fame + reward.Fame,
			(if didWin then data.Statistics.Wins else data.Statistics.Losses) + 1,
		}
		for _, total in totals do
			assert(
				total >= 0 and total <= MAX_SAFE_INTEGER and total % 1 == 0,
				"Invalid resulting balance"
			)
		end
		data.Currencies.Cash += reward.Cash
		data.Currencies.Tickets += reward.Tickets
		data.Progression.Experience += reward.Experience
		data.Progression.Fame += reward.Fame
		if didWin then
			data.Statistics.Wins += 1
		else
			data.Statistics.Losses += 1
		end
		table.insert(data.Statistics.RecentMatchIds, matchId)
		if #data.Statistics.RecentMatchIds > MAX_RECENT_MATCH_IDS then
			table.remove(data.Statistics.RecentMatchIds, 1)
		end
	end
	sequences[key] = sequence
	data.MatchRewardSequences = sequences
	return true
end

return table.freeze(MatchRewardLedger)
