--!strict
-- Unit tests for src/shared/Movement. Run with: luau tests/run.luau

local Movement = require("../src/shared/Movement/Movement")
local Config = require("../src/shared/Movement/Config")

type State = Movement.State
type Intent = Movement.Intent

local config: Movement.Config = Config

-- Floor 200 studs wide with its top at y = 0, plus a pass-through platform at y = 20.
local stage: Movement.Stage = {
	Solids = { { MinX = -100, MaxX = 100, MinY = -10, MaxY = 0 } },
	Platforms = { { MinX = -10, MaxX = 10, MinY = 19, MaxY = 20 } },
}

local function intent(fields: { [string]: any }?): Intent
	local i = Movement.neutralIntent()
	if fields then
		for k, v in fields do
			(i :: any)[k] = v
		end
	end
	return i
end

local function run(s: State, frames: number, i: Intent?): State
	for _ = 1, frames do
		s = Movement.step(s, i or intent(), config, stage)
	end
	return s
end

local function grounded(x: number?): State
	local s = run(Movement.new(config, x or 0, 1), 120)
	assert(s.Mode == "Ground", "expected to settle on the ground, got " .. s.Mode)
	return s
end

-- Press jump for one frame, keep holding for `holdFrames` total, then let go.
local function jump(s: State, holdFrames: number): State
	s = Movement.step(s, intent({ JumpPressed = true, JumpHeld = true }), config, stage)
	for _ = 2, holdFrames do
		s = Movement.step(s, intent({ JumpHeld = true }), config, stage)
	end
	return s
end

local function apexOf(s: State): number
	local best = s.Y
	for _ = 1, 200 do
		s = Movement.step(s, intent(), config, stage)
		best = math.max(best, s.Y)
		if s.Mode == "Landing" then
			break
		end
	end
	return best
end

local function near(a: number, b: number, tolerance: number): boolean
	return math.abs(a - b) <= tolerance
end

local tests: { [string]: () -> () } = {}

tests["falls and lands on the floor"] = function()
	local s = grounded()
	assert(s.Y == 0, "feet should rest on the floor top")
	assert(s.VY == 0)
	assert(s.AirJumpsLeft == config.AirJumps)
end

tests["runs right at run speed and faces right"] = function()
	local s = run(grounded(), 60, intent({ MoveX = 1 }))
	assert(near(s.VX, config.RunSpeed, 1e-9), "VX = " .. s.VX)
	assert(s.Facing == 1)
end

tests["walks when the stick is only partly tilted"] = function()
	local s = run(grounded(), 60, intent({ MoveX = -0.5 }))
	assert(near(s.VX, -config.WalkSpeed, 1e-9), "VX = " .. s.VX)
	assert(s.Facing == -1)
end

tests["friction stops the fighter when the stick is let go"] = function()
	local s = run(grounded(), 60, intent({ MoveX = 1 }))
	s = run(s, 60)
	assert(s.VX == 0)
end

tests["jump squat lasts JumpSquat frames before leaving the ground"] = function()
	local s = jump(grounded(), config.JumpSquat)
	assert(s.Mode == "JumpSquat", "should still be in jump squat, got " .. s.Mode)
	s = Movement.step(s, intent({ JumpHeld = true }), config, stage)
	assert(s.Mode == "Air", "should be airborne after jump squat, got " .. s.Mode)
end

tests["holding jump gives a full hop of about FullHopHeight"] = function()
	local s = jump(grounded(), config.JumpSquat + 1)
	local apex = apexOf(s)
	assert(near(apex, config.FullHopHeight, 0.6), "apex = " .. apex)
end

tests["tapping jump gives a short hop of about ShortHopHeight"] = function()
	local s = jump(grounded(), 1)
	local apex = apexOf(s)
	assert(near(apex, config.ShortHopHeight, 0.6), "apex = " .. apex)
end

tests["double jump works once, then air jumps run out"] = function()
	local s = jump(grounded(), config.JumpSquat + 1)
	s = run(s, 10)
	s = Movement.step(s, intent({ JumpPressed = true, JumpHeld = true }), config, stage)
	assert(s.AirJumpsLeft == 0)
	assert(near(s.VY, Movement.jumpVelocity(config, config.DoubleJumpHeight), 1e-9))
	s = run(s, 5)
	local before = s.VY
	s = Movement.step(s, intent({ JumpPressed = true, JumpHeld = true }), config, stage)
	assert(s.VY < before, "a second air jump should not happen")
end

tests["landing restores air jumps after landing lag"] = function()
	local s = jump(grounded(), config.JumpSquat + 1)
	s = run(s, 10)
	s = Movement.step(s, intent({ JumpPressed = true }), config, stage)
	s = run(s, 200)
	assert(s.Mode == "Ground")
	assert(s.AirJumpsLeft == config.AirJumps)
