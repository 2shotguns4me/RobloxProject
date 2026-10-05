--!strict
local InputController = require(script.Input.InputController)
local LocalFighter = require(script.Fighter.LocalFighter)
local FighterCamera = require(script.Camera.FighterCamera)

InputController.start()
LocalFighter.start()
FighterCamera.start(LocalFighter.getFocus)
