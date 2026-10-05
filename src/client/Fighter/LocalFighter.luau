--!strict
--[[
	Runs the local fixed-step 60 Hz simulation: your fighter plus, for now, a training opponent
	(a bot that fights back, or a dummy that stands still; see Training/Config).
	Each frame it steps both with the pure Combat rules, resolves hits and blast-zone KOs,
	then draws the result: your character's root pinned to the 2.5D plane, the dummy, and
	the Feel effects (hitstop shake, sparks, sound, rumble, KO bursts, jump and land dust).

	The client owns its character's physics, so setting the root's CFrame here replicates
	to the server and other players. Hits are local only (training): fighting other players
	needs server checks, which come with netcode.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BotFolder = Shared:WaitForChild("Bot")
local Bot = require(BotFolder:WaitForChild("Bot"))
local BotConfig = require(BotFolder:WaitForChild("Config"))
local CombatFolder = Shared:WaitForChild("Combat")
local Combat = require(CombatFolder:WaitForChild("Combat"))
local CombatConfig = require(CombatFolder:WaitForChild("Config"))
local Fighter = require(CombatFolder:WaitForChild("Fighter"))
local TestMoveset = require(CombatFolder:WaitForChild("TestMoveset"))
local Movement = require(Shared:WaitForChild("Movement"):WaitForChild("Movement"))
local MovementConfig = require(Shared:WaitForChild("Movement"):WaitForChild("Config"))
local StageGeometry = require(Shared:WaitForChild("Stage"):WaitForChild("StageGeometry"))
local Feel = require("../Feel/Feel")
local PercentLabel = require("../Hud/PercentLabel")
local InputController = require("../Input/InputController")
local TrainingConfig = require("../Training/Config")
local TrainingDummy = require("../Training/TrainingDummy")
local Config = require("./Config")

local FRAME = 1 / 60
local PLAYER_ID = 1
local DUMMY_ID = 2

local LocalFighter = {}

local ctx: Fighter.Context = {
	Movement = MovementConfig,
	Combat = CombatConfig,
	Stage = { Solids = {}, Platforms = {} },
	Moveset = TestMoveset :: any, -- placeholder until the first fighter design exists
}
local stageDirty = true
local activeCharacter: Model? = nil
local focusCallbacks: { ({ Vector3 }) -> () } = {}

-- The dummy outlives your character, so it's kept here rather than per character.
local dummy: Fighter.State? = nil
local dummyView: TrainingDummy.View? = nil
local dummyBot: Bot.State = Bot.new(os.time())

local function spawnPoint(): (number, number)
	local x, y = StageGeometry.spawnPoint()
	if x and y then
		return x, y
	end
	return Config.FallbackSpawn.X, Config.FallbackSpawn.Y
end

local function newFighter(id: number): Fighter.State
	local x, y = spawnPoint()
	if id == DUMMY_ID then
		x += TrainingConfig.SpawnOffsetX
	end
	return Fighter.new(ctx, id, x, y)
end

local function world(x: number, y: number): Vector3
	return Vector3.new(x, y, StageGeometry.PlaneZ)
end

-- Height of the HumanoidRootPart's centre above the feet.
local function rootOffset(humanoid: Humanoid, root: BasePart): number
	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		return root.Size.Y / 2 + 2 -- R6 legs are 2 studs tall and HipHeight is 0
	end
	return humanoid.HipHeight + root.Size.Y / 2
end

local function isOut(f: Fighter.State, zone: Movement.Rect?): boolean
	if zone then
		return Combat.isOutside(f, zone)
	end
	-- No stage yet (or not streamed in): fall back to a fixed depth below the spawn.
	local _, spawnY = spawnPoint()
	return f.Body.Y < spawnY - Config.FallRespawnDepth
end

local function playKO(f: Fighter.State, zone: Movement.Rect?, isLocal: boolean)
	local body = f.Body
	local x, y = body.X, body.Y
	if zone then
		x = math.clamp(x, zone.MinX, zone.MaxX)
		y = math.clamp(y, zone.MinY, zone.MaxY)
	end
	local velocity = Vector3.new(body.VX, body.VY, 0)
	local direction = if velocity.Magnitude > 1e-3 then velocity.Unit else nil
	Feel.PlayBlastZoneExit(world(x, y), direction, isLocal)
	Feel.PlayKO({ position = world(x, y), direction = direction })
end

local function playMovementFeel(before: Movement.State, after: Movement.State)
	local wasAir, isAir = before.Mode == "Air", after.Mode == "Air"
	if before.Mode == "JumpSquat" and isAir then
		Feel.PlayMovement("Jump", world(after.X, after.Y))
	elseif wasAir and not isAir then
		Feel.PlayMovement("Land", world(after.X, after.Y))
	end
end

local function playHitFeel(hit: Combat.Hit, models: { [number]: Instance })
	Feel.PlayHit({
		position = world(hit.X, hit.Y),
		victim = models[hit.VictimId],
		damage = hit.Damage,
		direction = Vector3.new(hit.DirectionX, hit.DirectionY, 0),
		attackerIsLocal = hit.AttackerId == PLAYER_ID,
		victimIsLocal = hit.VictimId == PLAYER_ID,
		victimAirborne = true,
		playerCount = 2,
	})
end

local function onCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart

	-- Stop the Humanoid from walking, jumping or turning the character itself.
	humanoid.PlatformStand = true
	humanoid.AutoRotate = false

	-- Each character keeps its own state, so an old character's loop finishing late
	-- can't disturb the new one.
	activeCharacter = character
	local me = newFighter(PLAYER_ID)
	local myLabel = PercentLabel.create(root)
	InputController.clearPresses()
	local accumulator = 0

	if TrainingConfig.Enabled and not dummyView then
		dummy = newFighter(DUMMY_ID)
		dummyView = TrainingDummy.create(MovementConfig.BodyHalfWidth, MovementConfig.BodyHeight)
	end

	local function simulateFrame()
		if stageDirty then
			ctx.Stage = StageGeometry.read()
			stageDirty = false
		end

		local before = me.Body
		me = Fighter.step(me, InputController.read(), ctx)
		playMovementFeel(before, me.Body)

		local d = dummy
		if not d then
			return
		end
		local dummyIntent = Fighter.neutralIntent()
		if TrainingConfig.Opponent == "Bot" then
			dummyIntent, dummyBot = Bot.decide(dummyBot, d, me, ctx, BotConfig)
		end
		d = Fighter.step(d, dummyIntent, ctx)

		local fighters, hits = Combat.resolveHits({ me, d }, ctx)
		me, d = fighters[1], fighters[2]
		local models: { [number]: Instance } = { [PLAYER_ID] = character }
		local view = dummyView
		if view then
			models[DUMMY_ID] = view.Model
		end
		for _, hit in hits do
			playHitFeel(hit, models)
		end
		dummy = d
	end

	local connection: RBXScriptConnection
	connection = RunService.PreSimulation:Connect(function(dt: number)
		if activeCharacter ~= character or not character.Parent or humanoid.Health <= 0 then
			connection:Disconnect()
			if activeCharacter == character then
				activeCharacter = nil
				for _, callback in focusCallbacks do
					callback({})
				end
			end
			return
		end

		-- KO slow-mo scales simulation time.
		accumulator += dt * Feel.GetTimeScale()
		local steps = 0
		while accumulator >= FRAME and steps < Config.MaxStepsPerUpdate do
			simulateFrame()
			accumulator -= FRAME
			steps += 1
		end
		if steps == Config.MaxStepsPerUpdate then
			accumulator = 0
		end

		local zone = Combat.blastZone(ctx)
		if isOut(me, zone) then
			playKO(me, zone, true)
			me = newFighter(PLAYER_ID)
		end
		local d = dummy
		if d and isOut(d, zone) then
			playKO(d, zone, false)
			dummy = newFighter(DUMMY_ID)
			dummyBot = Bot.new(dummyBot.Seed)
		end

		-- Draw.
		local s = me.Body
		local position = world(s.X, s.Y + rootOffset(humanoid, root)) + Feel.GetVisualOffset(character)
		root.CFrame = CFrame.lookAt(position, position + Vector3.new(s.Facing, 0, 0))
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		PercentLabel.set(myLabel, me.Percent)

		local targets = { position }
		local view, current = dummyView, dummy
		if view and current then
			TrainingDummy.render(view, current, MovementConfig.BodyHeight, Feel.GetVisualOffset(view.Model))
			table.insert(targets, TrainingDummy.centre(current, MovementConfig.BodyHeight))
		end
		for _, callback in focusCallbacks do
			callback(targets)
		end
	end)
end

-- Called every frame with the positions the camera should frame (your fighter, the
-- dummy), or an empty list once your character is gone.
function LocalFighter.onFocusChanged(callback: ({ Vector3 }) -> ())
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
