--!strict

local PendingProfileLoads = {}
PendingProfileLoads.__index = PendingProfileLoads

export type PendingProfileLoads = typeof(setmetatable(
	{} :: {
		_pending: { [Player]: boolean },
	},
	{} :: typeof(PendingProfileLoads)
))

function PendingProfileLoads.new(): PendingProfileLoads
	return setmetatable({ _pending = {} }, PendingProfileLoads)
end

function PendingProfileLoads.Start(self: PendingProfileLoads, player: Player): boolean
	if self._pending[player] then
		return false
	end
	self._pending[player] = true
	return true
end

function PendingProfileLoads.Finish(self: PendingProfileLoads, player: Player)
	self._pending[player] = nil
end

function PendingProfileLoads.HasPending(self: PendingProfileLoads): boolean
	return next(self._pending) ~= nil
end

return PendingProfileLoads
