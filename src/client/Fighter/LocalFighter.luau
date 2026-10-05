--!strict
--[[
	Drives the local player's character with Movement at a fixed 60 Hz, instead of
	Roblox's Humanoid physics, and pins it to the 2.5D plane.

	The client owns its character's physics, so setting the root's CFrame here replicates
	to the server and other players. Server checks and prediction come with netcode later.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Movement = require(Shared:WaitForChild("Movement"):WaitForChild("Movement"))
local MovementConfig = require(Shared:WaitForChild("Movement"):WaitForChild("Config"))
local StageGeometry = require(Shared:WaitForChild("Stage"):WaitForChild("StageGeometry"))
local InputController = require("../Input/InputController")
local Config = require("./Config")

local FRAME = 1 / 60

local LocalFighter = {}

local activeCharacter: Model? = nil
local focusCallbacks: { (Vector3?) -> () } = {}
local stage: Movement.Stage = { Solids = {}, Platforms = {} }
local stageDirty = true

local function spawnPoint(): (number, number)
	local x, y = StageGeometry.spawnPoint()
	if x and y then
		return x, y
	end
	return Config.FallbackSpawn.X, Config.FallbackSpawn.Y
end

-- Height of the HumanoidRootPart's centre above the feet.
local function rootOffset(humanoid: Humanoid, root: BasePart): number
	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		return root.Size.Y / 2 + 2 -- R6 legs are 2 studs tall and HipHeight is 0
	end
	return humanoid.HipHeight + root.Size.Y / 2
end

local function onCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart

	-- Stop the Humanoid from walking, jumping or turning the character itself.
	humanoid.PlatformStand = true
	humanoid.AutoRotate = false

	-- Each character keeps its own state, so an old character's loop finishing late
	-- can't disturb the new one.
	local x, y = spawnPoint()
	local s = Movement.new(MovementConfig, x, y)
	activeCharacter = character
	InputController.clearPresses()
	local accumulator = 0

	local connection: RBXScriptConnection
	connection = RunService.PreSimulation:Connect(function(dt)
		if activeCharacter ~= character or not character.Parent or humanoid.Health <= 0 then
			connection:Disconnect()
			if activeCharacter == character then
				activeCharacter = nil
				for _, callback in focusCallbacks do
					callback(nil)
				end
			end
			return
		end
		if stageDirty then
			stage = StageGeometry.read()
			stageDirty = false
		end

		accumulator += dt
		local steps = 0
		while accumulator >= FRAME and steps < Config.MaxStepsPerUpdate do
			s = Movement.step(s, InputController.read(), MovementConfig, stage)
			accumulator -= FRAME
			steps += 1
		end
		if steps == Config.MaxStepsPerUpdate then
			accumulator = 0
		end

		local spawnX, spawnY = spawnPoint()
		if s.Y < spawnY - Config.FallRespawnDepth then
			s = Movement.new(MovementConfig, spawnX, spawnY)
		end
		local position = Vector3.new(s.X, s.Y + rootOffset(humanoid, root), StageGeometry.PlaneZ)
		for _, callback in focusCallbacks do
			callback(position)
		end
		root.CFrame = CFrame.lookAt(position, position + Vector3.new(s.Facing, 0, 0))
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end)
end

-- Called every frame with the fighter's root position (for the camera), or nil once the
-- character is gone.
function LocalFighter.onFocusChanged(callback: (Vector3?) -> ())
	table.insert(focusCallbacks, callback)
end

function LocalFighter.start()
	StageGeometry.onChanged(function()
		stageDirty = true
	end)

	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

return LocalFighter
