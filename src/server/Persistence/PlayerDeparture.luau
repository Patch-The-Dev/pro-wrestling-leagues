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

function PlayerDeparture.ReleaseAll(self: PlayerDeparture)
	local loadedPlayers = self._repository:GetLoadedPlayers()
	local remaining = #loadedPlayers
	for _, player in loadedPlayers do
		task.spawn(function()
			local result = { pcall(self.Release, self, player) }
			if result[1] ~= true then
				warn(`Shutdown release failed for user {player.UserId}: {tostring(result[2])}`)
			end
			remaining -= 1
		end)
	end
	local deadline = os.clock() + SHUTDOWN_WAIT_SECONDS
	while (remaining > 0 or self._pending > 0) and os.clock() < deadline do
		task.wait(0.1)
	end
	if remaining > 0 or self._pending > 0 then
		warn("Profile release exceeded the shutdown wait budget")
	end
	self._repository:ReleaseAll()
end

function PlayerDeparture:Destroy() end

return PlayerDeparture
