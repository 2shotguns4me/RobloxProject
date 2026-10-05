--!strict
--[[
	The training opponent's look: an orange block the size of a fighter's body, with a damage %
	label. LocalFighter simulates it like any fighter, driven by the bot or standing still
	(Training/Config.Opponent). Client-only: everyone gets their own.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Fighter = require(Shared:WaitForChild("Combat"):WaitForChild("Fighter"))
local StageGeometry = require(Shared:WaitForChild("Stage"):WaitForChild("StageGeometry"))
local PercentLabel = require("../Hud/PercentLabel")
local Config = require("./Config")

local TrainingDummy = {}

export type View = {
	Model: Model,
	Body: Part,
	Label: TextLabel,
}

function TrainingDummy.create(bodyHalfWidth: number, bodyHeight: number): View
	local model = Instance.new("Model")
	model.Name = "TrainingDummy"

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.Size = Vector3.new(bodyHalfWidth * 2, bodyHeight, Config.Depth)
	body.Color = Config.Color
	body.Material = Enum.Material.SmoothPlastic
	body.Parent = model
	model.PrimaryPart = body

	local label = PercentLabel.create(body)
	model.Parent = Workspace
	return { Model = model, Body = body, Label = label }
end

-- Draws the dummy from its simulated state. `offset` is the visual hitstop shake.
function TrainingDummy.render(view: View, f: Fighter.State, bodyHeight: number, offset: Vector3)
	local position = Vector3.new(f.Body.X, f.Body.Y + bodyHeight / 2, StageGeometry.PlaneZ)
	view.Body.CFrame = CFrame.new(position + offset)
	PercentLabel.set(view.Label, f.Percent)
end

function TrainingDummy.centre(f: Fighter.State, bodyHeight: number): Vector3
	return Vector3.new(f.Body.X, f.Body.Y + bodyHeight / 2, StageGeometry.PlaneZ)
end

return TrainingDummy
