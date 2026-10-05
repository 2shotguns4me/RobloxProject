--!strict
--[[
	One fighter in the fixed-step simulation: movement plus attacks, damage %, hitstun and
	hitstop. Pure; Combat.resolveHits applies hits between fighters each frame.

	Each 60 Hz frame:
	- Hitstop freezes the fighter completely (presses are still buffered).
	- Hitstun takes away control; the fighter flies with its launch velocity.
	- Otherwise a buffered attack starts if the fighter can act, else it moves normally.

	Attacks on the ground: Attack = Jab, or SideTilt when holding left/right; Smash = SideSmash.
	In the air either button gives NeutralAir. Landing during an aerial cancels it into that
	move's landing lag.
]]

local Movement = require("../Movement/Movement")

local Fighter = {}

export type Hitbox = {
	Attachment: string?,
	Offset: Vector3, -- relative to the fighter's centre: X forward, Y up
	Size: Vector3,
}

export type Move = {
	Animation: string?,
	Damage: number,
	BaseKnockback: number,
	KnockbackGrowth: number,
	Angle: number, -- degrees, 0 = forward, 90 = up
	Startup: number, -- frames before the hitbox comes out
	Active: number, -- frames the hitbox is out
	Endlag: number, -- frames after
	LandingLag: number?, -- aerials only
	Hitbox: Hitbox,
}

export type Moveset = { [string]: Move }

export type CombatConfig = {
	KnockbackMultiplier: number,
	KnockbackFlat: number,
	DefaultWeight: number,
	LaunchSpeedPerKnockback: number,
	HitstunPerKnockback: number,
	LaunchDecay: number,
	AttackBuffer: number,
	DefaultAerialLandingLag: number,
	BlastZone: { Side: number, Top: number, Bottom: number },
}

-- Everything a step needs that isn't the fighter itself.
export type Context = {
	Movement: Movement.Config,
	Combat: CombatConfig,
	Stage: Movement.Stage,
	Moveset: Moveset,
}

export type Intent = {
	MoveX: number,
	MoveY: number,
	JumpHeld: boolean,
	JumpPressed: boolean,
	AttackPressed: boolean,
	SmashPressed: boolean,
	SmashX: number, -- -1, 0 or 1: which way the smash was aimed (0 = facing)
}

export type Attack = {
	Name: string,
	Serial: number, -- counts up with every attack this fighter starts; identifies it online
	Frame: number, -- 1 on the first frame of the move
	Hit: { [number]: boolean }, -- fighter ids this attack has already hit
}

