--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.Config.CombatConfig)
local MovesConfig = require(ReplicatedStorage.Shared.Config.MovesConfig)
local CombatTypes = require(ReplicatedStorage.Shared.Types.CombatTypes)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)

type CombatAction = CombatTypes.CombatAction
type CombatState = CombatTypes.CombatState
type GrappleDirection = CombatTypes.GrappleDirection
type DamageSpec = CombatTypes.DamageSpec
type PlayerData = PlayerDataTypes.PlayerData

local CombatRules = {}

local COSTS = CombatConfig.Costs :: { [CombatAction]: number }
local COOLDOWNS = CombatConfig.Cooldowns :: { [CombatAction]: number }

function CombatRules.GetStaminaCost(action: CombatAction): number
	return COSTS[action]
end

function CombatRules.GetCooldown(action: CombatAction): number
	return COOLDOWNS[action]
end

function CombatRules.ResolveMoveId(data: PlayerData, action: CombatAction, sequence: number?, direction: GrappleDirection?): string?
	local moves = data.Wrestler.Moves

	if action == "Attack" then
		local attackSequence = math.clamp(sequence or 1, 1, 3)
		if attackSequence == 1 then
			return moves.Attack1
		elseif attackSequence == 2 then
			return moves.Attack2
		end
		return moves.Attack3
	elseif action == "RunningAttack" then
		return moves.RunningAttack
	elseif action == "TurnbuckleAttack" then
		return moves.TurnbuckleAttack
	elseif action == "RunningGrapple" then
		return moves.RunningGrappleMove
	elseif action == "Grapple" then
		if direction == "Forward" then
			return moves.GrappleForward
		elseif direction == "Left" then
			return moves.GrappleLeft
		elseif direction == "Backward" then
			return moves.GrappleBackward
		elseif direction == "Right" then
			return moves.GrappleRight
		elseif direction == "Finisher" then
			return moves.Finisher
		end
	elseif action == "Taunt" then
		return moves.Taunt
	end

	return nil
end

function CombatRules.GetDamage(moveId: string): DamageSpec?
	local move = MovesConfig.Get(moveId)
	return if move ~= nil then table.clone(move.Damage) else nil
end

function CombatRules.GetMoveDuration(moveId: string): number?
	local move = MovesConfig.Get(moveId)
	return if move ~= nil then move.Duration else nil
end

function CombatRules.CanStartAction(state: CombatState, action: CombatAction): boolean
	if action == "TurnbuckleAttack" then
		return state == "SittingOnTurnbuckle"
	elseif action == "Taunt" then
		return state == "Roaming"
	elseif action == "Pin" then
		return state == "Roaming" or state == "Running"
	end
	return state == "Roaming" or state == "Running"
end

return table.freeze(CombatRules)
