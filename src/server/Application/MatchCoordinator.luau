--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Promise = require(ReplicatedStorage.Packages.Promise)
local Trove = require(ReplicatedStorage.Packages.Trove)
local MatchConfig = require(ReplicatedStorage.Shared.Config.MatchConfig)
local MatchTypes = require(ReplicatedStorage.Shared.Types.MatchTypes)
local NetworkTypes = require(ReplicatedStorage.Shared.Types.NetworkTypes)

local CharacterAdapter = require(script.Parent.Parent.Adapters.CharacterAdapter)
local ArenaRegistryModule = require(script.Parent.Parent.Components.ArenaRegistry)
local MatchSessionModule = require(script.Parent.Parent.Domain.Match.MatchSession)

type ArenaRegistry = ArenaRegistryModule.ArenaRegistry
type MatchEndReason = MatchTypes.MatchEndReason
type MatchResult = MatchTypes.MatchResult
type MatchSession = MatchSessionModule.MatchSession
type MatchUpdate = NetworkTypes.MatchUpdate

type DataSource = {
	IsLoaded: (self: DataSource, player: Player) -> boolean,
}

type EconomySource = {
	ApplyMatchReward: (self: EconomySource, player: Player, didWin: boolean) -> boolean,
}

type EntranceSource = {
	PlayForPlayers: (self: EntranceSource, players: { Player }, arenaId: string) -> (),
}

type EmitQueueChanged = (player: Player, queued: boolean) -> ()
type EmitMatchChanged = (player: Player, update: MatchUpdate) -> ()
type OnSessionClosed = (players: { Player }, result: MatchResult) -> ()

export type Dependencies = {
	DataSource: DataSource,
	EconomySource: EconomySource,
	EntranceSource: EntranceSource,
	EmitQueueChanged: EmitQueueChanged,
	EmitMatchChanged: EmitMatchChanged,
	OnSessionClosed: OnSessionClosed,
}

local MatchCoordinator = {}
MatchCoordinator.__index = MatchCoordinator

local function isCharacterReady(player: Player): boolean
	local character = player.Character
	if character == nil then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	return humanoid ~= nil and humanoid.Health > 0 and root ~= nil and root:IsA("BasePart")
end

export type MatchCoordinator = typeof(setmetatable(
	{} :: {
		_trove: typeof(Trove.new()),
		_arenaRegistry: ArenaRegistry,
		_dataSource: DataSource,
		_economySource: EconomySource,
		_entranceSource: EntranceSource,
		_emitQueueChanged: EmitQueueChanged,
		_emitMatchChanged: EmitMatchChanged,
		_onSessionClosed: OnSessionClosed,
		_queue: { Player },
		_matchesByPlayer: { [Player]: MatchSession },
		_sessions: { [string]: MatchSession },
	},
	{} :: typeof(MatchCoordinator)
))

function MatchCoordinator.new(dependencies: Dependencies): MatchCoordinator
	local trove = Trove.new()
	local arenaRegistry = ArenaRegistryModule.new()

	local self = setmetatable({
		_trove = trove,
		_arenaRegistry = arenaRegistry,
		_dataSource = dependencies.DataSource,
		_economySource = dependencies.EconomySource,
		_entranceSource = dependencies.EntranceSource,
		_emitQueueChanged = dependencies.EmitQueueChanged,
		_emitMatchChanged = dependencies.EmitMatchChanged,
		_onSessionClosed = dependencies.OnSessionClosed,
		_queue = {},
		_matchesByPlayer = {},
		_sessions = {},
	}, MatchCoordinator)

	trove:Add(arenaRegistry)
	trove:Connect(Players.PlayerRemoving, function(player)
		self:_handlePlayerRemoving(player)
	end)

	return self
end

function MatchCoordinator:_queueIndex(player: Player): number?
	return table.find(self._queue, player)
end

function MatchCoordinator:JoinQueue(player: Player): (boolean, string?)
	if not self._dataSource:IsLoaded(player) then
		return false, "Player data is not loaded"
	end
	if self._matchesByPlayer[player] ~= nil then
		return false, "Already in a match"
	end
	if not isCharacterReady(player) then
		return false, "Character is not ready"
	end
	if self:_queueIndex(player) ~= nil then
		return true, nil
	end

	table.insert(self._queue, player)
	self._emitQueueChanged(player, true)
	self:_matchmake()
	return true, nil
