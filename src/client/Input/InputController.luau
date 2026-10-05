--!strict
--[[
	Turns keyboard, gamepad and touch input into one Movement.Intent per simulation frame.

	Turns off Roblox's default character controls and touch UI, since our own controller
	moves the fighter. The touch joystick and Jump button are built here for now; they move
	to a Studio-built layout with the rest of the UI later.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Fighter = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Combat"):WaitForChild("Fighter"))
local Config = require("./Config")

local InputController = {}

local jumpPresses = 0 -- jump presses not yet handed to the simulation
local attackPresses = 0
local smashPresses = 0
local smashX = 0 -- aim of the most recent smash press: -1, 0 (facing) or 1
local smashStickOut = false -- right stick is past the smash threshold
local gamepadStick = Vector2.zero
local touchStick = Vector2.zero
local touchJumpHeld = false
local touchShieldHeld = false

local function anyKeyDown(keys: { Enum.KeyCode }): boolean
	for _, key in keys do
		if UserInputService:IsKeyDown(key) then
			return true
		end
	end
	return false
end

local function anyGamepadButtonDown(buttons: { Enum.KeyCode }): boolean
	for _, button in buttons do
		if UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, button) then
			return true
		end
	end
	return false
end

local function axis(negative: boolean, positive: boolean): number
	return (if positive then 1 else 0) - (if negative then 1 else 0)
end

-- Whichever device is pushed furthest wins on each axis.
local function strongest(values: { number }): number
	local best = 0
	for _, v in values do
		if math.abs(v) > math.abs(best) then
			best = v
		end
	end
	return math.clamp(best, -1, 1)
end

local function disableDefaultControls()
	local player = Players.LocalPlayer
	task.spawn(function()
		local ok, err = pcall(function()
			local playerModule = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript
			local module = require(playerModule) :: any
			module:GetControls():Disable()
		end)
		if not ok then
			warn("Could not disable default controls:", err)
		end
	end)
	pcall(function()
		GuiService.TouchControlsEnabled = false
	end)
end

local function keyboardX(): number
	return axis(anyKeyDown(Config.Keyboard.Left), anyKeyDown(Config.Keyboard.Right))
end

local function pressSmash(direction: number)
	smashPresses += 1
	smashX = direction
end

local function roundButton(name: string, size: number, position: UDim2, parent: Instance): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.fromOffset(size, size)
	button.Position = position
	button.BackgroundColor3 = Color3.new(1, 1, 1)
	button.BackgroundTransparency = 0.5
	button.Text = name
	button.TextScaled = true
	button.AutoButtonColor = false
	Instance.new("UICorner", button).CornerRadius = UDim.new(0.5, 0)
	button.Parent = parent
	return button
end

local function buildTouchControls()
	local touch = Config.Touch
	local gui = Instance.new("ScreenGui")
	gui.Name = "TouchControls"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true

	local base = Instance.new("Frame")
	base.Name = "JoystickBase"
	base.AnchorPoint = Vector2.new(0.5, 0.5)
	base.Size = UDim2.fromOffset(touch.JoystickBaseSize, touch.JoystickBaseSize)
	base.BackgroundColor3 = Color3.new(1, 1, 1)
	base.BackgroundTransparency = 0.8
	base.Visible = false
	Instance.new("UICorner", base).CornerRadius = UDim.new(0.5, 0)
	base.Parent = gui

	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.fromScale(0.5, 0.5)
	knob.Size = UDim2.fromOffset(touch.JoystickKnobSize, touch.JoystickKnobSize)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.BackgroundTransparency = 0.3
	Instance.new("UICorner", knob).CornerRadius = UDim.new(0.5, 0)
	knob.Parent = base

	local jumpButton = roundButton("Jump", touch.JumpButtonSize, touch.JumpButtonPosition, gui)
	local shieldButton = roundButton("Shield", touch.ShieldButtonSize, touch.ShieldButtonPosition, gui)
	shieldButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			touchShieldHeld = true
		end
	end)
	shieldButton.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			touchShieldHeld = false
		end
	end)
	local attackButton = roundButton("Attack", touch.AttackButtonSize, touch.AttackButtonPosition, gui)

	-- Attack: a tap attacks when the thumb lifts; swiping sideways off the button smashes
	-- the moment the swipe is long enough.
	local attackTouch: InputObject? = nil
	local attackStart = Vector2.zero
	local swiped = false
	attackButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch and not attackTouch then
			attackTouch = input
			attackStart = Vector2.new(input.Position.X, input.Position.Y)
			swiped = false
		end
	end)
	UserInputService.TouchMoved:Connect(function(input: InputObject)
		if input ~= attackTouch or swiped then
			return
		end
		local dx = input.Position.X - attackStart.X
		if math.abs(dx) >= touch.SmashSwipePixels then
			swiped = true
			pressSmash(math.sign(dx))
		end
	end)
	UserInputService.TouchEnded:Connect(function(input: InputObject)
		if input ~= attackTouch then
			return
		end
		attackTouch = nil
		if not swiped then
			attackPresses += 1
		end
	end)

	jumpButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			touchJumpHeld = true
			jumpPresses += 1
		end
	end)
	jumpButton.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			touchJumpHeld = false
		end
	end)

	-- Floating joystick: appears wherever a thumb lands on the left half of the screen.
	local activeTouch: InputObject? = nil
	local origin = Vector2.zero

	UserInputService.TouchStarted:Connect(function(input, gameProcessed)
		if gameProcessed or activeTouch then
			return
		end
		local position = Vector2.new(input.Position.X, input.Position.Y)
		local camera = workspace.CurrentCamera
		if camera and position.X > camera.ViewportSize.X / 2 then
			return
		end
		activeTouch = input
		origin = position
		base.Position = UDim2.fromOffset(position.X, position.Y)
		knob.Position = UDim2.fromScale(0.5, 0.5)
		base.Visible = true
	end)

	UserInputService.TouchMoved:Connect(function(input)
		if input ~= activeTouch then
			return
		end
		local offset = Vector2.new(input.Position.X, input.Position.Y) - origin
		if offset.Magnitude > touch.JoystickRadius then
			offset = offset.Unit * touch.JoystickRadius
		end
		knob.Position = UDim2.new(0.5, offset.X, 0.5, offset.Y)
		-- Screen Y points down; movement Y points up.
		touchStick = Vector2.new(offset.X, -offset.Y) / touch.JoystickRadius
	end)

	UserInputService.TouchEnded:Connect(function(input)
		if input ~= activeTouch then
			return
		end
		activeTouch = nil
		touchStick = Vector2.zero
		base.Visible = false
	end)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

