--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchConfig = require(ReplicatedStorage.Shared.Config.MatchConfig)
local MatchTypes = require(ReplicatedStorage.Shared.Types.MatchTypes)

type MatchState = MatchTypes.MatchState

local MatchSession = {}
MatchSession.__index = MatchSession

export type MatchSession = typeof(setmetatable(
	{} :: {
		Id: string,
		ArenaId: string,
		Players: { Player },
		State: MatchState,
		StartedAt: number?,
		_votesToEnd: { [number]: boolean },
	},
	{} :: typeof(MatchSession)
))

function MatchSession.new(id: string, arenaId: string, players: { Player }): MatchSession
	assert(#players >= MatchConfig.MinimumPlayers, "Match requires enough players")
	assert(#players <= MatchConfig.MaximumPlayers, "Match has too many players")

	return setmetatable({
		Id = id,
		ArenaId = arenaId,
		Players = table.clone(players),
		State = "Waiting",
		StartedAt = nil,
		_votesToEnd = {},
	}, MatchSession)
end

function MatchSession:_setState(state: MatchState)
	if self.State == state then
		return
	end

	self.State = state
end

function MatchSession:Contains(player: Player): boolean
	return table.find(self.Players, player) ~= nil
end

function MatchSession:BeginStarting(): boolean
	if self.State ~= "Waiting" then
		return false
	end
	self:_setState("Starting")
	return true
end

function MatchSession:Start(): boolean
	if self.State ~= "Starting" then
		return false
	end

	self.StartedAt = workspace:GetServerTimeNow()
	self:_setState("Active")
	return true
end

function MatchSession:VoteToEnd(player: Player): boolean
	if self.State ~= "Active" or not self:Contains(player) then
		return false
	end

	self._votesToEnd[player.UserId] = true

	local votes = 0
	for _ in self._votesToEnd do
		votes += 1
	end

	return votes / #self.Players >= MatchConfig.VoteToEndFraction
end

function MatchSession:Finish(): boolean
	if self.State ~= "Active" then
		return false
	end

	self:_setState("Ending")
	self:_setState("Complete")
	return true
end

function MatchSession:Cancel(): boolean
	if self.State ~= "Waiting" and self.State ~= "Starting" then
		return false
	end

	self:_setState("Ending")
	self:_setState("Complete")
	return true
end

function MatchSession:GetDuration(): number
	if self.StartedAt == nil then
		return 0
	end

	return math.max(0, workspace:GetServerTimeNow() - self.StartedAt)
end

function MatchSession:Destroy()
	table.clear(self._votesToEnd)
end

return MatchSession