end

function MatchCoordinator:LeaveQueue(player: Player)
	local index = self:_queueIndex(player)
	if index == nil then
		return
	end

	table.remove(self._queue, index)
	self._emitQueueChanged(player, false)
end

function MatchCoordinator:_matchmake()
	while #self._queue >= MatchConfig.MinimumPlayers do
		local players: { Player } = {}
		while #players < MatchConfig.MaximumPlayers and #self._queue > 0 do
			local player = table.remove(self._queue, 1)
			if player.Parent == Players and self._dataSource:IsLoaded(player) and isCharacterReady(player) then
				table.insert(players, player)
			else
				self._emitQueueChanged(player, false)
			end
		end

		if #players < MatchConfig.MinimumPlayers then
			for _, player in players do
				table.insert(self._queue, player)
			end
			return
		end

		if not self:_createMatch(players) then
			for index = #players, 1, -1 do
				local player = players[index]
				if
					player.Parent == Players
					and self._dataSource:IsLoaded(player)
					and isCharacterReady(player)
					and self._matchesByPlayer[player] == nil
				then
					table.insert(self._queue, 1, player)
					self._emitQueueChanged(player, true)
				end
			end
			return
		end
	end
end

function MatchCoordinator:_createMatch(players: { Player }): boolean
	local id = HttpService:GenerateGUID(false)
	local arenaId = self._arenaRegistry:Reserve(id, #players, MatchConfig.DefaultArenaId)
	if arenaId == nil then
		return false
	end

	local session = MatchSessionModule.new(id, arenaId, players)
	assert(session:BeginStarting(), "New match session must enter Starting state")
	self._sessions[id] = session

	local startsAt = workspace:GetServerTimeNow() + MatchConfig.StartCountdownSeconds
	for _, player in players do
		self._matchesByPlayer[player] = session
		self._emitQueueChanged(player, false)
		self._emitMatchChanged(player, {
			Id = session.Id,
			State = "Starting",
			ArenaId = session.ArenaId,
			StartsAt = startsAt,
		})
	end

	if not self:_placePlayers(session) then
		warn(string.format("Arena %q does not provide enough valid spawn points for match %s", session.ArenaId, session.Id))
		self:_abortStartingSession(session)
		return false
	end
	self._entranceSource:PlayForPlayers(players, session.ArenaId)

	local countdown = Promise.delay(MatchConfig.StartCountdownSeconds):andThen(function()
		if self._sessions[id] ~= session or not session:Start() then
			return
		end

		for _, player in session.Players do
			self._emitMatchChanged(player, {
				Id = session.Id,
				State = "Active",
				ArenaId = session.ArenaId,
				StartedAt = session.StartedAt,
			})
		end
	end)
	self._trove:AddPromise(countdown)
	return true
end

function MatchCoordinator:_placePlayers(session: MatchSession): boolean
	local spawns = self._arenaRegistry:GetSpawnCFrames(session.ArenaId)
	if #spawns < #session.Players then
		return false
	end

	for index, player in session.Players do
		local character = player.Character
		if character == nil then
			return false
		end

		CharacterAdapter.PlaceAt(character, spawns[index])
	end
	return true
end

function MatchCoordinator:GetOpponents(player: Player): { Player }
	local session = self._matchesByPlayer[player]
	if session == nil then
		return {}
	end

	local opponents: { Player } = {}
	for _, candidate in session.Players do
		if candidate ~= player and candidate.Parent == Players then
			table.insert(opponents, candidate)
		end
	end
	return opponents
end

function MatchCoordinator:IsMatchActiveFor(player: Player): boolean
	local session = self._matchesByPlayer[player]
	return session ~= nil and session.State == "Active"
end

function MatchCoordinator:_getArenaId(player: Player): string?
	local session = self._matchesByPlayer[player]
	return if session ~= nil then session.ArenaId else nil
end

function MatchCoordinator:IsInstanceInPlayerArena(player: Player, instance: Instance): boolean
	local arenaId = self:_getArenaId(player)
	return arenaId ~= nil and self._arenaRegistry:Contains(arenaId, instance)
end

function MatchCoordinator:FinishForKnockout(loser: Player)
	local winner = self:GetOpponents(loser)[1]
	if winner ~= nil then
		self:FinishMatch(winner, loser, "Knockout")
	end
end

function MatchCoordinator:_abortStartingSession(session: MatchSession)
	local result: MatchResult = {
		WinnerUserId = nil,
		LoserUserId = nil,
		Reason = "Cancelled",
		DurationSeconds = 0,
	}

	if not session:Cancel() then
		return
	end

	for _, player in session.Players do
		if player.Parent == Players then
			self._emitMatchChanged(player, {
				Id = session.Id,
				State = "Complete",
				Result = result,
			})
		end
	end
	self._onSessionClosed(table.clone(session.Players), result)
	self:_cleanupSession(session)
end

function MatchCoordinator:_cancelStartingSession(session: MatchSession, departingPlayer: Player)
	local result: MatchResult = {
		WinnerUserId = nil,
		LoserUserId = nil,
		Reason = "Cancelled",
		DurationSeconds = 0,
	}

	if not session:Cancel() then
		return
	end

	local remaining: { Player } = {}
	for _, player in session.Players do
		if player ~= departingPlayer and player.Parent == Players then
			self._emitMatchChanged(player, {
				Id = session.Id,
				State = "Complete",
				Result = result,
			})
			table.insert(remaining, player)
		end
	end

	self._onSessionClosed(table.clone(session.Players), result)
	self:_cleanupSession(session)
	for _, player in remaining do
		self:JoinQueue(player)
	end
end

function MatchCoordinator:_finishSession(
	session: MatchSession,
	winner: Player?,
	loser: Player?,
	reason: MatchEndReason
): boolean
	if session.State ~= "Active" then
		return false
	end
	if winner ~= nil and not session:Contains(winner) then
		return false
	end
	if loser ~= nil and not session:Contains(loser) then
		return false
	end
	if winner ~= nil and winner == loser then
		return false
	end

	local result: MatchResult = {
		WinnerUserId = if winner ~= nil then winner.UserId else nil,
		LoserUserId = if loser ~= nil then loser.UserId else nil,
		Reason = reason,
		DurationSeconds = session:GetDuration(),
	}

	if not session:Finish() then
		return false
	end

	if winner ~= nil then
		self._economySource:ApplyMatchReward(winner, true)
	end
	if loser ~= nil then
		self._economySource:ApplyMatchReward(loser, false)
	end

	for _, player in session.Players do
		self._emitMatchChanged(player, {
			Id = session.Id,
			State = "Complete",
			Result = result,
		})
	end
	self._onSessionClosed(table.clone(session.Players), result)

	local cleanup = Promise.delay(MatchConfig.PostMatchSeconds):andThen(function()
		self:_cleanupSession(session)
	end)
	self._trove:AddPromise(cleanup)
	return true
end

function MatchCoordinator:FinishMatch(winner: Player?, loser: Player?, reason: MatchEndReason): boolean
	local anchor = winner or loser
	if anchor == nil then
		return false
	end

	local session = self._matchesByPlayer[anchor]
	if session == nil then
		return false
	end

	return self:_finishSession(session, winner, loser, reason)
end

function MatchCoordinator:_cleanupSession(session: MatchSession)
	if self._sessions[session.Id] ~= session then
		return
	end

	self._sessions[session.Id] = nil
	self._arenaRegistry:Release(session.Id)
	for _, player in session.Players do
		if self._matchesByPlayer[player] == session then
			self._matchesByPlayer[player] = nil
		end
	end
	session:Destroy()
end

function MatchCoordinator:VoteToEnd(player: Player): boolean
	local session = self._matchesByPlayer[player]
	if session == nil then
		return false
	end

	if session:VoteToEnd(player) then
		return self:_finishSession(session, nil, nil, "Vote")
	end
	return true
end

function MatchCoordinator:_handlePlayerRemoving(player: Player)
	self:LeaveQueue(player)

	local session = self._matchesByPlayer[player]
	if session == nil or session.State == "Complete" then
		return
	end

	if session.State == "Active" then
		local opponent = self:GetOpponents(player)[1]
		if opponent ~= nil then
			self:FinishMatch(opponent, player, "Forfeit")
		else
			self:_cleanupSession(session)
		end
	else
		self:_cancelStartingSession(session, player)
	end
end

function MatchCoordinator:Destroy()
	for _, session in self._sessions do
		session:Destroy()
	end
	table.clear(self._sessions)
	table.clear(self._matchesByPlayer)
	table.clear(self._queue)
	self._trove:Destroy()
end

return MatchCoordinator
