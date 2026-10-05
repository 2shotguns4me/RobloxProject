--!strict
--[[
	Interactions between fighters for one simulation frame: hit detection and resolution,
	and blast-zone KOs. Pure.

		fighters = step every fighter with Fighter.step, then:
		fighters, hits = Combat.resolveHits(fighters, ctx)
		local zone = Combat.blastZone(ctx)
		if Combat.isOutside(fighter, zone) then ... KO ...

	Hits are gathered first and applied together, so two attacks that connect on the same
	frame both land (a trade).
]]

local HitTiers = require("../Feel/HitTiers")
local Movement = require("../Movement/Movement")
local Fighter = require("./Fighter")
local Knockback = require("./Knockback")

local Combat = {}

export type Hit = {
	AttackerId: number,
	VictimId: number,
	Move: string,
	Damage: number,
	Knockback: number,
	Percent: number, -- victim's percent after the hit
	VictimHitstop: number,
	AttackerHitstop: number,
	DirectionX: number, -- unit launch direction
	DirectionY: number,
	X: number, -- contact point (centre of the hitbox/hurtbox overlap)
	Y: number,
	Shielded: boolean, -- blocked: the shield took it, no % or launch
}

-- Everything a hit does to its victim, worked out from the victim's percent before the hit.
-- The server computes this for online hits and sends it to the victim's client, which
-- applies it with Combat.applyHit; local hits do both steps at once.
export type HitResult = {
	Damage: number,
	Percent: number, -- victim's percent after the hit
	Knockback: number,
	VX: number, -- launch velocity, studs per frame
	VY: number,
	Hitstun: number,
	VictimHitstop: number,
	AttackerHitstop: number,
	DirectionX: number, -- unit launch direction
	DirectionY: number,
}

function Combat.computeHit(
	ctx: Fighter.Context,
	move: Fighter.Move,
	attackerFacing: number,
	victimPercent: number,
	victimWeight: number,
	playerCount: number
): HitResult
	local percent = victimPercent + move.Damage
	local kb =
		Knockback.compute(ctx.Combat, percent, move.Damage, victimWeight, move.BaseKnockback, move.KnockbackGrowth)
	local vx, vy = Knockback.launchVelocity(ctx.Combat, kb, move.Angle, attackerFacing)
	local victimFrames, attackerFrames = HitTiers.hitstopFrames(move.Damage, { playerCount = playerCount })
	local radians = math.rad(move.Angle)
	return {
		Damage = move.Damage,
		Percent = percent,
		Knockback = kb,
		VX = vx,
		VY = vy,
		Hitstun = Knockback.hitstunFrames(ctx.Combat, kb),
		VictimHitstop = victimFrames,
		AttackerHitstop = attackerFrames,
		DirectionX = math.cos(radians) * attackerFacing,
		DirectionY = math.sin(radians),
	}
end

-- Applies a hit to its victim: damage, launch, hitstun, hitstop, and cancels whatever it
-- was doing. DI is applied by the victim's own input when the hitstop ends, and getting hit
-- gives back the air dodge.
function Combat.applyHit(victim: Fighter.State, result: HitResult): Fighter.State
	local v = table.clone(victim)
	v.Percent = result.Percent
	v.Body = Movement.launch(v.Body, result.VX, result.VY)
	v.Hitstun = result.Hitstun
	v.Hitstop = math.max(v.Hitstop, result.VictimHitstop)
	v.Attack = nil
	v.Defense = nil
	v.ShieldStun = 0
	v.AirDodged = false
	v.DIPending = true
	return v
end

-- What a blocked hit does: shield damage, shield stun and pushback instead of % and launch.
export type ShieldHitResult = {
	Damage: number,
	ShieldDamage: number,
	ShieldStun: number,
	PushX: number, -- the blocker's slide, studs per frame (away from the attacker)
	VictimHitstop: number,
	AttackerHitstop: number,
}

function Combat.computeShieldHit(
	ctx: Fighter.Context,
	move: Fighter.Move,
	attackerFacing: number,
	playerCount: number
): ShieldHitResult
	local d = ctx.Combat.Defense
	local victimFrames, attackerFrames = HitTiers.hitstopFrames(move.Damage, { playerCount = playerCount })
	return {
		Damage = move.Damage,
		ShieldDamage = move.Damage * d.ShieldDamageMultiplier,
		ShieldStun = math.floor(d.ShieldStunBase + move.Damage * d.ShieldStunPerDamage),
		PushX = attackerFacing * move.Damage * d.ShieldPushPerDamage,
		VictimHitstop = victimFrames,
		AttackerHitstop = attackerFrames,
	}
end

-- Applies a blocked hit. A shield worn down to nothing breaks into the long stun. If the
-- fighter has already let go of its shield (an online hit judged on a slightly older view of
-- it), only the shield health goes down.
function Combat.applyShieldHit(victim: Fighter.State, result: ShieldHitResult): Fighter.State
	local v = table.clone(victim)
	if not Fighter.isShielding(v) then
		v.Shield = math.max(0, v.Shield - result.ShieldDamage)
		return v
	end
	v.Shield -= result.ShieldDamage
	v.Hitstop = math.max(v.Hitstop, result.VictimHitstop)
	local body = table.clone(v.Body)
	body.VX = result.PushX
	v.Body = body
	if v.Shield <= 0 then
		v.Shield = 0
		v.Defense = "ShieldBreak"
		v.DefenseFrame = 0
		v.ShieldStun = 0
		v.Attack = nil
	else
		v.ShieldStun = result.ShieldStun
	end
	return v
