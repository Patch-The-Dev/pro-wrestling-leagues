--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchConfig = require(ReplicatedStorage.Shared.Config.MatchConfig)
local MatchTypes = require(ReplicatedStorage.Shared.Types.MatchTypes)
local NetworkTypes = require(ReplicatedStorage.Shared.Types.NetworkTypes)
local Promise = require(ReplicatedStorage.Packages.Promise)
local Trove = require(ReplicatedStorage.Shared.Util.Cleanup)

local ArenaRegistryModule = require(script.Parent.Parent.Components.ArenaRegistry)
local MatchPlacementModule = require(script.Parent.Parent.Domain.Match.MatchPlacement)
local MatchSessionModule = require(script.Parent.Parent.Domain.Match.MatchSession)
local RewardPolicy = require(script.Parent.Parent.Domain.Economy.RewardPolicy)

type ArenaRegistry = ArenaRegistryModule.ArenaRegistry
type MatchEndReason = MatchTypes.MatchEndReason
type MatchResult = MatchTypes.MatchResult
type MatchSession = MatchSessionModule.MatchSession
type MatchPlacement = MatchPlacementModule.MatchPlacement
type MatchUpdate = NetworkTypes.MatchUpdate
type Settlement = {
	Complete: boolean,
	Cleaned: boolean,
	Players: { Player },
}

type DataSource = {
	IsLoaded: (self: DataSource, player: Player) -> boolean,
}

type EconomySource = {
	RecordMatchResult: (
		self: EconomySource,
		winner: Player,
		loser: Player,
		matchId: string,
		finishedAt: number
	) -> boolean,
}

type EntranceSource = {
	PlayForPlayers: (
		self: EntranceSource,
		players: { Player },
		arenaId: string,
		matchId: string,
		matchStartsAt: number
	) -> (),
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
		_trove: Trove.Trove,
		_arenaRegistry: ArenaRegistry,
		_dataSource: DataSource,
		_economySource: EconomySource,
		_entranceSource: EntranceSource,
		_emitQueueChanged: EmitQueueChanged,
		_emitMatchChanged: EmitMatchChanged,
		_onSessionClosed: OnSessionClosed,
		_queue: { Player },
		_matchesByPlayer: { [Player]: MatchSession? },
		_sessions: { [string]: MatchSession },
		_placements: { [string]: MatchPlacement },
		_settlementsByPlayer: { [Player]: Settlement },
		_destroyed: boolean,
	},
	{} :: typeof(MatchCoordinator)
))

function MatchCoordinator.new(dependencies: Dependencies): MatchCoordinator
	local trove = Trove.new()
	local arenaRegistry = ArenaRegistryModule.new()

	local self: MatchCoordinator = setmetatable({
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
		_placements = {},
		_settlementsByPlayer = {},
		_destroyed = false,
	}, MatchCoordinator)

	trove:Add(function()
		arenaRegistry:Destroy()
	end)
	local availableConnection = arenaRegistry.Available:Connect(function()
		self:_matchmake()
	end)
	trove:Add(function()
		availableConnection:Disconnect()
	end)
	return self
end

function MatchCoordinator._queueIndex(self: MatchCoordinator, player: Player): number?
	return table.find(self._queue, player)
end

function MatchCoordinator.JoinQueue(self: MatchCoordinator, player: Player): (boolean, string?)
	if not self._dataSource:IsLoaded(player) then
		return false, "Player data is not loaded"
	end
	if self._matchesByPlayer[player] ~= nil then
		return false, "Already in a match"
	end
	local priorSettlement = self._settlementsByPlayer[player]
	if priorSettlement ~= nil and not priorSettlement.Complete then
		return false, "Previous match reward is still settling"
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

function MatchCoordinator.LeaveQueue(self: MatchCoordinator, player: Player)
	local index = self:_queueIndex(player)
	if index == nil then
		return
	end

	table.remove(self._queue, index)
	self._emitQueueChanged(player, false)
end

function MatchCoordinator._isQueueReady(self: MatchCoordinator, player: Player): boolean
	local settlement: Settlement? = self._settlementsByPlayer[player]
	return player.Parent == Players
		and self._dataSource:IsLoaded(player)
		and self._matchesByPlayer[player] == nil
		and (settlement == nil or settlement.Complete)
		and isCharacterReady(player)
end

