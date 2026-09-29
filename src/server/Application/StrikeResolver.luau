--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.Config.CombatConfig)
local CombatTypes = require(ReplicatedStorage.Shared.Types.CombatTypes)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local Promise = require(ReplicatedStorage.Packages.Promise)
local Trove = require(ReplicatedStorage.Packages.Trove)

local ActionBudgetModule = require(script.Parent.Parent.Domain.Combat.ActionBudget)
local CharacterAdapter = require(script.Parent.Parent.Adapters.CharacterAdapter)
local CombatRules = require(script.Parent.Parent.Domain.Combat.CombatRules)
local CombatantModule = require(script.Parent.Parent.Domain.Combat.Combatant)
local RecoverySchedulerModule = require(script.Parent.Parent.Domain.Combat.RecoveryScheduler)

type ActionBudget = ActionBudgetModule.ActionBudget
type CombatAction = CombatTypes.CombatAction
type CombatState = CombatTypes.CombatState
type Combatant = CombatantModule.Combatant
type DamageSpec = CombatTypes.DamageSpec
type PlayerData = PlayerDataTypes.PlayerData
type RecoveryScheduler = RecoverySchedulerModule.RecoveryScheduler
type ResolvedAction = CombatTypes.ResolvedAction

type DataSource = {
	Get: (self: DataSource, player: Player) -> PlayerData?,
}

type GetCombatant = (player: Player) -> Combatant?
type FindTarget = (player: Player, range: number) -> Player?
type EmitToParticipants = (attacker: Player, target: Player?, event: ResolvedAction) -> ()
type EmitStarted = (attacker: Player, event: ResolvedAction) -> ()
type CanResolve = (attacker: Player) -> boolean

export type Dependencies = {
	DataSource: DataSource,
	Budget: ActionBudget,
	Recovery: RecoveryScheduler,
	GetCombatant: GetCombatant,
	FindTarget: FindTarget,
	EmitToParticipants: EmitToParticipants,
	EmitStarted: EmitStarted,
	CanResolve: CanResolve,
}

local StrikeResolver = {}
StrikeResolver.__index = StrikeResolver

export type StrikeResolver = typeof(setmetatable(
	{} :: {
		_trove: typeof(Trove.new()),
		_dataSource: DataSource,
		_budget: ActionBudget,
		_recovery: RecoveryScheduler,
		_getCombatant: GetCombatant,
		_findTarget: FindTarget,
		_emitToParticipants: EmitToParticipants,
		_emitStarted: EmitStarted,
		_canResolve: CanResolve,
	},
	{} :: typeof(StrikeResolver)
))

local function getActionState(action: CombatAction): CombatState
	if action == "Attack" or action == "RunningAttack" then
		return "Attacking"
	elseif action == "Taunt" then
		return "Taunting"
	end
	return "PerformingMove"
end

function StrikeResolver.new(dependencies: Dependencies): StrikeResolver
	return setmetatable({
		_trove = Trove.new(),
		_dataSource = dependencies.DataSource,
		_budget = dependencies.Budget,
		_recovery = dependencies.Recovery,
		_getCombatant = dependencies.GetCombatant,
		_findTarget = dependencies.FindTarget,
		_emitToParticipants = dependencies.EmitToParticipants,
		_emitStarted = dependencies.EmitStarted,
		_canResolve = dependencies.CanResolve,
	}, StrikeResolver)
end

function StrikeResolver:_emitResolved(attacker: Player, target: Player?, event: ResolvedAction)
	local emitted, message = pcall(self._emitToParticipants, attacker, target, event)
	if not emitted then
		warn(`Combat presentation failed for user {attacker.UserId}: {tostring(message)}`)
	end
end

function StrikeResolver:Request(
	player: Player,
	action: CombatAction,
	combatant: Combatant
): (boolean, string?)
	local data = self._dataSource:Get(player)
	if data == nil then
		return false, "Player data is unavailable"
	end

	local sequence = if action == "Attack" then self._budget:PeekAttackSequence(player) else nil
	local moveId = CombatRules.ResolveMoveId(data, action, sequence, nil)
	if moveId == nil then
		return false, "No move is equipped"
	end

	local damage = CombatRules.GetDamage(moveId)
	local duration = CombatRules.GetMoveDuration(moveId)
	local impactSeconds = if action == "Taunt" then 0 else CombatRules.GetImpactDelay(moveId)
	if damage == nil or duration == nil or impactSeconds == nil or impactSeconds >= duration then
		return false, "Move configuration is missing"
	end

	local actionState = getActionState(action)
	if not combatant:CanSetState(actionState) then
		return false, "State transition rejected"
	end

	if not self._budget:Commit(player, combatant, action) then
		return false, "Action resources changed before commit"
	end
	if sequence ~= nil then
		self._budget:CommitAttackSequence(player, sequence)
	end

	if action == "TurnbuckleAttack" then
		CharacterAdapter.SetMovementEnabled(combatant.Character, true)
	end
	combatant:SetState(actionState)

	local event: ResolvedAction = {
		Action = action,
		MoveId = moveId,
		AttackerUserId = player.UserId,
		Sequence = sequence,
	}
	if action == "Taunt" then
		combatant:AddFinisher(damage.AttackerFinisher)
		self:_emitResolved(player, nil, event)
	else
		local started, startMessage = pcall(self._emitStarted, player, event)
		if not started then
			warn(
				`Combat start presentation failed for user {player.UserId}: {tostring(startMessage)}`
			)
		end
		local range = if action == "TurnbuckleAttack"
			then CombatConfig.Targeting.GrappleRange + 3
			else CombatConfig.Targeting.AttackRange
		local impact = Promise.delay(impactSeconds):andThen(function()
			if
				self._getCombatant(player) ~= combatant
				or combatant:GetState() ~= actionState
				or not self._canResolve(player)
			then
				return
			end
			local targetPlayer: Player? = self._findTarget(player, range)
			local targetCombatant = if targetPlayer ~= nil
				then self._getCombatant(targetPlayer)
				else nil
			if
				targetPlayer ~= nil
				and targetCombatant ~= nil
				and targetCombatant:GetState() ~= "Dead"
			then
				combatant:AddFinisher(damage.AttackerFinisher)
				targetCombatant:ApplyDamage(damage)
				self._recovery:ScheduleVictim(targetCombatant, damage.StunSeconds)
				event.TargetUserId = targetPlayer.UserId
			else
				targetPlayer = nil
			end
			self:_emitResolved(player, targetPlayer, event)
		end)
		self._trove:AddPromise(impact)
	end
	self._recovery:ScheduleState(combatant, actionState, "Roaming", duration)
	return true, nil
end

function StrikeResolver:ApplyWeaponAttack(
	player: Player,
	attacker: Combatant,
	damage: DamageSpec,
	weaponId: string
): boolean
	local targetPlayer = self._findTarget(player, CombatConfig.Targeting.WeaponRange)
	local victim = if targetPlayer ~= nil then self._getCombatant(targetPlayer) else nil
	if targetPlayer == nil or victim == nil or victim:GetState() == "Dead" then
		return false
	end

	attacker:AddFinisher(damage.AttackerFinisher)
	victim:ApplyDamage(damage)
	self._recovery:ScheduleVictim(victim, damage.StunSeconds)

	local event: ResolvedAction = {
		Action = "WeaponAttack",
		WeaponId = weaponId,
		AttackerUserId = player.UserId,
		TargetUserId = targetPlayer.UserId,
	}
	self:_emitResolved(player, targetPlayer, event)
	return true
end

function StrikeResolver:Destroy()
	self._trove:Destroy()
end

return StrikeResolver
