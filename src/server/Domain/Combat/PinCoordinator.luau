--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.Config.CombatConfig)
local CombatantModule = require(script.Parent.Combatant)
local NetworkTypes = require(ReplicatedStorage.Shared.Types.NetworkTypes)
local PinSessionModule = require(script.Parent.PinSession)
local RecoverySchedulerModule = require(script.Parent.RecoveryScheduler)
local Trove = require(ReplicatedStorage.Shared.Util.Cleanup)

type Combatant = CombatantModule.Combatant
type PinSession = PinSessionModule.PinSession
type RecoveryScheduler = RecoverySchedulerModule.RecoveryScheduler
type PinResolution = NetworkTypes.PinResolution

type GetCombatant = (player: Player) -> Combatant?
type EmitPrompt = (recipient: Player, sessionId: string, targetTime: number) -> ()
type EmitResolved = (recipient: Player, sessionId: string, result: PinResolution) -> ()
type FinishMatch = (winner: Player, loser: Player) -> ()

local PinCoordinator = {}
PinCoordinator.__index = PinCoordinator

export type PinCoordinator = typeof(setmetatable(
	{} :: {
		_trove: Trove.Trove,
		_sessions: { [string]: PinSession },
		_getCombatant: GetCombatant,
		_recovery: RecoveryScheduler,
		_emitPrompt: EmitPrompt,
		_emitResolved: EmitResolved,
		_finishMatch: FinishMatch,
	},
	{} :: typeof(PinCoordinator)
))

function PinCoordinator.new(
	getCombatant: GetCombatant,
	recovery: RecoveryScheduler,
	emitPrompt: EmitPrompt,
	emitResolved: EmitResolved,
	finishMatch: FinishMatch
): PinCoordinator
	return setmetatable({
		_trove = Trove.new(),
		_sessions = {},
		_getCombatant = getCombatant,
		_recovery = recovery,
		_emitPrompt = emitPrompt,
		_emitResolved = emitResolved,
		_finishMatch = finishMatch,
	}, PinCoordinator)
end

function PinCoordinator._settle(self: PinCoordinator, id: string, session: PinSession)
	if self._sessions[id] ~= session then
		return
	end
	self._sessions[id] = nil

	local pinnerCombatant = self._getCombatant(session.Pinner)
	local victimCombatant = self._getCombatant(session.Victim)

	if session:DidEscape() then
		if pinnerCombatant ~= nil and pinnerCombatant:GetState() == "Pinning" then
			pinnerCombatant:SetState("Roaming")
		end
		if victimCombatant ~= nil and victimCombatant:GetState() == "Pinned" then
			victimCombatant:SetState("StandingUp")
			self._recovery:ScheduleState(victimCombatant, "StandingUp", "Roaming", 0.6)
		end
		self._emitResolved(session.Pinner, id, "Escaped")
		self._emitResolved(session.Victim, id, "Escaped")
	else
		self._emitResolved(session.Pinner, id, "Pinned")
		self._emitResolved(session.Victim, id, "Pinned")
		self._finishMatch(session.Pinner, session.Victim)
	end

	session:Destroy()
end

function PinCoordinator._schedulePrompt(self: PinCoordinator, id: string, session: PinSession)
	if self._sessions[id] ~= session or session:IsFinished() then
		self:_settle(id, session)
		return
	end

	local targetTime = session:NextPrompt()
	if targetTime == nil then
		self:_settle(id, session)
		return
	end

	self._emitPrompt(session.Victim, id, targetTime)
	local expiry = session:AwaitPromptExpiry():andThen(function()
		if self._sessions[id] ~= session then
			return
		end
		if not session:IsFinished() then
			session:ExpirePrompt()
		end
		if session:IsFinished() then
			self:_settle(id, session)
		else
			self:_schedulePrompt(id, session)
		end
	end)
	self._trove:AddPromise(expiry)
end

function PinCoordinator.Start(self: PinCoordinator, pinner: Player, victim: Player): boolean
	local id = HttpService:GenerateGUID(false)
	local pingSucceeded, roundTripSeconds = pcall(function()
		return victim:GetNetworkPing()
	end)
	local latencyAllowance = if pingSucceeded
			and type(roundTripSeconds) == "number"
			and roundTripSeconds == roundTripSeconds
			and roundTripSeconds ~= math.huge
		then math.clamp(
			roundTripSeconds * 0.5,
			0,
			CombatConfig.Pin.MaximumOneWayLatencyCompensationSeconds
		)
		else 0
	local session = PinSessionModule.new(id, pinner, victim, latencyAllowance)
	self._sessions[id] = session
	self:_schedulePrompt(id, session)
	return true
end

function PinCoordinator.SubmitInput(
	self: PinCoordinator,
	player: Player,
	sessionId: string
): boolean
	local session: PinSession? = self._sessions[sessionId]
	if session == nil or not session:SubmitInput(player) then
		return false
	end

	self:_settle(sessionId, session)
	return true
end

function PinCoordinator.CancelForPlayer(self: PinCoordinator, player: Player)
	for id, session in self._sessions do
		if session.Pinner == player or session.Victim == player then
			self._sessions[id] = nil

			local pinnerCombatant = self._getCombatant(session.Pinner)
			if pinnerCombatant ~= nil and pinnerCombatant:GetState() == "Pinning" then
				pinnerCombatant:SetState("Roaming")
			end

			local victimCombatant = self._getCombatant(session.Victim)
			if victimCombatant ~= nil and victimCombatant:GetState() == "Pinned" then
				victimCombatant:SetState("Grounded")
				self._recovery:ScheduleVictim(victimCombatant, 0)
			end

			session:Destroy()
		end
	end
end

function PinCoordinator.Destroy(self: PinCoordinator)
	for id, session in self._sessions do
		self._sessions[id] = nil
		session:Destroy()
	end
	self._trove:Destroy()
end

return PinCoordinator
