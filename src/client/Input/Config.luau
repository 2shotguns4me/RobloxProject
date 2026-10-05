--!strict
-- Default bindings and touch layout (docs/GameScope.md, "Controls and netcode").
-- Remapping comes later; special and grab come with their systems.

return {
	Keyboard = {
		Left = { Enum.KeyCode.A, Enum.KeyCode.Left },
		Right = { Enum.KeyCode.D, Enum.KeyCode.Right },
		Up = { Enum.KeyCode.W, Enum.KeyCode.Up },
		Down = { Enum.KeyCode.S, Enum.KeyCode.Down },
		Jump = { Enum.KeyCode.Space },
		Attack = { Enum.KeyCode.J },
		Smash = { Enum.KeyCode.L }, -- aims with A/D, otherwise the way you face
		Shield = { Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift }, -- + direction to dodge
	},

	Gamepad = {
		Jump = { Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonY },
		Attack = { Enum.KeyCode.ButtonX },
		Shield = { Enum.KeyCode.ButtonL2, Enum.KeyCode.ButtonR2 }, -- triggers
		-- Flicking the right stick past this tilt is a smash in that direction.
		SmashStickThreshold = 0.7,
	},

	Touch = {
		JoystickRadius = 70, -- pixels the thumb travels for a full tilt
		JoystickBaseSize = 140,
		JoystickKnobSize = 60,
		JumpButtonSize = 110,
		JumpButtonPosition = UDim2.new(1, -150, 1, -150), -- top-left corner of the button
		AttackButtonSize = 120,
		AttackButtonPosition = UDim2.new(1, -290, 1, -170),
		-- Tap Attack to attack; swipe off it sideways at least this many pixels for a smash.
		SmashSwipePixels = 40,
		-- Hold Shield to shield; move the joystick while holding it to dodge.
		ShieldButtonSize = 90,
		ShieldButtonPosition = UDim2.new(1, -140, 1, -270),
	},
}
