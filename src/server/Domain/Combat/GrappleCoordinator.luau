--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.Config.CombatConfig)
local CombatTypes = require(ReplicatedStorage.Shared.Types.CombatTypes)
local CombatantModule = require(script.Parent.Combatant)
local GrappleSessionModule = require(script.Parent.GrappleSession)
local RecoverySchedulerModule = require(script.Parent.RecoveryScheduler)
local Trove = require(ReplicatedStorage.Packages.Trove)

type DamageSpec = CombatTypes.DamageSpec
type ResolvedAction = CombatTypes.ResolvedAction
type Combatant = CombatantModule.Combatant
type GrappleSession = GrappleSessionModule.GrappleSession
type RecoveryScheduler = RecoverySchedulerModule.RecoveryScheduler

type GetCombatant = (player: Player) -> Combatant?
type EmitAction = (recipient: Player, event: ResolvedAction) -> ()
type EmitWindow = (recipient: Player, sessionId: string, endsAt: number) -> ()

local GrappleCoordinator = {}
GrappleCoordinator.__index = GrappleCoordinator

export type GrappleCoordinator = typeof(setmetatable(
	{} :: {
		_trove: typeof(Trove.new()),
		_sessions: { [string]: GrappleSession },
		_getCombatant: GetCombatant,
		_recovery: RecoveryScheduler,
		_emitAction: EmitAction,
		_emitWindow: EmitWindow,
	},
	{} :: typeof(GrappleCoordinator)
))

function GrappleCoordinator.new(
	getCombatant: GetCombatant,
	recovery: RecoveryScheduler,
	emitAction: EmitAction,
	emitWindow: EmitWindow
): GrappleCoordinator
	return setmetatable({
		_trove = Trove.new(),
		_sessions = {},
		_getCombatant = getCombatant,
		_recovery = recovery,
		_emitAction = emitAction,
		_emitWindow = emitWindow,
	}, GrappleCoordinator)
end

function GrappleCoordinator:Start(
	initiator: Player,
	victimPlayer: Player,
	action: "Grapple" | "RunningGrapple",
	moveId: string,
	damage: DamageSpec,
	duration: number,
	isFinisher: boolean
)
	local initiatorCombatant = self._getCombatant(initiator)
	local victimCombatant = self._getCombatant(victimPlayer)
	if initiatorCombatant == nil or victimCombatant == nil then
		return false
	end

	local id = HttpService:GenerateGUID(false)
	local session = GrappleSessionModule.new(id, initiator, victimPlayer)
	self._sessions[id] = session

	local reversalEndsAt = workspace:GetServerTimeNow() + CombatConfig.Reversal.WindowSeconds
	self._emitWindow(victimPlayer, id, reversalEndsAt)

	local resolution = session:AwaitResolution():andThen(function(reversed)
		if self._sessions[id] ~= session then
			return
		end
		self._sessions[id] = nil

		local currentInitiator = self._getCombatant(initiator)
		local currentVictim = self._getCombatant(victimPlayer)
		if currentInitiator ~= initiatorCombatant or currentVictim ~= victimCombatant then
			session:Destroy()
			return
		end

		if reversed then
			victimCombatant:RestoreStamina(CombatConfig.Reversal.StaminaReward)
			victimCombatant:AddFinisher(CombatConfig.Reversal.FinisherReward)
			victimCombatant:SetState("Roaming")
			initiatorCombatant:SetState("Stunned")
			self._recovery:ScheduleVictim(initiatorCombatant, CombatConfig.DefaultStunSeconds)

			local event: ResolvedAction = {
				Action = "Reversal",
				AttackerUserId = victimPlayer.UserId,
				TargetUserId = initiator.UserId,
			}
			self._emitAction(initiator, event)
			self._emitAction(victimPlayer, event)
		else
			initiatorCombatant:SetState("PerformingMove")
			victimCombatant:SetState("PerformingMove")
			initiatorCombatant:AddFinisher(damage.AttackerFinisher)
			victimCombatant:ApplyDamage(damage)

			local event: ResolvedAction = {
				Action = action,
				MoveId = moveId,
				AttackerUserId = initiator.UserId,
				TargetUserId = victimPlayer.UserId,
				IsFinisher = if isFinisher then true else nil,
			}
			self._emitAction(initiator, event)
			self._emitAction(victimPlayer, event)

			self._recovery:ScheduleState(initiatorCombatant, "PerformingMove", "Roaming", duration)
			self._recovery:ScheduleVictim(victimCombatant, math.max(damage.StunSeconds, duration))
		end

		session:Destroy()
	end)
	self._trove:AddPromise(resolution)
	return true
end

function GrappleCoordinator:TryReverse(player: Player, sessionId: string): boolean
	local session = self._sessions[sessionId]
	return session ~= nil and session:TryReverse(player)
end

function GrappleCoordinator:CancelForPlayer(player: Player)
	for id, session in self._sessions do
		if session.Initiator == player or session.Victim == player then
			self._sessions[id] = nil

			local initiatorCombatant = self._getCombatant(session.Initiator)
			if initiatorCombatant ~= nil and initiatorCombatant:GetState() == "Grappling" then
				initiatorCombatant:SetState("Roaming")
			end

			local victimCombatant = self._getCombatant(session.Victim)
			if victimCombatant ~= nil and victimCombatant:GetState() == "Stunned" then
				victimCombatant:SetState("Roaming")
			end

			session:Destroy()
		end
	end
end

function GrappleCoordinator:Destroy()
	for id, session in self._sessions do
		self._sessions[id] = nil
		session:Destroy()
	end
	self._trove:Destroy()
end

return GrappleCoordinator
