--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatTypes = require(ReplicatedStorage.Shared.Types.CombatTypes)
local WeaponComponentModule = require(script.Parent.Parent.Parent.Components.WeaponComponent)

type DamageSpec = CombatTypes.DamageSpec
type WeaponComponent = WeaponComponentModule.WeaponComponent

type MatchSource = {
	IsMatchActiveFor: (self: MatchSource, player: Player) -> boolean,
}

type CombatSource = {
	ApplyWeaponAttack: (
		self: CombatSource,
		player: Player,
		damage: DamageSpec,
		weaponId: string
	) -> boolean,
}

local WeaponAttack = {}

function WeaponAttack.Try(
	player: Player,
	component: WeaponComponent,
	matchSource: MatchSource,
	combatSource: CombatSource,
	belongsToArena: (Player, WeaponComponent) -> boolean
): (boolean, string?)
	if not component:IsEquippedBy(player) then
		return false, "Weapon must be equipped"
	end
	if not matchSource:IsMatchActiveFor(player) then
		return false, "No active match"
	end
	if not belongsToArena(player, component) then
		return false, "Weapon does not belong to this match arena"
	end
	if not component:CanUse() then
		return false, "Weapon is not ready"
	end

	local consumed, previousUsedAt, revision = component:ConsumeUse()
	if not consumed then
		return false, "Weapon state changed before commit"
	end
	local appliedWithoutError, applied = pcall(function()
		return combatSource:ApplyWeaponAttack(
			player,
			component:GetDamageSpec(),
			component.DefinitionId
		)
	end)
	if not appliedWithoutError or not applied then
		component:RollbackUse(previousUsedAt :: number, revision :: number)
		if not appliedWithoutError then
			warn(`Weapon attack failed for user {player.UserId}: {tostring(applied)}`)
		end
		return false, "No valid target"
	end
	return true, nil
end

return table.freeze(WeaponAttack)
