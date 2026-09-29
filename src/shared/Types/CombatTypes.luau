--!strict

export type CombatState =
	"Roaming"
	| "Running"
	| "Stunned"
	| "Grounded"
	| "Falling"
	| "ClimbingTurnbuckle"
	| "SittingOnTurnbuckle"
	| "Attacking"
	| "Grappling"
	| "PerformingMove"
	| "Taunting"
	| "StandingUp"
	| "Pinning"
	| "Pinned"
	| "Dead"

export type CombatAction =
	"Attack"
	| "RunningAttack"
	| "Grapple"
	| "RunningGrapple"
	| "TurnbuckleAttack"
	| "Taunt"
	| "Dash"
	| "Pin"

export type GrappleDirection = "Forward" | "Left" | "Backward" | "Right" | "Finisher"
export type ResolvedActionName = CombatAction | "Reversal" | "WeaponAttack"
export type MoveCategory =
	"Attack"
	| "RunningAttack"
	| "Grapple"
	| "RunningGrapple"
	| "TurnbuckleAttack"
	| "Taunt"

export type CombatSnapshot = {
	State: CombatState,
	Health: number,
	MaxHealth: number,
	Stamina: number,
	MaxStamina: number,
	Poise: number,
	MaxPoise: number,
	Finisher: number,
	MaxFinisher: number,
}

export type ResolvedAction = {
	Action: ResolvedActionName,
	MoveId: string?,
	WeaponId: string?,
	AttackerUserId: number,
	TargetUserId: number?,
	Sequence: number?,
	IsFinisher: boolean?,
}

export type DamageSpec = {
	HealthDamage: number,
	PoiseDamage: number,
	AttackerFinisher: number,
	VictimFinisher: number,
	StunSeconds: number,
}

return {}
