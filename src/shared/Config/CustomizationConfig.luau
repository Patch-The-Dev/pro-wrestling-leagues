--!strict

local CustomizationConfig = {
	MoveSlots = {
		Attack1 = "Attack",
		Attack2 = "Attack",
		Attack3 = "Attack",
		RunningAttack = "RunningAttack",
		TurnbuckleAttack = "TurnbuckleAttack",
		RunningGrappleMove = "RunningGrapple",
		GrappleForward = "Grapple",
		GrappleLeft = "Grapple",
		GrappleBackward = "Grapple",
		GrappleRight = "Grapple",
		Finisher = "Grapple",
		Taunt = "Taunt",
	},
	DefaultMoves = {
		Attack1 = "Left Punch",
		Attack2 = "Right Punch",
		Attack3 = "Left Punch",
		RunningAttack = "Clothesline",
		TurnbuckleAttack = "Dive",
		RunningGrappleMove = "Shoulder Tackle",
		GrappleForward = "Bodyslam",
		GrappleLeft = "Drop Kick",
		GrappleBackward = "Head Thrust",
		GrappleRight = "DDT",
		Finisher = "Suplex",
		Taunt = "Raise Hands",
	},
}

table.freeze(CustomizationConfig.MoveSlots)
table.freeze(CustomizationConfig.DefaultMoves)
table.freeze(CustomizationConfig)

return CustomizationConfig
