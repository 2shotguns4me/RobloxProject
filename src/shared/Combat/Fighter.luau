--!strict
--[[
	One fighter in the fixed-step simulation: movement plus attacks, defense, damage %, hitstun
	and hitstop. Pure; Combat.resolveHits applies hits between fighters each frame.

	Each 60 Hz frame:
	- Hitstop freezes the fighter completely (presses are still buffered). When the hitstop
	  of a hit ends, the held direction bends the launch (DI).
	- Hitstun takes away control; the fighter flies with its launch velocity.
	- A defensive action in progress (shield, dodge, ...) runs.
	- Otherwise holding shield on the ground starts shielding, pressing it in the air starts
	  an air dodge, a buffered attack starts if the fighter can act, or it moves normally.

	Attacks on the ground: Attack = Jab, or SideTilt when holding left/right; Smash = SideSmash.
	In the air either button gives NeutralAir. Landing during an aerial cancels it into that
	move's landing lag.

	Defense (tuning in Combat/Config.Defense):
	- Shield: hold on the ground. Blocks hits (they wear the shield down instead of adding %),
	  drains while held, regenerates while down, and breaks into a long stun when empty.
	  Let go for a short drop lag; jump straight out of it any time.
	- While shielding: press down to spot dodge, or flick left/right to roll that way.
	- In the air: press shield to air dodge, once per airtime.
	- Dodges are intangible for part of their duration: attacks pass straight through.
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

export type DodgeConfig = { Start: number, End: number, Total: number }

export type DefenseConfig = {
	ShieldMax: number,
	ShieldDrain: number,
	ShieldRegen: number,
	ShieldDamageMultiplier: number,
	ShieldStunBase: number,
	ShieldStunPerDamage: number,
	ShieldPushPerDamage: number,
	ShieldDropLag: number,
	ShieldBreakStun: number,
	ShieldAfterBreak: number,
	SpotDodge: DodgeConfig,
	Roll: { Start: number, End: number, Total: number, Speed: number, MoveFrames: number },
	AirDodge: { Start: number, End: number, Total: number, LandingLag: number },
	DIMaxDegrees: number,
}

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
	Defense: DefenseConfig,
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
	ShieldHeld: boolean,
}

export type Defense = "Shield" | "ShieldDrop" | "ShieldBreak" | "SpotDodge" | "Roll" | "AirDodge"

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
	Shield: number, -- shield health
	Defense: Defense?, -- defensive action in progress
	DefenseFrame: number, -- 1 on its first frame
	ShieldStun: number, -- frames stuck in shield after blocking
	RollDirection: number,
	AirDodged: boolean, -- already air dodged since last on the ground
	DIPending: boolean, -- hit this hitstop; DI applies when it ends
	PrevShieldHeld: boolean,
	PrevMoveX: number,
	PrevMoveY: number,
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
		ShieldHeld = false,
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
		Shield = ctx.Combat.Defense.ShieldMax,
		Defense = nil,
		DefenseFrame = 0,
		ShieldStun = 0,
		RollDirection = 0,
		AirDodged = false,
		DIPending = false,
		PrevShieldHeld = false,
		PrevMoveX = 0,
		PrevMoveY = 0,
	}
end

function Fighter.isShielding(f: State): boolean
	return f.Defense == "Shield"
end

-- Attacks pass straight through during the intangible part of a dodge.
function Fighter.isIntangible(f: State, ctx: Context): boolean
	local kind = f.Defense
	if kind ~= "SpotDodge" and kind ~= "Roll" and kind ~= "AirDodge" then
		return false
	end
	local window: DodgeConfig = (ctx.Combat.Defense :: any)[kind]
	return f.DefenseFrame >= window.Start and f.DefenseFrame <= window.End
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

-- DI: when a hit's hitstop ends, the held direction rotates the launch by up to DIMaxDegrees,
-- most when held at right angles to it, not at all when held along it.
local function applyDI(f: State, intent: Intent, ctx: Context)
	f.DIPending = false
	local body = table.clone(f.Body)
	local speed = math.sqrt(body.VX * body.VX + body.VY * body.VY)
	local sx, sy = intent.MoveX, intent.MoveY
	local stick = math.sqrt(sx * sx + sy * sy)
	if speed < 1e-6 or stick < ctx.Movement.StickDeadzone then
		return
	end
	if stick > 1 then
		sx, sy = sx / stick, sy / stick
	end
	local dirX, dirY = body.VX / speed, body.VY / speed
	local cross = dirX * sy - dirY * sx -- > 0: stick is anticlockwise of the launch
	local angle = math.rad(ctx.Combat.Defense.DIMaxDegrees) * cross
	local c, s = math.cos(angle), math.sin(angle)
	body.VX, body.VY = body.VX * c - body.VY * s, body.VX * s + body.VY * c
	f.Body = body
end

local function startDefense(f: State, kind: Defense)
	f.Defense = kind
	f.DefenseFrame = 0
	f.ShieldStun = 0
end

