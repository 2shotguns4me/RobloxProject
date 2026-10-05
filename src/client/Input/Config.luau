--!strict
-- Default bindings and touch layout (docs/GameScope.md, "Controls and netcode").
-- Remapping comes later; attack, special, shield and grab are added with the hit pipeline.

return {
	Keyboard = {
		Left = { Enum.KeyCode.A, Enum.KeyCode.Left },
		Right = { Enum.KeyCode.D, Enum.KeyCode.Right },
		Up = { Enum.KeyCode.W, Enum.KeyCode.Up },
		Down = { Enum.KeyCode.S, Enum.KeyCode.Down },
		Jump = { Enum.KeyCode.Space },
	},

	Gamepad = {
		Jump = { Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonY },
	},

	Touch = {
		JoystickRadius = 70, -- pixels the thumb travels for a full tilt
		JoystickBaseSize = 140,
		JoystickKnobSize = 60,
		JumpButtonSize = 110,
		JumpButtonPosition = UDim2.new(1, -150, 1, -150), -- top-left corner of the button
	},
}
