--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RateLimiter = require(ReplicatedStorage.Shared.Util.RateLimiter)

export type Channel = "Combat" | "Interaction" | "Customization" | "Economy" | "Data"

local RequestGuard = {}
RequestGuard.__index = RequestGuard

export type RequestGuard = typeof(setmetatable(
	{} :: {
		_limiters: { [Channel]: RateLimiter.RateLimiter },
	},
	RequestGuard
))

function RequestGuard.new(): RequestGuard
	return setmetatable({
		_limiters = {
			Combat = RateLimiter.new(12, 8),
			Interaction = RateLimiter.new(8, 4),
			Customization = RateLimiter.new(6, 2),
			Economy = RateLimiter.new(4, 1),
			Data = RateLimiter.new(4, 1),
		} :: { [Channel]: RateLimiter.RateLimiter },
	}, RequestGuard)
end

function RequestGuard:Allow(player: Player, channel: Channel): boolean
	return self._limiters[channel]:Allow(player.UserId)
end

function RequestGuard:Forget(player: Player)
	for _, limiter in self._limiters do
		limiter:Forget(player.UserId)
	end
end

return RequestGuard
