--!strict

type Repository = {
	Release: (self: Repository, player: Player) -> (),
	ReleaseAll: (self: Repository) -> (),
	GetLoadedPlayers: (self: Repository) -> { Player },
}

local SHUTDOWN_WAIT_SECONDS = 25

local PlayerDeparture = {}
PlayerDeparture.__index = PlayerDeparture

export type PlayerDeparture = typeof(setmetatable(
	{} :: {
		_repository: Repository,
		_beforeRelease: ((Player) -> ())?,
		_releasing: { [Player]: boolean },
		_pending: number,
	},
	PlayerDeparture
))

function PlayerDeparture.new(repository: Repository): PlayerDeparture
	return setmetatable({
		_repository = repository,
		_beforeRelease = nil,
		_releasing = {},
		_pending = 0,
	}, PlayerDeparture)
end

function PlayerDeparture:SetBeforeRelease(callback: (Player) -> ())
	self._beforeRelease = callback
end

function PlayerDeparture.Release(self: PlayerDeparture, player: Player)
	if self._releasing[player] then
		return
	end
	self._releasing[player] = true
	self._pending += 1

	local beforeRelease = self._beforeRelease
	if beforeRelease ~= nil then
		local result = { pcall(beforeRelease, player) }
		if result[1] ~= true then
			warn(
				`Match settlement failed before releasing user {player.UserId}: {tostring(result[2])}`
			)
		end
	end

	local result = { pcall(self._repository.Release, self._repository, player) }
	if result[1] ~= true then
		warn(`Profile release failed for user {player.UserId}: {tostring(result[2])}`)
	end
	self._releasing[player] = nil
	self._pending -= 1
end

function PlayerDeparture.ReleaseAll(
	self: PlayerDeparture,
	shutdownDeadline: number?,
	hasPendingLoads: (() -> boolean)?
)
	local deadline = shutdownDeadline or os.clock() + SHUTDOWN_WAIT_SECONDS
	local scheduled: { [Player]: boolean } = {}
	local remaining = 0
	while true do
		for _, player in self._repository:GetLoadedPlayers() do
			if not scheduled[player] then
				scheduled[player] = true
				remaining += 1
				task.spawn(function()
					local result = { pcall(self.Release, self, player) }
					if result[1] ~= true then
						warn(
							`Shutdown release failed for user {player.UserId}: {tostring(result[2])}`
						)
					end
					remaining -= 1
				end)
			end
		end
		local loading = hasPendingLoads ~= nil and hasPendingLoads()
		if not loading and remaining == 0 and self._pending == 0 then
			break
		end
		if os.clock() >= deadline then
			warn("Profile loads or releases exceeded the shutdown wait budget")
			break
		end
		task.wait(0.1)
	end
	self._repository:ReleaseAll()
end

function PlayerDeparture:Destroy() end

return PlayerDeparture
