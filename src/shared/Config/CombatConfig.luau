--!strict

local CombatConfig = {
	MaxHealth = 100,
	MaxStamina = 100,
	MaxPoise = 100,
	MaxFinisher = 100,

	StaminaRegenerationPerSecond = 14,
	StaminaRegenerationDelay = 0.8,
	PoiseRecoveryPerSecond = 8,
	GroundedSeconds = 1.7,
	DefaultStunSeconds = 0.65,

	Targeting = {
		AttackRange = 6,
		GrappleRange = 7,
		PinRange = 7,
		WeaponRange = 8,
		TurnbuckleRange = 6,
		MinimumFacingDot = 0.2,
	},

	Costs = {
		Attack = 5,
		RunningAttack = 10,
		Grapple = 8,
		RunningGrapple = 12,
		TurnbuckleAttack = 12,
		Taunt = 0,
		Dash = 15,
		Pin = 0,
	},

	Cooldowns = {
		Attack = 0.38,
		RunningAttack = 0.85,
		Grapple = 0.7,
		RunningGrapple = 1,
		TurnbuckleAttack = 1.2,
		Taunt = 1.5,
		Dash = 2,
		Pin = 1,
	},

	Finisher = {
		RequiredCharge = 100,
	},

	Pin = {
		InputWindowSeconds = 0.16,
		MaximumOneWayLatencyCompensationSeconds = 0.12,
		FirstPromptDelay = 0.75,
		SecondPromptDelay = 1.0,
		ThirdPromptDelay = 1.25,
		MaximumMisses = 3,
	},

	Movement = {
		RunningSpeedThreshold = 12,
		DashBackwardSpeed = 35,
		MaximumPlausibleSpeed = 48,
		MaximumPlausibleAscentSpeed = 75,
		MaximumPlausibleDescentSpeed = 260,
		PositionSlackStuds = 5,
		VerticalPositionSlackStuds = 8,
		SampleIntervalSeconds = 0.1,
		SuspiciousMovementLockSeconds = 1,
	},

	Reversal = {
		WindowSeconds = 0.8,
		StaminaReward = 8,
		FinisherReward = 5,
	},
}

table.freeze(CombatConfig.Targeting)
table.freeze(CombatConfig.Costs)
table.freeze(CombatConfig.Cooldowns)
table.freeze(CombatConfig.Finisher)
table.freeze(CombatConfig.Pin)
table.freeze(CombatConfig.Movement)
table.freeze(CombatConfig.Reversal)
table.freeze(CombatConfig)

return CombatConfig