function MatchCoordinator._matchmake(self: MatchCoordinator)
	while #self._queue >= MatchConfig.MinimumPlayers do
		local players: { Player } = {}
		while #players < MatchConfig.MaximumPlayers and #self._queue > 0 do
			local player = table.remove(self._queue, 1)
			assert(player ~= nil, "Non-empty queue must contain a player")
			if self:_isQueueReady(player) then
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
				if self:_isQueueReady(player) and self._matchesByPlayer[player] == nil then
					table.insert(self._queue, 1, player)
					self._emitQueueChanged(player, true)
				end
			end
			return
		end
	end
end

function MatchCoordinator._notifyMatchChanged(
	self: MatchCoordinator,
	player: Player,
	update: MatchUpdate
)
	local notified, notificationError = pcall(function()
		self._emitMatchChanged(player, update)
		return true
	end)
	if not notified then
		warn(`Match notification failed for user {player.UserId}: {tostring(notificationError)}`)
	end
end

function MatchCoordinator._startCountdown(
	self: MatchCoordinator,
	session: MatchSession,
	startingCharacters: { [Player]: Model }
)
	local countdown = Promise.delay(MatchConfig.StartCountdownSeconds):andThen(function()
		if self._sessions[session.Id] ~= session or session.State ~= "Starting" then
			return
		end
		for _, player in session.Players do
			if
				player.Parent ~= Players
				or not self._dataSource:IsLoaded(player)
				or player.Character ~= startingCharacters[player]
				or not isCharacterReady(player)
			then
				self:_cancelStartingSession(session)
				for _, candidate in session.Players do
					if
						candidate ~= player
						and candidate.Parent == Players
						and isCharacterReady(candidate)
					then
						self:JoinQueue(candidate)
					end
				end
				return
			end
		end
		if not session:Start() then
			return
		end

		for _, player in session.Players do
			self:_notifyMatchChanged(player, {
				Id = session.Id,
				State = "Active",
				ArenaId = session.ArenaId,
				StartedAt = session.StartedAt,
			})
		end
	end)
	self._trove:AddPromise(countdown)
end

