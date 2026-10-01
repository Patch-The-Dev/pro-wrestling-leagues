--!strict

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type RateLimiter = typeof(setmetatable(
	{} :: {
		capacity: number,
		refillPerSecond: number,
		tokens: { [number]: number },
		updatedAt: { [number]: number },
	},
	RateLimiter
))

function RateLimiter.new(capacity: number, refillPerSecond: number): RateLimiter
	assert(capacity > 0, "capacity must be positive")
	assert(refillPerSecond > 0, "refillPerSecond must be positive")

	return setmetatable({
		capacity = capacity,
		refillPerSecond = refillPerSecond,
		tokens = {},
		updatedAt = {},
	}, RateLimiter)
end

function RateLimiter.Allow(self: RateLimiter, userId: number, cost: number?): boolean
	local requestedCost = cost or 1
	if requestedCost <= 0 then
		return false
	end

	local now = os.clock()
	local previous = self.updatedAt[userId] or now
	local current = self.tokens[userId] or self.capacity
	local replenished = math.min(self.capacity, current + (now - previous) * self.refillPerSecond)

	self.updatedAt[userId] = now

	if replenished < requestedCost then
		self.tokens[userId] = replenished
		return false
	end

	self.tokens[userId] = replenished - requestedCost
	return true
end

function RateLimiter.Forget(self: RateLimiter, userId: number)
	self.tokens[userId] = nil
	self.updatedAt[userId] = nil
end

return RateLimiter