-- One frame of a defensive action in progress. Returns nothing; updates f.
local function stepDefense(f: State, intent: Intent, ctx: Context, pressedDown: boolean, flickX: number)
	local d = ctx.Combat.Defense
	f.DefenseFrame += 1
	local kind = f.Defense

	if kind == "Shield" then
		if f.Body.Mode ~= "Ground" then
			f.Defense = nil -- slid off an edge
			f.ShieldStun = 0
		elseif f.ShieldStun > 0 then
			f.ShieldStun -= 1
		else
			f.Shield -= d.ShieldDrain
			if f.Shield <= 0 then
				f.Shield = 0
				startDefense(f, "ShieldBreak")
				f.DefenseFrame = 1
			elseif intent.JumpPressed then
				-- Jump straight out of shield.
				f.Defense = nil
				f.Body = Movement.step(f.Body, intent, ctx.Movement, ctx.Stage)
				return
			elseif pressedDown then
				startDefense(f, "SpotDodge")
				f.DefenseFrame = 1
			elseif flickX ~= 0 then
				startDefense(f, "Roll")
				f.DefenseFrame = 1
				f.RollDirection = flickX
			elseif not intent.ShieldHeld then
				startDefense(f, "ShieldDrop")
				f.DefenseFrame = 1
			end
		end
	end

	kind = f.Defense
	if kind == "Roll" then
		local body = table.clone(f.Body)
		if f.DefenseFrame <= d.Roll.MoveFrames then
			body.VX = f.RollDirection * d.Roll.Speed
		end
		f.Body = Movement.step(body, Movement.neutralIntent(), ctx.Movement, ctx.Stage)
		if f.DefenseFrame >= d.Roll.Total or f.Body.Mode == "Air" then
			f.Defense = nil
		end
	elseif kind == "AirDodge" then
		-- Drift but no jumps or fast-fall; landing early cancels into landing lag.
		local drift = Movement.neutralIntent()
		drift.MoveX = intent.MoveX
		f.Body = Movement.step(f.Body, drift, ctx.Movement, ctx.Stage)
		if f.Body.Mode ~= "Air" then
			local body = table.clone(f.Body)
			body.Mode = "Landing"
			body.ModeFrame = 0
			body.LandingLagFrames = d.AirDodge.LandingLag
			f.Body = body
			f.Defense = nil
		elseif f.DefenseFrame >= d.AirDodge.Total then
			f.Defense = nil
		end
	else
		f.Body = Movement.step(f.Body, Movement.neutralIntent(), ctx.Movement, ctx.Stage)
		local length = if kind == "ShieldDrop"
			then d.ShieldDropLag
			elseif kind == "ShieldBreak" then d.ShieldBreakStun
			elseif kind == "SpotDodge" then d.SpotDodge.Total
			else math.huge -- Shield lasts as long as it's held
		if f.DefenseFrame >= length then
			if kind == "ShieldBreak" then
				f.Shield = d.ShieldAfterBreak
			end
			f.Defense = nil
		end
	end
end

local stepInner: (f: State, intent: Intent, ctx: Context) -> ()

-- Advance one 60 Hz frame. Returns a new State; the input State is not changed.
function Fighter.step(state: State, intent: Intent, ctx: Context): State
	local f = table.clone(state)
	stepInner(f, intent, ctx)
	-- Shield, dodges, hitstun and ground attacks move the body with a neutral intent; keep its
	-- idea of the last held up/down true, so holding down through them doesn't count as a fresh
	-- press afterwards (dropping through a platform or fast-falling by itself).
	if f.Body.PrevMoveY ~= intent.MoveY then
		local body = table.clone(f.Body)
		body.PrevMoveY = intent.MoveY
		f.Body = body
	end
	return f
end

stepInner = function(f: State, intent: Intent, ctx: Context)
	local d = ctx.Combat.Defense
	local mc = ctx.Movement

	local pressed = intent.AttackPressed or intent.SmashPressed
	if pressed then
		f.AttackBuffer = ctx.Combat.AttackBuffer
		f.BufferedSmash = intent.SmashPressed
		f.BufferedSmashX = intent.SmashX
	end

	-- Fresh presses (this frame but not last): shield, down, and a left/right flick.
	local shieldPressed = intent.ShieldHeld and not f.PrevShieldHeld
	local pressedDown = intent.MoveY <= -mc.DownThreshold and f.PrevMoveY > -mc.DownThreshold
	local flickX = 0
	if math.abs(intent.MoveX) >= mc.RunThreshold and math.abs(f.PrevMoveX) < mc.RunThreshold then
		flickX = math.sign(intent.MoveX)
	end
	f.PrevShieldHeld = intent.ShieldHeld
	f.PrevMoveX = intent.MoveX
	f.PrevMoveY = intent.MoveY

	if f.Hitstop > 0 then
		f.Hitstop -= 1
		if f.Hitstop == 0 and f.DIPending then
			applyDI(f, intent, ctx)
		end
		return
	end
	if not pressed and f.AttackBuffer > 0 then
		f.AttackBuffer -= 1
	end
	if f.Defense ~= "Shield" and f.Defense ~= "ShieldBreak" then
		f.Shield = math.min(f.Shield + d.ShieldRegen, d.ShieldMax)
	end

	if f.Hitstun > 0 then
		f.Hitstun -= 1
		-- Knockback decay: horizontal launch speed bleeds off at a fixed rate, as in Smash.
		-- Gravity already does this vertically.
		local body = table.clone(f.Body)
		local decay = ctx.Combat.LaunchDecay
		body.VX = if body.VX > 0 then math.max(body.VX - decay, 0) else math.min(body.VX + decay, 0)
		f.Body = Movement.step(body, neutralMovement(), ctx.Movement, ctx.Stage)
		return
	end

	if not f.Defense and not f.Attack then
		if f.Body.Mode == "Ground" and intent.ShieldHeld and f.Shield > 0 then
			startDefense(f, "Shield")
		elseif f.Body.Mode == "Air" and shieldPressed and not f.AirDodged then
			startDefense(f, "AirDodge")
			f.AirDodged = true
		end
	end
	if f.Defense then
		stepDefense(f, intent, ctx, pressedDown, flickX)
		if f.Body.Mode ~= "Air" then
			f.AirDodged = false
		end
		return
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
		if f.Body.Mode ~= "Air" then
			f.AirDodged = false
		end
		return
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
	if f.Body.Mode ~= "Air" then
		f.AirDodged = false
	end
end

return Fighter
