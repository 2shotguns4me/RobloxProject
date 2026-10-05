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

local Movement = require(ReplicatedStorage.Shared.Movement.Movement)
local Config = require(script.Parent.Config)

local InputController = {}

local jumpPresses = 0 -- jump presses not yet handed to the simulation
local gamepadStick = Vector2.zero
local touchStick = Vector2.zero
local touchJumpHeld = false

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

	local jumpButton = Instance.new("TextButton")
	jumpButton.Name = "Jump"
	jumpButton.Size = UDim2.fromOffset(touch.JumpButtonSize, touch.JumpButtonSize)
	jumpButton.Position = touch.JumpButtonPosition
	jumpButton.BackgroundColor3 = Color3.new(1, 1, 1)
	jumpButton.BackgroundTransparency = 0.5
	jumpButton.Text = "Jump"
	jumpButton.TextScaled = true
	jumpButton.AutoButtonColor = false
	Instance.new("UICorner", jumpButton).CornerRadius = UDim.new(0.5, 0)
	jumpButton.Parent = gui

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
		if table.find(Config.Keyboard.Jump, input.KeyCode) or table.find(Config.Gamepad.Jump, input.KeyCode) then
			jumpPresses += 1
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Thumbstick1 then
			gamepadStick = Vector2.new(input.Position.X, input.Position.Y)
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
end

-- Call once per simulation frame. Each press is handed out exactly once, so a tap
-- shorter than a frame still registers.
function InputController.read(): Movement.Intent
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

	local keyX = axis(anyKeyDown(keys.Left), anyKeyDown(keys.Right))
	local keyY = axis(anyKeyDown(keys.Down), anyKeyDown(keys.Up))

	local jumpPressed = jumpPresses > 0
	if jumpPressed then
		jumpPresses -= 1
	end

	return {
		MoveX = strongest({ keyX, dpadX, gamepadStick.X, touchStick.X }),
		MoveY = strongest({ keyY, dpadY, gamepadStick.Y, touchStick.Y }),
		JumpHeld = anyKeyDown(keys.Jump) or anyGamepadButtonDown(Config.Gamepad.Jump) or touchJumpHeld,
		JumpPressed = jumpPressed,
	}
end

return InputController
