--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatRules = require(script.Parent.CombatRules)
local CombatTypes = require(ReplicatedStorage.Shared.Types.CombatTypes)
local CombatantModule = require(script.Parent.Combatant)

type CombatAction = CombatTypes.CombatAction
type Combatant = CombatantModule.Combatant

type ComboState = {
	Index: number,
	LastAt: number,
}

local ActionBudget = {}
ActionBudget.__index = ActionBudget

export type ActionBudget = typeof(setmetatable(
	{} :: {
		_cooldowns: { [Player]: { [string]: number } },
		_combos: { [Player]: ComboState },
	},
	{} :: typeof(ActionBudget)
))

function ActionBudget.new(): ActionBudget
	return setmetatable({
		_cooldowns = {},
		_combos = {},
	}, ActionBudget)
end

function ActionBudget:Validate(
	player: Player,
	combatant: Combatant,
	action: CombatAction
): (boolean, string?)
	if not CombatRules.CanStartAction(combatant:GetState(), action) then
		return false, "Action is not valid in the current state"
	end

	local byAction = self._cooldowns[player]
	if byAction ~= nil and os.clock() < (byAction[action] or 0) then
		return false, "Action is on cooldown"
	end

	local staminaCost = CombatRules.GetStaminaCost(action)
	if not combatant:CanSpendStamina(staminaCost) then
		return false, "Not enough stamina"
	end

	return true, nil
end

function ActionBudget:Commit(player: Player, combatant: Combatant, action: CombatAction): boolean
	local staminaCost = CombatRules.GetStaminaCost(action)
	if not combatant:SpendStamina(staminaCost) then
		return false
	end

	local byAction = self._cooldowns[player]
	if byAction == nil then
		byAction = {}
		self._cooldowns[player] = byAction
	end
	byAction[action] = os.clock() + CombatRules.GetCooldown(action)
	return true
end

function ActionBudget:Rollback(player: Player, combatant: Combatant, action: CombatAction)
	local byAction = self._cooldowns[player]
	if byAction ~= nil then
		byAction[action] = nil
	end
	combatant:RestoreStamina(CombatRules.GetStaminaCost(action))
end

function ActionBudget:PeekAttackSequence(player: Player): number
	local combo = self._combos[player]
	local now = os.clock()
	if combo == nil or now - combo.LastAt > 1 then
		return 1
	end
	return (combo.Index % 3) + 1
end

function ActionBudget:CommitAttackSequence(player: Player, sequence: number)
	self._combos[player] = {
		Index = sequence,
		LastAt = os.clock(),
	}
end

function ActionBudget:Forget(player: Player)
	self._cooldowns[player] = nil
	self._combos[player] = nil
end

function ActionBudget:Destroy()
	table.clear(self._cooldowns)
	table.clear(self._combos)
end

return ActionBudget