export type State = {
	Id: number,
	Body: Movement.State,
	Percent: number,
	Weight: number,
	Attack: Attack?,
	Hitstun: number, -- frames left without control
	Hitstop: number, -- frames left frozen
	AttackBuffer: number, -- frames left on a buffered attack press
	BufferedSmash: boolean,
	BufferedSmashX: number,
	AttackCount: number, -- attacks started so far (the next attack's Serial is this + 1)
}

local AERIALS = { NeutralAir = true }

function Fighter.neutralIntent(): Intent
	return {
		MoveX = 0,
		MoveY = 0,
		JumpHeld = false,
		JumpPressed = false,
		AttackPressed = false,
		SmashPressed = false,
		SmashX = 0,
	}
end

function Fighter.new(ctx: Context, id: number, x: number, y: number, weight: number?): State
	return {
		Id = id,
		Body = Movement.new(ctx.Movement, x, y),
		Percent = 0,
		Weight = weight or ctx.Combat.DefaultWeight,
		Attack = nil,
		Hitstun = 0,
		Hitstop = 0,
		AttackBuffer = 0,
		BufferedSmash = false,
		BufferedSmashX = 0,
		AttackCount = 0,
	}
end

function Fighter.totalFrames(move: Move): number
	return move.Startup + move.Active + move.Endlag
end

-- The fighter's body in world space.
function Fighter.hurtbox(f: State, ctx: Context): Movement.Rect
	local body = f.Body
	local halfWidth = ctx.Movement.BodyHalfWidth
	return {
		MinX = body.X - halfWidth,
		MaxX = body.X + halfWidth,
		MinY = body.Y,
		MaxY = body.Y + ctx.Movement.BodyHeight,
	}
end

-- The attack's hitbox in world space while it's active, else nil.
function Fighter.activeHitbox(f: State, ctx: Context): (Movement.Rect?, Move?)
	local attack = f.Attack
	if not attack or f.Hitstun > 0 then
		return nil, nil
	end
	local move = ctx.Moveset[attack.Name]
	if attack.Frame <= move.Startup or attack.Frame > move.Startup + move.Active then
		return nil, nil
	end
	local body = f.Body
	local centreX = body.X + move.Hitbox.Offset.X * body.Facing
	local centreY = body.Y + ctx.Movement.BodyHeight / 2 + move.Hitbox.Offset.Y
	local halfX, halfY = move.Hitbox.Size.X / 2, move.Hitbox.Size.Y / 2
	return { MinX = centreX - halfX, MaxX = centreX + halfX, MinY = centreY - halfY, MaxY = centreY + halfY }, move
end

local function neutralMovement(): Movement.Intent
	return Movement.neutralIntent()
end

-- Picks the move a buffered press turns into, or nil if the fighter can't attack right now.
local function chooseMove(f: State, intent: Intent, ctx: Context): (string?, number?)
	local mode = f.Body.Mode
	if mode == "Ground" then
		if f.BufferedSmash then
			return "SideSmash", if f.BufferedSmashX ~= 0 then f.BufferedSmashX else nil
		elseif math.abs(intent.MoveX) >= ctx.Movement.StickDeadzone then
			return "SideTilt", math.sign(intent.MoveX)
		end
		return "Jab", nil
	elseif mode == "Air" then
		return "NeutralAir", nil
	end
	return nil, nil
end

-- Advance one 60 Hz frame. Returns a new State; the input State is not changed.
function Fighter.step(state: State, intent: Intent, ctx: Context): State
	local f = table.clone(state)

	local pressed = intent.AttackPressed or intent.SmashPressed
	if pressed then
		f.AttackBuffer = ctx.Combat.AttackBuffer
		f.BufferedSmash = intent.SmashPressed
		f.BufferedSmashX = intent.SmashX
	end

	if f.Hitstop > 0 then
		f.Hitstop -= 1
		return f
	end
	if not pressed and f.AttackBuffer > 0 then
		f.AttackBuffer -= 1
	end

	if f.Hitstun > 0 then
		f.Hitstun -= 1
		-- Knockback decay: horizontal launch speed bleeds off at a fixed rate, as in Smash.
		-- Gravity already does this vertically.
		local body = table.clone(f.Body)
		local decay = ctx.Combat.LaunchDecay
		body.VX = if body.VX > 0 then math.max(body.VX - decay, 0) else math.min(body.VX + decay, 0)
		f.Body = Movement.step(body, neutralMovement(), ctx.Movement, ctx.Stage)
		return f
	end

	if not f.Attack and f.AttackBuffer > 0 then
		local name, facing = chooseMove(f, intent, ctx)
		if name then
			f.AttackBuffer = 0
			f.AttackCount += 1
			f.Attack = { Name = name, Serial = f.AttackCount, Frame = 0, Hit = {} }
			if facing then
				local body = table.clone(f.Body)
				body.Facing = facing
				f.Body = body
			end
		end
	end

	local attack = f.Attack
	if not attack then
		f.Body = Movement.step(f.Body, intent, ctx.Movement, ctx.Stage)
		return f
	end

	local move = ctx.Moveset[attack.Name]
	local aerial = AERIALS[attack.Name] == true
	local nextAttack = table.clone(attack)
	nextAttack.Frame += 1
	f.Attack = nextAttack

	-- Ground attacks root the fighter; aerials keep drift and fast-fall but no jumps.
	local moveIntent = neutralMovement()
	if aerial then
		moveIntent.MoveX = intent.MoveX
		moveIntent.MoveY = intent.MoveY
	end
	local facing = f.Body.Facing
	f.Body = Movement.step(f.Body, moveIntent, ctx.Movement, ctx.Stage)
	f.Body.Facing = facing -- attacks never turn the fighter around

	if aerial and f.Body.Mode ~= "Air" then
		-- Landed mid-aerial: cancel into the move's landing lag.
		local body = table.clone(f.Body)
		body.Mode = "Landing"
		body.ModeFrame = 0
		body.LandingLagFrames = move.LandingLag or ctx.Combat.DefaultAerialLandingLag
		f.Body = body
		f.Attack = nil
	else
		-- Over, or a ground attack that slid off an edge.
		local slidOff = not aerial and f.Body.Mode == "Air"
		if slidOff or nextAttack.Frame >= Fighter.totalFrames(move) then
			f.Attack = nil
		end
	end
	return f
end

return Fighter
