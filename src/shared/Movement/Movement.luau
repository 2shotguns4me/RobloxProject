--!strict
--[[
	Pure 2D movement rules for one fighter: walking, running, jumps (full hop, short hop,
	double jump), gravity, fast-fall, landing lag and pass-through platforms.

	No Instances or services, so it runs in plain Luau for tests (see tests/). The client
	feeds it one Intent per 60 Hz frame and draws the result on the 2.5D plane.

	Coordinates: X runs along the stage, Y is up, and (X, Y) is the fighter's feet.
]]

local Movement = {}

export type Config = {
	BodyHalfWidth: number,
	BodyHeight: number,
	StickDeadzone: number,
	RunThreshold: number,
	DownThreshold: number,
	WalkSpeed: number,
	RunSpeed: number,
	GroundAccel: number,
	GroundFriction: number,
	JumpSquat: number,
	FullHopHeight: number,
	ShortHopHeight: number,
	DoubleJumpHeight: number,
	AirJumps: number,
	Gravity: number,
	MaxFallSpeed: number,
	FastFallSpeed: number,
	AirSpeed: number,
	AirAccel: number,
	AirFriction: number,
	LandingLag: number,
	JumpBuffer: number,
	DropThroughFrames: number,
}

-- What the player wants this frame, from any device.
export type Intent = {
	MoveX: number, -- -1 (left) to 1 (right)
	MoveY: number, -- -1 (down) to 1 (up)
	JumpHeld: boolean,
	JumpPressed: boolean, -- true only on the frame jump went down
}

export type Rect = {
	MinX: number,
	MaxX: number,
	MinY: number,
	MaxY: number,
}

export type Stage = {
	Solids: { Rect }, -- collide on every side
	Platforms: { Rect }, -- only the top collides, and only from above
}

export type Mode = "Ground" | "JumpSquat" | "Air" | "Landing"

export type State = {
	X: number,
	Y: number,
	VX: number,
	VY: number,
	Facing: number, -- 1 = right, -1 = left
	Mode: Mode,
	ModeFrame: number, -- frames spent in the current mode
	AirJumpsLeft: number,
	FastFalling: boolean,
	JumpBuffer: number, -- frames left on a buffered jump press
	ShortHop: boolean, -- jump was released during jump squat
	DropThrough: number, -- frames left ignoring pass-through platforms
	PrevMoveY: number,
	LandingLagFrames: number, -- length of the current landing; aerial attacks set their own
}

local EPSILON = 1e-4

function Movement.neutralIntent(): Intent
	return { MoveX = 0, MoveY = 0, JumpHeld = false, JumpPressed = false }
end

-- A fighter in the air at (x, y), about to fall and land.
function Movement.new(config: Config, x: number, y: number): State
	return {
		X = x,
		Y = y,
		VX = 0,
		VY = 0,
		Facing = 1,
		Mode = "Air",
		ModeFrame = 0,
		AirJumpsLeft = config.AirJumps,
		FastFalling = false,
		JumpBuffer = 0,
		ShortHop = false,
		DropThrough = 0,
		PrevMoveY = 0,
		LandingLagFrames = config.LandingLag,
	}
end

-- Sends the fighter flying (knockback): airborne with the given velocity, studs per frame.
function Movement.launch(state: State, vx: number, vy: number): State
	local s = table.clone(state)
	s.VX = vx
	s.VY = vy
	s.FastFalling = false
	s.Mode = "Air"
	s.ModeFrame = 0
	return s
end

-- Launch speed that peaks at `height` under the config's gravity.
function Movement.jumpVelocity(config: Config, height: number): number
	return math.sqrt(2 * config.Gravity * height)
end

local function approach(value: number, target: number, amount: number): number
	if value < target then
		return math.min(value + amount, target)
	end
	return math.max(value - amount, target)
end

local function setMode(s: State, mode: Mode)
	s.Mode = mode
	s.ModeFrame = 0
end

local function isUnder(s: State, config: Config, r: Rect): boolean
	return s.X + config.BodyHalfWidth > r.MinX and s.X - config.BodyHalfWidth < r.MaxX
end

-- The rect the fighter is standing on, if any. Pass-through platforms are skipped
-- while dropping through.
local function findSupport(s: State, config: Config, stage: Stage): (Rect?, boolean)
	for _, r in stage.Solids do
		if math.abs(s.Y - r.MaxY) < EPSILON and isUnder(s, config, r) then
			return r, false
		end
	end
	if s.DropThrough == 0 then
		for _, r in stage.Platforms do
			if math.abs(s.Y - r.MaxY) < EPSILON and isUnder(s, config, r) then
				return r, true
			end
		end
	end
	return nil, false
end

local function land(s: State, config: Config, top: number)
	s.Y = top
	s.VY = 0
	s.AirJumpsLeft = config.AirJumps
	s.FastFalling = false
	s.LandingLagFrames = config.LandingLag
	if config.LandingLag > 0 then
		setMode(s, "Landing")
	else
		setMode(s, "Ground")
	end
end

local function moveHorizontally(s: State, config: Config, stage: Stage)
	s.X += s.VX
	local minY = s.Y + EPSILON
	local maxY = s.Y + config.BodyHeight
	for _, r in stage.Solids do
		local overlaps = s.X + config.BodyHalfWidth > r.MinX
			and s.X - config.BodyHalfWidth < r.MaxX
			and minY < r.MaxY
			and maxY > r.MinY
		if overlaps then
			-- Push out to whichever side the body's centre is on.
			if s.X < (r.MinX + r.MaxX) / 2 then
				s.X = r.MinX - config.BodyHalfWidth
			else
				s.X = r.MaxX + config.BodyHalfWidth
			end
			s.VX = 0
		end
	end
