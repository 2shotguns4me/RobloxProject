--!strict
--[[
	Runs the local fixed-step 60 Hz simulation and draws it.

	Each frame:
	- applies hits and KOs the server confirmed (NetClient), so other players can damage you;
	- steps your fighter from your input;
	- when you're alone in the server, steps the training opponent (a bot or a still dummy;
	  see Training/Config);
	- resolves hits against the opponent and against "ghosts" of the other players (where they
	  were a moment ago). Hits on other players show straight away and are sent to the server
	  as claims; the server decides the damage, and your % follows the server's;
	- sends your state to the server (every other frame, every frame while attacking), and
	  handles blast-zone KOs.

	Then it pins your character's root to the 2.5D plane (the client owns its character's
	physics, so this replicates to everyone), draws other players' characters exactly where
	their ghosts are (so what you see is what you hit), and plays the Feel effects.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

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
local NetConfig = require(Shared:WaitForChild("Net"):WaitForChild("Config"))
local StageGeometry = require(Shared:WaitForChild("Stage"):WaitForChild("StageGeometry"))
local Feel = require("../Feel/Feel")
local PercentLabel = require("../Hud/PercentLabel")
local InputController = require("../Input/InputController")
local NetClient = require("../Net/NetClient")
local TrainingConfig = require("../Training/Config")
local TrainingDummy = require("../Training/TrainingDummy")
local Config = require("./Config")

local FRAME = 1 / 60
-- Local ids for your fighter and the training opponent. Other players use their UserId;
-- these are chosen so they never clash with one (Studio test players are -1, -2, ...).
local PLAYER_ID = -1000001
local DUMMY_ID = -1000002

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

-- The training opponent outlives your character, so it's kept here rather than per character.
local dummy: Fighter.State? = nil
local dummyView: TrainingDummy.View? = nil
local dummyBot: Bot.State = Bot.new(os.time())

-- Damage % labels over other players' characters.
local remoteLabels: { [number]: { Root: BasePart, Label: TextLabel } } = {}

-- Attacks you've started, kept across respawns so attack serials only ever go up (the server
-- uses them to tell one attack from the next).
local attackCount = 0
-- The latest ghosts of other players, for drawing their characters.
local latestGhosts: { Fighter.State } = {}

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
	local f = Fighter.new(ctx, id, x, y)
	if id == PLAYER_ID then
		f.AttackCount = attackCount
	end
	return f
end

local function world(x: number, y: number): Vector3
	return Vector3.new(x, y, StageGeometry.PlaneZ)
end

local function centre(f: Fighter.State): Vector3
	return world(f.Body.X, f.Body.Y + MovementConfig.BodyHeight / 2)
end

local function isAlone(): boolean
	return #Players:GetPlayers() <= 1
end

local function characterOf(userId: number): Model?
	local player = Players:GetPlayerByUserId(userId)
	return if player then player.Character else nil
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

