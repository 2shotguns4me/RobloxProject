--!strict
local Workspace = game:GetService("Workspace")

local InputController = require("@self/Input/InputController")
local LocalFighter = require("@self/Fighter/LocalFighter")
local FightCamera = require("@self/Camera/FightCamera")

InputController.start()
LocalFighter.start()

-- The Studio feel harness drives the camera itself when it's switched on.
if Workspace:GetAttribute("FeelHarness") ~= true then
	FightCamera.Start()
	LocalFighter.onFocusChanged(FightCamera.SetTargets)
end