end

local function overlap(a: Movement.Rect, b: Movement.Rect): Movement.Rect?
	local minX, maxX = math.max(a.MinX, b.MinX), math.min(a.MaxX, b.MaxX)
	local minY, maxY = math.max(a.MinY, b.MinY), math.min(a.MaxY, b.MaxY)
	if minX < maxX and minY < maxY then
		return { MinX = minX, MaxX = maxX, MinY = minY, MaxY = maxY }
	end
	return nil
end

-- Detects every hit this frame and applies damage, knockback, hitstun and hitstop.
-- Returns new fighter states (same order) and the hits, for effects and UI.
function Combat.resolveHits(fighters: { Fighter.State }, ctx: Fighter.Context): ({ Fighter.State }, { Hit })
	local playerCount = #fighters
	local pending = {}
	for ai, attacker in fighters do
		local hitbox, move = Fighter.activeHitbox(attacker, ctx)
		local attack = attacker.Attack
		if hitbox and move and attack then
			for vi, victim in fighters do
				-- Dodging fighters are intangible: the attack passes through and can still hit
				-- them later in its active frames.
				if vi ~= ai and not attack.Hit[victim.Id] and not Fighter.isIntangible(victim, ctx) then
					local contact = overlap(hitbox, Fighter.hurtbox(victim, ctx))
					if contact then
						table.insert(pending, {
							ai = ai,
							vi = vi,
							move = move,
							name = attack.Name,
							contact = contact,
							shielded = Fighter.isShielding(victim),
						})
					end
				end
			end
		end
	end

	if #pending == 0 then
		return fighters, {}
	end

	local result = table.clone(fighters)
	local hits: { Hit } = {}
	for _, p in pending do
		local attacker = table.clone(result[p.ai])
		local victim = table.clone(result[p.vi])
		local move = p.move

		-- In a trade the other hit may already have cancelled this attack; the hit still lands.
		local current = attacker.Attack
		if current then
			local attack = table.clone(current)
			attack.Hit = table.clone(attack.Hit)
			attack.Hit[victim.Id] = true
			attacker.Attack = attack
		end

		local contactX = (p.contact.MinX + p.contact.MaxX) / 2
		local contactY = (p.contact.MinY + p.contact.MaxY) / 2
		-- Check the shield again: an earlier hit this frame may have broken it.
		if p.shielded and Fighter.isShielding(victim) then
			local blocked = Combat.computeShieldHit(ctx, move, attacker.Body.Facing, playerCount)
			victim = Combat.applyShieldHit(victim, blocked)
			attacker.Hitstop = math.max(attacker.Hitstop, blocked.AttackerHitstop)
			result[p.ai] = attacker
			result[p.vi] = victim
			table.insert(hits, {
				AttackerId = attacker.Id,
				VictimId = victim.Id,
				Move = p.name,
				Damage = move.Damage,
				Knockback = 0,
				Percent = victim.Percent,
				VictimHitstop = blocked.VictimHitstop,
				AttackerHitstop = blocked.AttackerHitstop,
				DirectionX = attacker.Body.Facing,
				DirectionY = 0,
				X = contactX,
				Y = contactY,
				Shielded = true,
			})
			continue
		end

		local hit = Combat.computeHit(ctx, move, attacker.Body.Facing, victim.Percent, victim.Weight, playerCount)
		victim = Combat.applyHit(victim, hit)
		attacker.Hitstop = math.max(attacker.Hitstop, hit.AttackerHitstop)

		result[p.ai] = attacker
		result[p.vi] = victim

		table.insert(hits, {
			AttackerId = attacker.Id,
			VictimId = victim.Id,
			Move = p.name,
			Damage = move.Damage,
			Knockback = hit.Knockback,
			Percent = hit.Percent,
			VictimHitstop = hit.VictimHitstop,
			AttackerHitstop = hit.AttackerHitstop,
			DirectionX = hit.DirectionX,
			DirectionY = hit.DirectionY,
			X = contactX,
			Y = contactY,
			Shielded = false,
		})
	end
	return result, hits
end

-- The KO box: the stage's outer bounds pushed out by the BlastZone margins.
function Combat.blastZone(ctx: Fighter.Context): Movement.Rect?
	local zone: Movement.Rect? = nil
	local function include(r: Movement.Rect)
		if zone then
			zone.MinX = math.min(zone.MinX, r.MinX)
			zone.MaxX = math.max(zone.MaxX, r.MaxX)
			zone.MinY = math.min(zone.MinY, r.MinY)
			zone.MaxY = math.max(zone.MaxY, r.MaxY)
		else
			zone = table.clone(r)
		end
	end
	for _, r in ctx.Stage.Solids do
		include(r)
	end
	for _, r in ctx.Stage.Platforms do
		include(r)
	end
	local z = zone
	if not z then
		return nil
	end
	local margin = ctx.Combat.BlastZone
	return {
		MinX = z.MinX - margin.Side,
		MaxX = z.MaxX + margin.Side,
		MinY = z.MinY - margin.Bottom,
		MaxY = z.MaxY + margin.Top,
	}
end

function Combat.isOutside(f: Fighter.State, zone: Movement.Rect): boolean
	local body = f.Body
	return body.X < zone.MinX or body.X > zone.MaxX or body.Y < zone.MinY or body.Y > zone.MaxY
end

return Combat