end

tests["landing lag lasts LandingLag frames"] = function()
	local s = Movement.new(config, 0, 0.5)
	local frames = 0
	while s.Mode ~= "Landing" do
		s = Movement.step(s, intent(), config, stage)
	end
	while s.Mode == "Landing" do
		s = Movement.step(s, intent(), config, stage)
		frames += 1
	end
	assert(frames == config.LandingLag, "landing lag was " .. frames)
end

tests["a jump pressed during landing lag is buffered"] = function()
	local s = Movement.new(config, 0, 0.5)
	while s.Mode ~= "Landing" do
		s = Movement.step(s, intent(), config, stage)
	end
	s = Movement.step(s, intent({ JumpPressed = true, JumpHeld = true }), config, stage)
	s = run(s, config.LandingLag + 1, intent({ JumpHeld = true }))
	assert(s.Mode == "JumpSquat", "buffered jump should start jump squat, got " .. s.Mode)
end

tests["a jump pressed too early is dropped"] = function()
	local s = Movement.new(config, 0, 30)
	s.AirJumpsLeft = 0
	s = Movement.step(s, intent({ JumpPressed = true }), config, stage)
	s = run(s, 200)
	assert(s.Mode == "Ground")
end

tests["fast-fall needs a down press after the apex"] = function()
	local s = Movement.new(config, 50, 30)
	s = Movement.step(s, intent({ MoveY = -1 }), config, stage)
	assert(s.FastFalling)
	assert(s.VY == -config.FastFallSpeed)
end

tests["falling speed is capped at MaxFallSpeed"] = function()
	local s = run(Movement.new(config, 50, 500), 100)
	assert(s.VY == -config.MaxFallSpeed, "VY = " .. s.VY)
end

tests["lands on a pass-through platform from above"] = function()
	local s = run(Movement.new(config, 0, 25), 60)
	assert(s.Mode == "Ground" and s.Y == 20, "Y = " .. s.Y)
end

tests["jumps up through a pass-through platform"] = function()
	local s = Movement.new(config, 0, 15)
	s.VY = 1.5
	s = run(s, 3)
	assert(s.Y > 15 + 3, "should pass through from below, Y = " .. s.Y)
end

tests["pressing down drops through a pass-through platform"] = function()
	local s = run(Movement.new(config, 0, 25), 60)
	s = Movement.step(s, intent({ MoveY = -1 }), config, stage)
	assert(s.Mode == "Air")
	s = run(s, 120, intent({ MoveY = -1 }))
	assert(s.Mode == "Ground" and s.Y == 0, "should land on the floor, Y = " .. s.Y)
end

tests["pressing down on solid ground does nothing"] = function()
	local s = Movement.step(grounded(50), intent({ MoveY = -1 }), config, stage)
	assert(s.Mode == "Ground" and s.Y == 0)
end

tests["running off the edge starts falling with air jumps intact"] = function()
	local s = run(grounded(95), 30, intent({ MoveX = 1 }))
	assert(s.Mode == "Air")
	assert(s.AirJumpsLeft == config.AirJumps)
end

tests["walls stop horizontal movement"] = function()
	local wallStage: Movement.Stage = {
		Solids = {
			{ MinX = -100, MaxX = 100, MinY = -10, MaxY = 0 },
			{ MinX = 10, MaxX = 20, MinY = 0, MaxY = 30 },
		},
		Platforms = {},
	}
	local s = Movement.new(config, 0, 0)
	for _ = 1, 120 do
		s = Movement.step(s, intent({ MoveX = 1 }), config, wallStage)
	end
	assert(near(s.X, 10 - config.BodyHalfWidth, 1e-9), "X = " .. s.X)
	assert(s.VX == 0)
end

tests["ceilings stop upward movement"] = function()
	local roofStage: Movement.Stage = {
		Solids = {
			{ MinX = -100, MaxX = 100, MinY = -10, MaxY = 0 },
			{ MinX = -100, MaxX = 100, MinY = 8, MaxY = 10 },
		},
		Platforms = {},
	}
	local s = Movement.new(config, 0, 0)
	for _ = 1, 30 do
		s = Movement.step(s, intent(), config, roofStage)
	end
	s = Movement.step(s, intent({ JumpPressed = true, JumpHeld = true }), config, roofStage)
	local highest = 0
	for _ = 1, 60 do
		s = Movement.step(s, intent({ JumpHeld = true }), config, roofStage)
		highest = math.max(highest, s.Y + config.BodyHeight)
	end
	assert(highest <= 8 + 1e-9, "head went through the ceiling: " .. highest)
end

tests["step does not change the state passed in"] = function()
	local s = grounded()
	local x = s.X
	Movement.step(s, intent({ MoveX = 1 }), config, stage)
	assert(s.X == x and s.VX == 0)
end

return tests