end

local function moveVertically(s: State, config: Config, stage: Stage)
	local prevY = s.Y
	s.Y += s.VY

	if s.VY < 0 then
		local top: number? = nil
		local function consider(r: Rect)
			if prevY >= r.MaxY - EPSILON and s.Y <= r.MaxY and isUnder(s, config, r) then
				if top == nil or r.MaxY > top then
					top = r.MaxY
				end
			end
		end
		for _, r in stage.Solids do
			consider(r)
		end
		if s.DropThrough == 0 then
			for _, r in stage.Platforms do
				consider(r)
			end
		end
		if top then
			land(s, config, top)
		end
	elseif s.VY > 0 then
		for _, r in stage.Solids do
			local head = s.Y + config.BodyHeight
			if prevY + config.BodyHeight <= r.MinY + EPSILON and head > r.MinY and isUnder(s, config, r) then
				s.Y = r.MinY - config.BodyHeight
				s.VY = 0
			end
		end
	end
end

local function groundRun(s: State, intent: Intent, config: Config)
	local dir = intent.MoveX
	local amount = math.abs(dir)
	if amount < config.StickDeadzone then
		s.VX = approach(s.VX, 0, config.GroundFriction)
	else
		local speed = if amount >= config.RunThreshold then config.RunSpeed else config.WalkSpeed
		s.VX = approach(s.VX, math.sign(dir) * speed, config.GroundAccel)
		s.Facing = math.sign(dir)
	end
end

local function airDrift(s: State, intent: Intent, config: Config)
	if math.abs(intent.MoveX) < config.StickDeadzone then
		s.VX = approach(s.VX, 0, config.AirFriction)
	else
		s.VX = approach(s.VX, intent.MoveX * config.AirSpeed, config.AirAccel)
	end
end

-- Fast-fall needs a fresh press of down once the fighter is falling, as in Smash, so
-- holding down to drop through a platform doesn't fast-fall too.
local function fall(s: State, pressedDown: boolean, config: Config)
	if not s.FastFalling and s.VY <= 0 and pressedDown then
		s.FastFalling = true
	end
	if s.FastFalling then
		s.VY = -config.FastFallSpeed
	else
		s.VY = math.max(s.VY - config.Gravity, -config.MaxFallSpeed)
	end
end

-- Advance one 60 Hz frame. Returns a new State; the input State is not changed.
function Movement.step(state: State, intent: Intent, config: Config, stage: Stage): State
	local s = table.clone(state)
	s.ModeFrame += 1

	if intent.JumpPressed then
		s.JumpBuffer = config.JumpBuffer
	elseif s.JumpBuffer > 0 then
		s.JumpBuffer -= 1
	end
	local pressedDown = intent.MoveY <= -config.DownThreshold and s.PrevMoveY > -config.DownThreshold
	s.PrevMoveY = intent.MoveY
	if s.DropThrough > 0 then
		s.DropThrough -= 1
	end

	if s.Mode == "Ground" then
		local _, onPlatform = findSupport(s, config, stage)
		if s.JumpBuffer > 0 then
			s.JumpBuffer = 0
			s.ShortHop = false
			setMode(s, "JumpSquat")
		elseif pressedDown and onPlatform then
			s.DropThrough = config.DropThroughFrames
			pressedDown = false -- this press is the drop, not a fast-fall
			setMode(s, "Air")
		else
			groundRun(s, intent, config)
		end
	elseif s.Mode == "JumpSquat" then
		if not intent.JumpHeld then
			s.ShortHop = true
		end
		s.VX = approach(s.VX, 0, config.GroundFriction)
		if s.ModeFrame >= config.JumpSquat then
			local height = if s.ShortHop then config.ShortHopHeight else config.FullHopHeight
			s.VY = Movement.jumpVelocity(config, height)
			setMode(s, "Air")
		end
	elseif s.Mode == "Landing" then
		s.VX = approach(s.VX, 0, config.GroundFriction)
		if s.ModeFrame >= s.LandingLagFrames then
			setMode(s, "Ground")
		end
	end

	if s.Mode == "Air" then
		if s.JumpBuffer > 0 and s.AirJumpsLeft > 0 and s.ModeFrame > 1 then
			s.JumpBuffer = 0
			s.AirJumpsLeft -= 1
			s.FastFalling = false
			s.VY = Movement.jumpVelocity(config, config.DoubleJumpHeight)
			-- A double jump can change direction straight away, as in Smash.
			if math.abs(intent.MoveX) >= config.StickDeadzone then
				s.VX = intent.MoveX * config.AirSpeed
				s.Facing = math.sign(intent.MoveX)
			end
		else
			airDrift(s, intent, config)
			fall(s, pressedDown, config)
		end
	else
		s.VY = 0
	end

	moveHorizontally(s, config, stage)

	if s.Mode == "Air" then
		moveVertically(s, config, stage)
	else
		-- Walked, ran or slid off an edge (also during jump squat or landing lag).
		if findSupport(s, config, stage) == nil then
			setMode(s, "Air")
		end
	end

	return s
end

return Movement
