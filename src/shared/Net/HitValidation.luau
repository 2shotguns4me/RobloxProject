--!strict
--[[
	The server's checks on what clients report, against its own history of every fighter. Pure.

	A client that hits someone shows the hit straight away and sends a claim. The server only
	applies damage if the claim is believable (check):
	- the moments claimed aren't too old (rewind limit) or in the future;
	- the attacker's history shows that very attack (move + serial) around that time;
	- the attack's hitbox, on that frame and placed where the attacker was, overlaps the
	  victim's body where the victim was, with a little tolerance. This uses the same
	  Fighter.activeHitbox/hurtbox rules as the simulation;
	- the victim wasn't in the intangible part of a dodge then (timed by the server's
	  DefenseGuard when one is given, not by the client's own frame count).
	Whether it was blocked is the caller's call (DefenseGuard.shieldBlocks on victimGhost).
	...and it's a new hit (isNewHit): a later attack than the last hit on that victim, and not
	sooner after it than any real move allows.

	A KO report is accepted if the fighter's recent history reaches the blast zone (checkKO).
]]

local Fighter = require("../Combat/Fighter")
local Movement = require("../Movement/Movement")
local DefenseGuard = require("./DefenseGuard")
local History = require("./History")
local Snapshot = require("./Snapshot")

local HitValidation = {}

export type Claim = {
	VictimId: number,
	Move: string,
	Serial: number,
	Frame: number, -- the attack's frame when it hit
	T: number, -- server time the attacker hit
	VictimT: number, -- server time of the victim position the attacker saw
}

export type Config = {
	MaxRewindSeconds: number,
	FutureSlackSeconds: number,
	HitTolerance: number,
	AttackSlackSeconds: number,
	MinHitIntervalSeconds: number,
	KOTolerance: number,
}

-- The last hit one attacker landed on one victim.
export type LastHit = { Serial: number, T: number }

-- Checks a claim that arrived from a client. Returns a clean copy, or nil if malformed.
function HitValidation.sanitize(raw: any): Claim?
	if type(raw) ~= "table" or type(raw.Move) ~= "string" then
		return nil
	end
	for _, key in { "VictimId", "Serial", "Frame", "T", "VictimT" } do
		if not Snapshot.isFiniteNumber(raw[key], 1e10) then
			return nil
		end
	end
	return {
		VictimId = raw.VictimId,
		Move = raw.Move,
		Serial = math.floor(raw.Serial),
		Frame = math.floor(raw.Frame),
		T = raw.T,
		VictimT = raw.VictimT,
	}
end

-- A later attack than the previous hit on this victim, and not impossibly soon after it.
function HitValidation.isNewHit(last: LastHit?, claim: Claim, cfg: Config): boolean
	if not last then
		return true
	end
	return claim.Serial > last.Serial and claim.T - last.T >= cfg.MinHitIntervalSeconds
end

-- Returns true, or false and a short reason (for logging). The reason "attack not in history"
-- can mean the attack's state just hasn't arrived yet; the caller may retry once.
-- On success also returns the victim as the server saw it (shield, dodge, position).
function HitValidation.check(
	claim: Claim,
	attacker: History.History,
	victim: History.History,
	ctx: Fighter.Context,
	cfg: Config,
	now: number,
	victimGuard: DefenseGuard.Guard?
): (boolean, string?, Fighter.State?)
	local move = ctx.Moveset[claim.Move]
	if not move then
		return false, "unknown move"
	end
	for _, t in { claim.T, claim.VictimT } do
		if t < now - cfg.MaxRewindSeconds or t > now + cfg.FutureSlackSeconds then
			return false, "too old or in the future"
		end
	end

	local moveSeconds = Fighter.totalFrames(move) / 60
	local slack = cfg.AttackSlackSeconds
	if not History.findAttack(attacker, claim.Move, claim.Serial, claim.T - moveSeconds - slack, claim.T + slack) then
		return false, "attack not in history"
	end

	local a = History.sample(attacker, claim.T)
	local v = History.sample(victim, claim.VictimT)
	if not a or not v then
		return false, "no position history"
	end

	-- Rebuild both fighters where the server saw them and use the simulation's own rules.
	local attackerGhost = Snapshot.toGhost(a, 0, ctx)
	attackerGhost.Attack = { Name = claim.Move, Serial = claim.Serial, Frame = claim.Frame, Hit = {} }
	local hitbox = Fighter.activeHitbox(attackerGhost, ctx)
	if not hitbox then
		return false, "not an active frame"
	end
	local victimGhost = Snapshot.toGhost(v, 1, ctx)
	local dodging = if victimGuard
		then DefenseGuard.intangibleAt(victimGuard, victimGhost, claim.VictimT, ctx)
		else Fighter.isIntangible(victimGhost, ctx)
	if dodging then
		return false, "victim was dodging"
	end
	local hurtbox = Fighter.hurtbox(victimGhost, ctx)
	local tol = cfg.HitTolerance
	local overlaps = hitbox.MinX - tol < hurtbox.MaxX
		and hitbox.MaxX + tol > hurtbox.MinX
		and hitbox.MinY - tol < hurtbox.MaxY
		and hitbox.MaxY + tol > hurtbox.MinY
	if not overlaps then
		return false, "out of range"
	end
	return true, nil, victimGhost
end

-- True if the fighter got within KOTolerance of leaving the blast zone at any point in its
-- recorded history (so a late or reordered report still counts). With no stage, true.
function HitValidation.checkKO(h: History.History, zone: Movement.Rect?, cfg: Config): boolean
	if not zone then
		return true
	end
	local margin = cfg.KOTolerance
	for _, s in h.Entries do
		if
			s.X < zone.MinX + margin
			or s.X > zone.MaxX - margin
			or s.Y < zone.MinY + margin
			or s.Y > zone.MaxY - margin
		then
			return true
		end
	end
	return false
end

return HitValidation
