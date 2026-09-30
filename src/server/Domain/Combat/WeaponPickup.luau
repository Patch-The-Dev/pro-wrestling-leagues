--!strict

type MatchSource = {
	IsMatchActiveFor: (self: MatchSource, player: Player) -> boolean,
	IsInstanceInPlayerArena: (self: MatchSource, player: Player, instance: Instance) -> boolean,
}

type MovementSource = {
	IsMovementPlausible: (self: MovementSource, player: Player) -> boolean,
}

local WeaponPickup = {}

function WeaponPickup.Try(
	player: Player,
	weapon: Instance,
	matchSource: MatchSource,
	movementSource: MovementSource,
	isAvailable: () -> boolean,
	isNearWeapon: () -> boolean,
	pickup: () -> boolean
): (boolean, string?)
	if not matchSource:IsMatchActiveFor(player) then
		return false, "No active match"
	end
	if not matchSource:IsInstanceInPlayerArena(player, weapon) then
		return false, "Weapon is outside this match arena"
	end
	if not movementSource:IsMovementPlausible(player) then
		return false, "Character movement is not plausible"
	end
	if not isAvailable() or not isNearWeapon() then
		return false, "Weapon is not available in range"
	end
	if not pickup() then
		return false, "Weapon cannot be picked up"
	end
	return true, nil
end

return table.freeze(WeaponPickup)