local function playHitFeel(
	position: Vector3,
	damage: number,
	dirX: number,
	dirY: number,
	victim: Instance?,
	attackerIsLocal: boolean,
	victimIsLocal: boolean
)
	Feel.PlayHit({
		position = position,
		victim = victim,
		damage = damage,
		direction = Vector3.new(dirX, dirY, 0),
		attackerIsLocal = attackerIsLocal,
		victimIsLocal = victimIsLocal,
		victimAirborne = true,
		playerCount = math.max(#Players:GetPlayers(), 2),
	})
end

local function updateRemoteLabels(ghosts: { Fighter.State })
	local seen = {}
	for _, ghost in ghosts do
		local character = characterOf(ghost.Id)
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") then
			local existing = remoteLabels[ghost.Id]
			local label: TextLabel
			if existing and existing.Root == root then
				label = existing.Label
			else
				label = PercentLabel.create(root)
				remoteLabels[ghost.Id] = { Root = root, Label = label }
			end
			PercentLabel.set(label, ghost.Percent)
			seen[ghost.Id] = true
		end
	end
	for id, entry in remoteLabels do
		if not seen[id] then
			local gui = entry.Label.Parent
			if gui then
				gui:Destroy()
			end
			remoteLabels[id] = nil
		end
	end
end

-- Draws other players' characters where their ghosts are, every render frame, over Roblox's
-- own replication of them, so the model you see is the one your hits are tested against.
local function drawRemoteCharacters()
	for _, ghost in latestGhosts do
		local character = characterOf(ghost.Id)
		if not character then
			continue
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")
		if humanoid and root and root:IsA("BasePart") then
			local body = ghost.Body
			local position = world(body.X, body.Y + rootOffset(humanoid, root)) + Feel.GetVisualOffset(character)
			root.CFrame = CFrame.lookAt(position, position + Vector3.new(body.Facing, 0, 0))
		end
	end
end

local function onCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	local myUserId = Players.LocalPlayer.UserId

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
	local frameCount = 0
	local wasAlone = isAlone()

	if TrainingConfig.Enabled and not dummyView then
		dummy = newFighter(DUMMY_ID)
		dummyView = TrainingDummy.create(MovementConfig.BodyHalfWidth, MovementConfig.BodyHeight)
	end

	local function applyServerEvents()
		for _, hit in NetClient.takeHits() do
			local r = hit.Result
			local position = world(hit.X, hit.Y)
			if hit.VictimId == myUserId then
				me = Combat.applyHit(me, r)
				playHitFeel(position, r.Damage, r.DirectionX, r.DirectionY, character, false, true)
			elseif hit.AttackerId ~= myUserId then
				-- Someone else's hit: effects only. (Your own hits already played when you landed them.)
				playHitFeel(position, r.Damage, r.DirectionX, r.DirectionY, characterOf(hit.VictimId), false, false)
			end
		end
		for _, ko in NetClient.takeKOs() do
			if ko.UserId ~= myUserId then
				Feel.PlayBlastZoneExit(world(ko.X, ko.Y), nil, false)
			end
		end
	end

	local function simulateFrame()
		if stageDirty then
			ctx.Stage = StageGeometry.read()
			stageDirty = false
		end
		applyServerEvents()

		local before = me.Body
		me = Fighter.step(me, InputController.read(), ctx)
		attackCount = me.AttackCount
		playMovementFeel(before, me.Body)

		-- The training opponent only plays when you're alone; with others, they're the fight
		-- and the server owns your % (training damage doesn't carry over).
		local alone = isAlone()
		wasAlone = alone
		if not alone then
			me.Percent = NetClient.serverPercent()
		end
		local d = if alone then dummy else nil
		if d then
			local dummyIntent = Fighter.neutralIntent()
			if TrainingConfig.Opponent == "Bot" then
				dummyIntent, dummyBot = Bot.decide(dummyBot, d, me, ctx, BotConfig)
			end
			d = Fighter.step(d, dummyIntent, ctx)
		end

		local ghosts, ghostTimes = NetClient.ghosts(ctx)
		latestGhosts = ghosts
		local fighters = { me }
		if d then
			table.insert(fighters, d)
		end
		for _, ghost in ghosts do
			table.insert(fighters, ghost)
		end

		local myAttack = me.Attack
		local list, hits = Combat.resolveHits(fighters, ctx)
		me = list[1]
		if d then
			dummy = list[2]
		end

		local dummyModel = if dummyView then dummyView.Model else nil
		for _, hit in hits do
			local position = world(hit.X, hit.Y)
			if hit.VictimId == DUMMY_ID or (hit.AttackerId == DUMMY_ID and hit.VictimId == PLAYER_ID) then
				-- Training hits are local only.
				local victim = if hit.VictimId == DUMMY_ID then dummyModel else character
				local fromMe = hit.AttackerId == PLAYER_ID
				playHitFeel(position, hit.Damage, hit.DirectionX, hit.DirectionY, victim, fromMe, not fromMe)
			elseif hit.AttackerId == PLAYER_ID and myAttack then
				-- You hit another player: show it now, let the server decide the damage. Send
				-- the state first, so the server has this attack on record before the claim.
				NetClient.sendState(me)
				NetClient.sendHitClaim({
					VictimId = hit.VictimId,
					Move = hit.Move,
					Serial = myAttack.Serial,
					Frame = myAttack.Frame,
					T = NetClient.now(),
					VictimT = ghostTimes[hit.VictimId] or NetClient.now(),
				})
				playHitFeel(
					position,
					hit.Damage,
					hit.DirectionX,
					hit.DirectionY,
					characterOf(hit.VictimId),
					true,
					false
				)
			end
		end

		frameCount += 1
		if me.Attack or frameCount % NetConfig.SendEveryFrames == 0 then
			NetClient.sendState(me)
		end
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
			NetClient.sendKO()
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
			local showDummy = wasAlone
			view.Model.Parent = if showDummy then Workspace else nil
			if showDummy then
				TrainingDummy.render(view, current, MovementConfig.BodyHeight, Feel.GetVisualOffset(view.Model))
				table.insert(targets, centre(current))
			end
		end
		for _, ghost in latestGhosts do
			table.insert(targets, centre(ghost))
		end
		updateRemoteLabels(latestGhosts)
		for _, callback in focusCallbacks do
			callback(targets)
		end
	end)
end

-- Called every frame with the positions the camera should frame (you, the training opponent
-- or other players), or an empty list once your character is gone.
function LocalFighter.onFocusChanged(callback: ({ Vector3 }) -> ())
	table.insert(focusCallbacks, callback)
end

function LocalFighter.start()
	StageGeometry.onChanged(function()
		stageDirty = true
	end)
	NetClient.start()
	RunService.PreRender:Connect(drawRemoteCharacters)

	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

return LocalFighter
