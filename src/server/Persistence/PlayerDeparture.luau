--!strict

type Repository = {
	Release: (self: Repository, player: Player) -> (),
	ReleaseAll: (self: Repository) -> (),
}

local PlayerDeparture = {}
PlayerDeparture.__index = PlayerDeparture

export type PlayerDeparture = typeof(setmetatable(
	{} :: {
		_repository: Repository,
		_beforeRelease: ((Player) -> ())?,
		_releasing: { [Player]: boolean },
		_pending: number,
		_completed: BindableEvent,
	},
	PlayerDeparture
))

function PlayerDeparture.new(repository: Repository): PlayerDeparture
	return setmetatable({
		_repository = repository,
		_beforeRelease = nil,
		_releasing = {},
		_pending = 0,
		_completed = Instance.new("BindableEvent"),
	}, PlayerDeparture)
end

function PlayerDeparture:SetBeforeRelease(callback: (Player) -> ())
	self._beforeRelease = callback
end

function PlayerDeparture:Release(player: Player)
	if self._releasing[player] then
		return
	end
	self._releasing[player] = true
	self._pending += 1

	local beforeRelease = self._beforeRelease
	if beforeRelease ~= nil then
		local settled, settlementError = pcall(beforeRelease, player)
		if not settled then
			warn(
				`Match settlement failed before releasing user {player.UserId}: {tostring(
					settlementError
				)}`
			)
		end
	end

	local released, releaseError = pcall(self._repository.Release, self._repository, player)
	if not released then
		warn(`Profile release failed for user {player.UserId}: {tostring(releaseError)}`)
	end
	self._releasing[player] = nil
	self._pending -= 1
	self._completed:Fire()
end

function PlayerDeparture:ReleaseAll()
	while self._pending > 0 do
		self._completed.Event:Wait()
	end
	self._repository:ReleaseAll()
end

function PlayerDeparture:Destroy()
	self._completed:Destroy()
end

return PlayerDeparture