function InputController.start()
	disableDefaultControls()

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		local key = input.KeyCode
		if table.find(Config.Keyboard.Jump, key) or table.find(Config.Gamepad.Jump, key) then
			jumpPresses += 1
		elseif table.find(Config.Keyboard.Attack, key) or table.find(Config.Gamepad.Attack, key) then
			attackPresses += 1
		elseif table.find(Config.Keyboard.Smash, key) then
			pressSmash(keyboardX())
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Thumbstick1 then
			gamepadStick = Vector2.new(input.Position.X, input.Position.Y)
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
			local stick = Vector2.new(input.Position.X, input.Position.Y)
			local out = stick.Magnitude >= Config.Gamepad.SmashStickThreshold
			if out and not smashStickOut then
				-- Mostly sideways flicks aim the smash; up or down flicks use facing for now.
				pressSmash(if math.abs(stick.X) >= math.abs(stick.Y) then math.sign(stick.X) else 0)
			end
			smashStickOut = out
		end
	end)

	UserInputService.GamepadDisconnected:Connect(function()
		gamepadStick = Vector2.zero
	end)

	if UserInputService.TouchEnabled then
		buildTouchControls()
	end
end

-- Forget presses made while there was no fighter to use them (e.g. while respawning).
function InputController.clearPresses()
	jumpPresses = 0
	attackPresses = 0
	smashPresses = 0
end

-- Call once per simulation frame. Each press is handed out exactly once, so a tap
-- shorter than a frame still registers.
function InputController.read(): Fighter.Intent
	local keys = Config.Keyboard
	local pad = Enum.UserInputType.Gamepad1
	local dpadX = axis(
		UserInputService:IsGamepadButtonDown(pad, Enum.KeyCode.DPadLeft),
		UserInputService:IsGamepadButtonDown(pad, Enum.KeyCode.DPadRight)
	)
	local dpadY = axis(
		UserInputService:IsGamepadButtonDown(pad, Enum.KeyCode.DPadDown),
		UserInputService:IsGamepadButtonDown(pad, Enum.KeyCode.DPadUp)
	)

	-- Ignore the keyboard while typing in chat or another text box.
	local typing = UserInputService:GetFocusedTextBox() ~= nil
	local keyX = if typing then 0 else keyboardX()
	local keyY = if typing then 0 else axis(anyKeyDown(keys.Down), anyKeyDown(keys.Up))
	local keyJump = not typing and anyKeyDown(keys.Jump)
	local keyShield = not typing and anyKeyDown(keys.Shield)

	local jumpPressed = jumpPresses > 0
	if jumpPressed then
		jumpPresses -= 1
	end
	local attackPressed = attackPresses > 0
	if attackPressed then
		attackPresses -= 1
	end
	local smashPressed = smashPresses > 0
	if smashPressed then
		smashPresses -= 1
	end

	return {
		MoveX = strongest({ keyX, dpadX, gamepadStick.X, touchStick.X }),
		MoveY = strongest({ keyY, dpadY, gamepadStick.Y, touchStick.Y }),
		JumpHeld = keyJump or anyGamepadButtonDown(Config.Gamepad.Jump) or touchJumpHeld,
		JumpPressed = jumpPressed,
		AttackPressed = attackPressed,
		SmashPressed = smashPressed,
		SmashX = smashX,
		ShieldHeld = keyShield or anyGamepadButtonDown(Config.Gamepad.Shield) or touchShieldHeld,
	}
end

return InputController