function MatchCoordinator._createMatch(self: MatchCoordinator, players: { Player }): boolean
	local id = HttpService:GenerateGUID(false)
	local session: MatchSession? = nil
	local initialized, result = pcall(function(): boolean
		local arenaId = self._arenaRegistry:Reserve(id, #players, MatchConfig.DefaultArenaId)
		if arenaId == nil then
			return false
		end

		local startingSession = MatchSessionModule.new(id, arenaId, players)
		session = startingSession
		self._sessions[id] = startingSession
		assert(startingSession:BeginStarting(), "New match session must enter Starting state")

		local startsAt = workspace:GetServerTimeNow() + MatchConfig.StartCountdownSeconds
		for _, player in players do
			self._matchesByPlayer[player] = startingSession
			self._emitQueueChanged(player, false)
		end

		if not self:_placePlayers(startingSession) then
			error(`Arena {arenaId} could not place every player for match {id}`)
		end
		for _, player in players do
			self._emitMatchChanged(player, {
				Id = id,
				State = "Starting",
				ArenaId = arenaId,
				StartsAt = startsAt,
			})
		end
		local startingCharacters: { [Player]: Model } = {}
		for _, player in players do
			startingCharacters[player] = player.Character :: Model
		end
		self._entranceSource:PlayForPlayers(players, arenaId, id, startsAt)
		self:_startCountdown(startingSession, startingCharacters)
		return true
	end)
	if initialized and result then
		return true
	end
	if not initialized then
		warn(`Match {id} could not start: {tostring(result)}`)
	end
	if session ~= nil then
		local failedSession = session
		local rolledBack, rollbackError = pcall(function()
			self:_cancelStartingSession(failedSession)
			return true
		end)
		if not rolledBack or self._sessions[id] == failedSession then
			if not rolledBack then
				warn(`Match {id} rollback failed: {tostring(rollbackError)}`)
			end
			local placement: MatchPlacement? = self._placements[id]
			if placement ~= nil then
				pcall(placement.Restore, placement)
				self._placements[id] = nil
			end
			self._sessions[id] = nil
			for _, player in players do
				if self._matchesByPlayer[player] == failedSession then
					self._matchesByPlayer[player] = nil
				end
			end
			self._arenaRegistry:Release(id)
			failedSession:Destroy()
		end
	else
		self._arenaRegistry:Release(id)
	end
	return false
end

function MatchCoordinator._releaseSettlement(self: MatchCoordinator, settlement: Settlement)
	if not settlement.Complete or not settlement.Cleaned then
		return
	end
	for _, player in settlement.Players do
		if self._settlementsByPlayer[player] == settlement then
			self._settlementsByPlayer[player] = nil
		end
	end
end

function MatchCoordinator._completeSettlement(self: MatchCoordinator, settlement: Settlement)
	if settlement.Complete then
		return
	end
	settlement.Complete = true
	self:_releaseSettlement(settlement)
end

function MatchCoordinator._waitForSettlement(
	_self: MatchCoordinator,
	settlement: Settlement,
	deadline: number
)
	while not settlement.Complete and os.clock() < deadline do
		task.wait(0.1)
	end
	if not settlement.Complete then
		warn("Match reward settlement did not finish before the profile release deadline")
	end
end

function MatchCoordinator._settleRewards(
	self: MatchCoordinator,
	settlement: Settlement,
	winner: Player,
	loser: Player,
	matchId: string,
	finishedAt: number
)
	local attempt = 0
	while not self._destroyed do
		attempt += 1
		local succeeded, recorded = pcall(function()
			return self._economySource:RecordMatchResult(winner, loser, matchId, finishedAt)
		end)
		if succeeded and recorded then
			-- Completion here means the journal durably owns recovery, not that
			-- an unconfirmed in-memory balance change counts as a saved payout.
			self:_completeSettlement(settlement)
			return
		end
		if attempt == 1 or attempt % 10 == 0 then
			warn(`Match result {matchId} still awaits durable recording: {tostring(recorded)}`)
		end
		task.wait(math.min(5, 0.5 * 2 ^ math.min(attempt - 1, 4)))
	end
	warn(`Match result {matchId} could not be recorded before shutdown`)
end

function MatchCoordinator._placePlayers(self: MatchCoordinator, session: MatchSession): boolean
	local spawns = self._arenaRegistry:GetSpawnCFrames(session.ArenaId)
	local placement = MatchPlacementModule.new(session.Players, spawns)
	if placement == nil or not placement:Place() then
		return false
	end
	self._placements[session.Id] = placement
	return true
end

function MatchCoordinator.GetOpponents(self: MatchCoordinator, player: Player): { Player }
	local session: MatchSession? = self._matchesByPlayer[player]
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

function MatchCoordinator.IsMatchActiveFor(self: MatchCoordinator, player: Player): boolean
	local session: MatchSession? = self._matchesByPlayer[player]
	return session ~= nil and session.State == "Active"
end

function MatchCoordinator.IsMatchInProgressFor(self: MatchCoordinator, player: Player): boolean
	local session: MatchSession? = self._matchesByPlayer[player]
	return session ~= nil and (session.State == "Starting" or session.State == "Active")
end

function MatchCoordinator._getArenaId(self: MatchCoordinator, player: Player): string?
	local session: MatchSession? = self._matchesByPlayer[player]
	return if session ~= nil then session.ArenaId else nil
end

function MatchCoordinator.IsInstanceInPlayerArena(
	self: MatchCoordinator,
	player: Player,
	instance: Instance
): boolean
	local arenaId = self:_getArenaId(player)
	return arenaId ~= nil and self._arenaRegistry:Contains(arenaId, instance)
end

function MatchCoordinator.FinishForKnockout(self: MatchCoordinator, loser: Player)
	local winner: Player? = self:GetOpponents(loser)[1]
	if winner ~= nil then
		self:FinishMatch(winner, loser, "Knockout")
	end
end

function MatchCoordinator._cancelStartingSession(
	self: MatchCoordinator,
	session: MatchSession,
	departingPlayer: Player?
)
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
		if (departingPlayer == nil or player ~= departingPlayer) and player.Parent == Players then
			self:_notifyMatchChanged(player, {
				Id = session.Id,
				State = "Complete",
				Result = result,
			})
			if departingPlayer then
				table.insert(remaining, player)
			end
		end
	end

	local closed, closeError = pcall(function()
		self._onSessionClosed(table.clone(session.Players), result)
		return true
	end)
	if not closed then
		warn(`Match close callback failed for match {session.Id}: {tostring(closeError)}`)
	end
	self:_cleanupSession(session)
	for _, player in remaining do
		self:JoinQueue(player)
	end
end

function MatchCoordinator._finishSession(
	self: MatchCoordinator,
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
	local settlement: Settlement = {
		Complete = false,
		Cleaned = false,
		Players = table.clone(session.Players),
	}
	for _, player in session.Players do
		self._settlementsByPlayer[player] = settlement
	end

	if
		winner ~= nil
		and loser ~= nil
		and RewardPolicy.IsEligible(reason, result.DurationSeconds)
	then
		local finishedAt = os.time()
		task.defer(function()
			self:_settleRewards(settlement, winner, loser, session.Id, finishedAt)
		end)
	else
		self:_completeSettlement(settlement)
	end

	local cleanup = Promise.delay(MatchConfig.PostMatchSeconds):andThen(function()
		self:_cleanupSession(session)
	end)
	self._trove:AddPromise(cleanup)

	for _, player in session.Players do
		self:_notifyMatchChanged(player, {
			Id = session.Id,
			State = "Complete",
			Result = result,
		})
	end
	local closed, closeError = pcall(function()
		self._onSessionClosed(table.clone(session.Players), result)
		return true
	end)
	if not closed then
		warn(`Match close callback failed for match {session.Id}: {tostring(closeError)}`)
	end
	return true
end

function MatchCoordinator.FinishMatch(
	self: MatchCoordinator,
	winner: Player?,
	loser: Player?,
	reason: MatchEndReason
): boolean
	local anchor = winner or loser
	if anchor == nil then
		return false
	end

	local session: MatchSession? = self._matchesByPlayer[anchor]
	if session == nil then
		return false
	end

	return self:_finishSession(session, winner, loser, reason)
end

function MatchCoordinator._cleanupSession(self: MatchCoordinator, session: MatchSession)
	if self._sessions[session.Id] ~= session then
		return
	end

	local placement: MatchPlacement? = self._placements[session.Id]
	if placement ~= nil then
		placement:Restore()
		self._placements[session.Id] = nil
	end
	self._sessions[session.Id] = nil
	self._arenaRegistry:Release(session.Id)
	for _, player in session.Players do
		if self._matchesByPlayer[player] == session then
			self._matchesByPlayer[player] = nil
		end
	end
	session:Destroy()
	local settlement: Settlement? = self._settlementsByPlayer[session.Players[1]]
	if settlement ~= nil then
		settlement.Cleaned = true
		self:_releaseSettlement(settlement)
	end
	self:_matchmake()
end

function MatchCoordinator.VoteToEnd(self: MatchCoordinator, player: Player): boolean
	local session: MatchSession? = self._matchesByPlayer[player]
	if session == nil then
		return false
	end

	if session:VoteToEnd(player) then
		return self:_finishSession(session, nil, nil, "Vote")
	end
	return true
end

function MatchCoordinator.HandlePlayerRemoving(self: MatchCoordinator, player: Player)
	self:LeaveQueue(player)

	local session: MatchSession? = self._matchesByPlayer[player]
	if session ~= nil then
		if session.State == "Active" then
			local opponent = self:GetOpponents(player)[1]
			if opponent then
				self:FinishMatch(opponent, player, "Forfeit")
			else
				self:_cleanupSession(session)
			end
		elseif session.State == "Starting" then
			self:_cancelStartingSession(session, player)
		end
	end

	local settlement: Settlement? = self._settlementsByPlayer[player]
	if settlement ~= nil and not settlement.Complete then
		self:_waitForSettlement(settlement, os.clock() + MatchConfig.SettlementWaitSeconds)
	end
end

function MatchCoordinator.Destroy(self: MatchCoordinator)
	local pending: { Settlement } = {}
	for _, settlement in self._settlementsByPlayer do
		if not settlement.Complete and table.find(pending, settlement) == nil then
			table.insert(pending, settlement)
		end
	end
	local deadline = os.clock() + MatchConfig.SettlementWaitSeconds
	for _, settlement in pending do
		self:_waitForSettlement(settlement, deadline)
	end
	self._destroyed = true
	for _, session in self._sessions do
		local placement: MatchPlacement? = self._placements[session.Id]
		if placement ~= nil then
			placement:Restore()
		end
		session:Destroy()
	end
	table.clear(self._sessions)
	table.clear(self._placements)
	table.clear(self._matchesByPlayer)
	table.clear(self._queue)
	table.clear(self._settlementsByPlayer)
	self._trove:Destroy()
end

return MatchCoordinator
