--!strict
--[[
	Bot opponent: decides one Fighter.Intent per 60 Hz frame from what it can see, exactly
	like a controller would. Pure and deterministic (its own seeded random numbers), so
	tests replay the same way every time.

		local bot = Bot.new(seed)
		local intent
		intent, bot = Bot.decide(bot, me, target, ctx, BotConfig)
		me = Fighter.step(me, intent, ctx)

	Priorities each frame:
	1. In hitstun or hitstop: nothing (it can't act anyway).
	2. Off the stage: steer back and double-jump to recover.
	3. Otherwise follow its current plan, rethinking every so often (its reaction time):
	   attack if in range (jab, tilt, or a smash once the target is damaged), jump into a
	   neutral air if the target is above, or walk towards the target, but never off the edge.
]]

local Fighter = require("../Combat/Fighter")
local Movement = require("../Movement/Movement")

local Bot = {}

export type Config = {
	MinDecisionFrames: number,
	MaxDecisionFrames: number,
	AttackRangeX: number,
	AttackRangeY: number,
	SmashPercent: number,
	SmashChance: number,
	TiltChance: number,
	AerialChance: number,
	AerialDelayFrames: number,
	IdleChance: number,
	EdgeMargin: number,
	FullHopHoldFrames: number,
}

export type State = {
	Seed: number, -- random number generator state
	Wait: number, -- frames until it rethinks
	MoveX: number, -- planned walking direction
	PendingAttack: "Jab" | "Tilt" | "Smash" | nil,
	AttackX: number, -- direction for a tilt or smash
	PendingJump: boolean,
	AerialIn: number, -- frames until a planned aerial; 0 = none
	JumpHold: number, -- frames left holding jump
}

-- Park-Miller generator: small enough multiplier to stay exact in doubles.
local MODULUS = 2147483647
local MULTIPLIER = 16807

local function nextRandom(b: State): number
	b.Seed = (b.Seed * MULTIPLIER) % MODULUS
	return b.Seed / MODULUS
end

function Bot.new(seed: number?): State
	local s = math.floor(seed or 1) % MODULUS
	return {
		Seed = if s <= 0 then 1 else s,
		Wait = 0,
		MoveX = 0,
		PendingAttack = nil,
		AttackX = 0,
		PendingJump = false,
		AerialIn = 0,
		JumpHold = 0,
	}
end

-- The widest solid is "the stage" for recovery and edge checks.
local function mainStage(stage: Movement.Stage): Movement.Rect?
	local best: Movement.Rect? = nil
	for _, r in stage.Solids do
		if not best or (r.MaxX - r.MinX) > (best.MaxX - best.MinX) then
			best = r
		end
	end
	return best
end

local function isOffstage(body: Movement.State, stage: Movement.Rect): boolean
	return body.X < stage.MinX or body.X > stage.MaxX or body.Y < stage.MaxY - 0.5
end

local function sign(x: number): number
	return if x > 0 then 1 elseif x < 0 then -1 else 0
end

local function plan(b: State, me: Fighter.State, target: Fighter.State, stage: Movement.Rect?, cfg: Config)
	local roll = nextRandom(b)
	b.Wait = cfg.MinDecisionFrames + math.floor(roll * (cfg.MaxDecisionFrames - cfg.MinDecisionFrames + 1))
	b.MoveX = 0

	local dx = target.Body.X - me.Body.X
	local dy = target.Body.Y - me.Body.Y
	local towards = sign(dx)

	if nextRandom(b) < cfg.IdleChance then
		return
	end

	local inRange = math.abs(dx) <= cfg.AttackRangeX
	local grounded = me.Body.Mode == "Ground"
	if inRange and math.abs(dy) <= cfg.AttackRangeY and grounded then
		local r = nextRandom(b)
		local behind = towards ~= 0 and towards ~= me.Body.Facing
		if target.Percent >= cfg.SmashPercent and r < cfg.SmashChance then
			b.PendingAttack = "Smash"
		elseif behind or r < cfg.TiltChance then
			b.PendingAttack = "Tilt" -- a tilt also turns around to face a target behind
		else
			b.PendingAttack = "Jab"
		end
		b.AttackX = if towards ~= 0 then towards else me.Body.Facing
		return
	end

	if inRange and dy > cfg.AttackRangeY and grounded and nextRandom(b) < cfg.AerialChance then
		b.PendingJump = true
		b.AerialIn = cfg.AerialDelayFrames
		b.MoveX = towards
		return
	end

	-- Walk towards the target, unless it's off the stage: wait at the edge instead.
	if stage and isOffstage(target.Body, stage) then
		b.MoveX = 0
	else
		b.MoveX = towards
	end
end

-- One frame of decisions. Returns the intent and the bot's new state; the input state is
-- not changed.
function Bot.decide(
	bot: State,
	me: Fighter.State,
	target: Fighter.State,
	ctx: Fighter.Context,
	cfg: Config
): (Fighter.Intent, State)
	local b = table.clone(bot)
	local intent = Fighter.neutralIntent()

	if b.JumpHold > 0 then
		b.JumpHold -= 1
		intent.JumpHeld = true
	end

	if me.Hitstun > 0 or me.Hitstop > 0 then
		-- Any plan is stale once it's been hit.
		b.PendingAttack = nil
		b.PendingJump = false
		b.AerialIn = 0
		b.Wait = 0
		return intent, b
	end

	local body = me.Body
	local stage = mainStage(ctx.Stage)

	-- Recovery: head back to the stage and double-jump once falling below its top.
	if stage and isOffstage(body, stage) then
		local centre = (stage.MinX + stage.MaxX) / 2
		intent.MoveX = sign(centre - body.X)
		local belowTop = body.Y < stage.MaxY
		if body.Mode == "Air" and body.VY <= 0 and belowTop and body.AirJumpsLeft > 0 then
			intent.JumpPressed = true
			intent.JumpHeld = true
			b.JumpHold = cfg.FullHopHoldFrames
		end
		b.Wait = 0
		return intent, b
	end

	b.Wait -= 1
	if b.Wait <= 0 and not b.PendingAttack and not b.PendingJump and b.AerialIn == 0 then
		plan(b, me, target, stage, cfg)
	end

	-- Never walk off the edge on purpose.
	local moveX = b.MoveX
	if stage and moveX ~= 0 and body.Mode == "Ground" then
		local toEdge = if moveX > 0 then stage.MaxX - body.X else body.X - stage.MinX
		if toEdge < cfg.EdgeMargin then
			moveX = 0
		end
	end
	intent.MoveX = moveX

	if b.PendingJump then
		b.PendingJump = false
		intent.JumpPressed = true
		intent.JumpHeld = true
		b.JumpHold = cfg.FullHopHoldFrames
	elseif b.AerialIn > 0 then
		b.AerialIn -= 1
		if b.AerialIn == 0 then
			intent.AttackPressed = true
		end
	elseif b.PendingAttack then
		local attack = b.PendingAttack
		b.PendingAttack = nil
		if attack == "Smash" then
			intent.SmashPressed = true
			intent.SmashX = b.AttackX
		elseif attack == "Tilt" then
			intent.AttackPressed = true
			intent.MoveX = b.AttackX
		else
			intent.AttackPressed = true
			intent.MoveX = 0
		end
	end

	return intent, b
end

return Bot
