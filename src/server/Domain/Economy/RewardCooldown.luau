--!strict

local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MatchConfig = require(ReplicatedStorage.Shared.Config.MatchConfig)

type RewardMap = {
	UpdateAsync: (
		self: RewardMap,
		key: string,
		transform: (unknown) -> number?,
		expiration: number
	) -> number?,
}

local RewardCooldown = {}
RewardCooldown.__index = RewardCooldown

export type RewardCooldown = typeof(setmetatable(
	{} :: {
		_map: RewardMap?,
		_localClaims: { [string]: number },
	},
	RewardCooldown
))

function RewardCooldown.new(map: RewardMap?): RewardCooldown
	local resolvedMap = map
	if resolvedMap == nil and not RunService:IsStudio() then
		resolvedMap = (
			MemoryStoreService:GetHashMap("ProWrestlingLeaguesRewardPairsV1") :: unknown
		) :: RewardMap
	end
	return setmetatable({
		_map = resolvedMap,
		_localClaims = {},
	}, RewardCooldown)
end

function RewardCooldown:TryClaim(firstUserId: number, secondUserId: number, now: number): boolean
	local low = math.min(firstUserId, secondUserId)
	local high = math.max(firstUserId, secondUserId)
	local key = `{low}:{high}`
	local cooldown = MatchConfig.RepeatOpponentRewardCooldownSeconds
	for oldKey, claimedAt in self._localClaims do
		if now - claimedAt >= cooldown then
			self._localClaims[oldKey] = nil
		end
	end
	local lastLocalClaim = self._localClaims[key]
	if lastLocalClaim ~= nil and now - lastLocalClaim < cooldown then
		return false
	end

	local map = self._map
	if map ~= nil then
		local succeeded, claimedAt = pcall(function()
			return map:UpdateAsync(key, function(previous)
				if type(previous) == "number" and now - previous < cooldown then
					return nil
				end
				return now
			end, cooldown)
		end)
		if not succeeded then
			warn(`Reward cooldown claim failed for pair {key}: {tostring(claimedAt)}`)
			return false
		end
		if claimedAt ~= now then
			return false
		end
	end

	self._localClaims[key] = now
	return true
end

function RewardCooldown:Destroy()
	table.clear(self._localClaims)
end

return RewardCooldown
