--!strict

local InputConfig = {
	Attack = Enum.UserInputType.MouseButton1,
	Grapple = Enum.KeyCode.E,
	Context = Enum.KeyCode.Q,
	Pin = Enum.KeyCode.F,
	RunningAttack = Enum.KeyCode.R,
	TurnbuckleAttack = Enum.KeyCode.V,
	TurnbuckleClimb = Enum.KeyCode.C,
	Taunt = Enum.KeyCode.T,
	Dash = Enum.KeyCode.X,
	RunModifier = Enum.KeyCode.LeftShift,
	Gamepad = {
		Attack = Enum.KeyCode.ButtonR2,
		Grapple = Enum.KeyCode.ButtonX,
		Context = Enum.KeyCode.ButtonB,
		Pin = Enum.KeyCode.ButtonY,
		RunningAttack = Enum.KeyCode.ButtonR1,
		TurnbuckleAttack = Enum.KeyCode.ButtonL1,
		TurnbuckleClimb = Enum.KeyCode.DPadUp,
		Taunt = Enum.KeyCode.DPadDown,
		Dash = Enum.KeyCode.ButtonR3,
		RunModifier = Enum.KeyCode.ButtonL2,
	},
}

table.freeze(InputConfig.Gamepad)
table.freeze(InputConfig)

return InputConfig
