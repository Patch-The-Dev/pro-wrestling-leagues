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
}

table.freeze(InputConfig)

return InputConfig
