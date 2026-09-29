--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatTypes = require(ReplicatedStorage.Shared.Types.CombatTypes)
local NetworkTypes = require(ReplicatedStorage.Shared.Types.NetworkTypes)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)

type AppearanceAssetField = PlayerDataTypes.AppearanceAssetField
type CombatAction = CombatTypes.CombatAction
type GrappleDirection = CombatTypes.GrappleDirection
type MoveSlot = PlayerDataTypes.MoveSlot
type WeaponAction = NetworkTypes.WeaponAction

local Contracts = {}

local COMBAT_ACTIONS: { [string]: boolean } = {
	Attack = true,
	RunningAttack = true,
	Grapple = true,
	RunningGrapple = true,
	TurnbuckleAttack = true,
	Taunt = true,
	Dash = true,
	Pin = true,
}

local GRAPPLE_DIRECTIONS: { [string]: boolean } = {
	Forward = true,
	Left = true,
	Backward = true,
	Right = true,
	Finisher = true,
}

local WEAPON_ACTIONS: { [string]: boolean } = {
	Pickup = true,
	Drop = true,
	Attack = true,
}

local MOVE_SLOTS: { [string]: boolean } = {
	Attack1 = true,
	Attack2 = true,
	Attack3 = true,
	RunningAttack = true,
	TurnbuckleAttack = true,
	RunningGrappleMove = true,
	GrappleForward = true,
	GrappleLeft = true,
	GrappleBackward = true,
	GrappleRight = true,
	Finisher = true,
	Taunt = true,
}

local APPEARANCE_FIELDS: { [string]: boolean } = {
	HairId = true,
	FaceId = true,
	ShirtId = true,
	PantsId = true,
}

local function isShortString(value: unknown, maximumLength: number): boolean
	return type(value) == "string" and #value > 0 and #value <= maximumLength
end

function Contracts.IsCombatAction(value: unknown): boolean
	return type(value) == "string" and COMBAT_ACTIONS[value] == true
end

function Contracts.AsCombatAction(value: unknown): CombatAction?
	return if Contracts.IsCombatAction(value) then value :: CombatAction else nil
end

function Contracts.IsGrappleDirection(value: unknown): boolean
	return type(value) == "string" and GRAPPLE_DIRECTIONS[value] == true
end

function Contracts.AsGrappleDirection(value: unknown): GrappleDirection?
	return if Contracts.IsGrappleDirection(value) then value :: GrappleDirection else nil
end

function Contracts.IsSessionId(value: unknown): boolean
	return isShortString(value, 64)
end

function Contracts.IsMoveSlot(value: unknown): boolean
	return type(value) == "string" and MOVE_SLOTS[value] == true
end

function Contracts.AsMoveSlot(value: unknown): MoveSlot?
	return if Contracts.IsMoveSlot(value) then value :: MoveSlot else nil
end

function Contracts.IsMoveId(value: unknown): boolean
	return isShortString(value, 64)
end

function Contracts.IsShopItemId(value: unknown): boolean
	return isShortString(value, 80)
end

function Contracts.IsWeaponNetworkId(value: unknown): boolean
	return isShortString(value, 96)
end

function Contracts.IsWeaponAction(value: unknown): boolean
	return type(value) == "string" and WEAPON_ACTIONS[value] == true
end

function Contracts.AsWeaponAction(value: unknown): WeaponAction?
	return if Contracts.IsWeaponAction(value) then value :: WeaponAction else nil
end

function Contracts.IsAppearanceAssetField(value: unknown): boolean
	return type(value) == "string" and APPEARANCE_FIELDS[value] == true
end

function Contracts.AsAppearanceAssetField(value: unknown): AppearanceAssetField?
	return if Contracts.IsAppearanceAssetField(value) then value :: AppearanceAssetField else nil
end

function Contracts.IsOptionalAssetId(value: unknown): boolean
	return value == nil
		or (type(value) == "string" and #value > 0 and #value <= 32 and string.match(value, "^%d+$") ~= nil)
end

return table.freeze(Contracts)
