--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MatchConfig = require(ReplicatedStorage.Shared.Config.MatchConfig)
local Types = require(script.Parent.SettlementTypes)

type Result = Types.Result
type Pair = Types.Pair
type Store = Types.Store
type Pages = Types.Pages
type ApplyAndConfirm = (number, number, number, string, boolean, Types.Reward) -> boolean

local MatchSettlementJournal = {}
MatchSettlementJournal.__index = MatchSettlementJournal

export type MatchSettlementJournal = typeof(setmetatable(
	{} :: {
		_store: Store,
		_applyAndConfirm: ApplyAndConfirm,
		_isRelevant: ((number, number) -> boolean)?,
		_pages: Pages?,
		_processing: { [string]: boolean },
	},
	{} :: typeof(MatchSettlementJournal)
))

local function pairKey(result: Result): string
	return `pair/{math.min(result.WinnerUserId, result.LoserUserId)}:{math.max(
		result.WinnerUserId,
		result.LoserUserId
	)}`
end

function MatchSettlementJournal.new(
	store: Store,
	applyAndConfirm: ApplyAndConfirm,
	isRelevant: ((number, number) -> boolean)?
): MatchSettlementJournal
	return setmetatable({
		_store = store,
		_applyAndConfirm = applyAndConfirm,
		_isRelevant = isRelevant,
		_pages = nil,
		_processing = {},
	}, MatchSettlementJournal)
end

function MatchSettlementJournal.Record(self: MatchSettlementJournal, result: Result): boolean
	assert(#result.MatchId > 0 and #result.MatchId <= 36, "Invalid settlement ID")
	assert(result.WinnerUserId ~= result.LoserUserId, "A settlement needs two different players")
	local succeeded, stored = pcall(function()
		return self._store:UpdateAsync(`result/{result.MatchId}`, function(previous)
			if previous ~= nil then
				local existing = previous :: Result
				assert(
					existing.MatchId == result.MatchId
						and existing.WinnerUserId == result.WinnerUserId
						and existing.LoserUserId == result.LoserUserId
						and existing.FinishedAt == result.FinishedAt,
					"Settlement ID collision"
				)
				return existing
			end
			return result
		end)
	end)
	if not succeeded then
		warn(`Could not persist match result {result.MatchId}: {tostring(stored)}`)
		return false
	end
	return stored ~= nil
end

function MatchSettlementJournal._claim(self: MatchSettlementJournal, result: Result): Pair
	local stored = self._store:UpdateAsync(pairKey(result), function(previous)
		local pair: Pair = if previous == nil
			then { Sequence = 0, LastMatchId = "", LastClaimedAt = 0, Pending = nil }
			else previous :: Pair
		if pair.Pending ~= nil or pair.LastMatchId == result.MatchId then
			return pair
		end
		if
			pair.Sequence > 0
			and result.FinishedAt - pair.LastClaimedAt
				< MatchConfig.RepeatOpponentRewardCooldownSeconds
		then
			return pair
		end
		return {
			Sequence = pair.Sequence + 1,
			LastMatchId = result.MatchId,
			LastClaimedAt = result.FinishedAt,
			Pending = {
				MatchId = result.MatchId,
				Sequence = pair.Sequence + 1,
				WinnerSaved = false,
				LoserSaved = false,
			},
		}
	end)
	assert(stored ~= nil, "Settlement claim was not committed")
	return stored :: Pair
end

function MatchSettlementJournal._acknowledge(
	self: MatchSettlementJournal,
	result: Result,
	sequence: number,
	winner: boolean
): Pair?
	local stored = self._store:UpdateAsync(pairKey(result), function(previous)
		if previous == nil then
			return nil
		end
		local pair = previous :: Pair
		local pending = pair.Pending
		if pending == nil or pending.MatchId ~= result.MatchId or pending.Sequence ~= sequence then
			return nil
		end
		local updated = table.clone(pair)
		local nextPending = table.clone(pending)
		if winner then
			nextPending.WinnerSaved = true
		else
			nextPending.LoserSaved = true
		end
		updated.Pending = if nextPending.WinnerSaved and nextPending.LoserSaved
			then nil
			else nextPending
		return updated
	end)
	return stored :: Pair?
end

function MatchSettlementJournal._process(self: MatchSettlementJournal, matchId: string): boolean
	local raw = self._store:GetAsync(`result/{matchId}`)
	if raw == nil then
		return true
	end
	local result = raw :: Result
	local relevant = self._isRelevant
	if relevant ~= nil and not relevant(result.WinnerUserId, result.LoserUserId) then
		return false
	end
	local pair = self:_claim(result)
	local pending = pair.Pending
	if pending ~= nil and pending.MatchId ~= matchId then
		return false
	end
	if pair.LastMatchId ~= matchId or pending == nil then
		-- Cooldown rejection or an already completed result. Never discard a partial payout.
		self._store:RemoveAsync(`result/{matchId}`)
		return true
	end

	for _, didWin in { true, false } do
		local saved = if didWin then pending.WinnerSaved else pending.LoserSaved
		if not saved then
			local userId = if didWin then result.WinnerUserId else result.LoserUserId
			local opponentId = if didWin then result.LoserUserId else result.WinnerUserId
			local reward = if didWin then result.WinReward else result.LossReward
			if
				self._applyAndConfirm(userId, opponentId, pending.Sequence, matchId, didWin, reward)
			then
				self:_acknowledge(result, pending.Sequence, didWin)
			end
		end
	end
	-- The pair state is authoritative. Use UpdateAsync rather than a cached read.
	local current = self._store:UpdateAsync(pairKey(result), function(previous)
		return previous
	end) :: Pair?
	if current ~= nil and (current.LastMatchId ~= matchId or current.Pending == nil) then
		self._store:RemoveAsync(`result/{matchId}`)
		return true
	end
	return false
end

function MatchSettlementJournal.Process(self: MatchSettlementJournal, matchId: string): boolean
	if self._processing[matchId] then
		return false
	end
	self._processing[matchId] = true
	local succeeded, complete = pcall(function()
		return self:_process(matchId)
	end)
	self._processing[matchId] = nil
	if not succeeded then
		warn(`Match settlement {matchId} remains pending: {tostring(complete)}`)
	end
	return succeeded and complete == true
end

function MatchSettlementJournal.ScanPage(self: MatchSettlementJournal)
	local succeeded, message = pcall(function()
		local pages = self._pages
		if pages == nil then
			pages = self._store:ListKeysAsync("result/", MatchConfig.SettlementPageSize, "", true)
			self._pages = pages
		end
		assert(pages ~= nil, "Settlement page is missing")
		for _, key in pages:GetCurrentPage() do
			self:Process(string.sub(key.KeyName, 8))
		end
		if pages.IsFinished then
			self._pages = nil
		else
			pages:AdvanceToNextPageAsync()
		end
		return true
	end)
	if not succeeded then
		self._pages = nil
		warn(`Settlement recovery scan failed: {tostring(message)}`)
	end
end

return MatchSettlementJournal
