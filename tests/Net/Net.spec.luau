--!strict
-- Unit tests for src/shared/Net. Run with: lune run tests/run Net

local Combat = require("../../src/shared/Combat/Combat")
local CombatConfig = require("../../src/shared/Combat/Config")
local Fighter = require("../../src/shared/Combat/Fighter")
local TestMoveset = require("../../src/shared/Combat/TestMoveset")
local MovementConfig = require("../../src/shared/Movement/Config")
local History = require("../../src/shared/Net/History")
local HitValidation = require("../../src/shared/Net/HitValidation")
local NetConfig = require("../../src/shared/Net/Config")
local Snapshot = require("../../src/shared/Net/Snapshot")

local ctx: Fighter.Context = {
	Movement = MovementConfig,
	Combat = CombatConfig,
	Stage = { Solids = { { MinX = -55, MaxX = 55, MinY = -10, MaxY = 0 } }, Platforms = {} },
	Moveset = TestMoveset :: any,
}

local function snap(t: number, x: number, fields: { [string]: any }?): Snapshot.Snapshot
	local s: Snapshot.Snapshot = {
		T = t,
		X = x,
		Y = 0,
		VX = 0,
		VY = 0,
		Facing = 1,
		Mode = "Ground",
		Attack = "",
		AttackFrame = 0,
		Serial = 0,
		Hitstun = false,
		Defense = "",
		DefenseFrame = 0,
		Shield = 55,
		Percent = 0,
	}
	if fields then
		for k, v in fields do
			(s :: any)[k] = v
		end
	end
	return s
end

-- Attacker at x = 0 doing a jab (serial 1) from t = 10.0; victim standing at `victimX`.
local JAB_ACTIVE_FRAME = TestMoveset.Jab.Startup + 1
local function scenario(victimX: number): (History.History, History.History)
	local attacker = History.new(NetConfig.HistorySeconds)
	local victim = History.new(NetConfig.HistorySeconds)
	for i = 0, 10 do
		local t = 10 + i / 30
		local frame = i * 2
		local attacking = frame >= 1 and frame <= 14
		History.push(
			attacker,
			snap(t, 0, {
				Attack = if attacking then "Jab" else "",
				AttackFrame = if attacking then frame else 0,
				Serial = if attacking then 1 else 0,
			})
		)
		History.push(victim, snap(t, victimX))
	end
	return attacker, victim
end

local function claim(fields: { [string]: any }?): HitValidation.Claim
	local c: HitValidation.Claim = {
		VictimId = 2,
		Move = "Jab",
		Serial = 1,
		Frame = JAB_ACTIVE_FRAME,
		T = 10.1,
		VictimT = 10.05,
	}
	if fields then
		for k, v in fields do
			(c :: any)[k] = v
		end
	end
	return c
end

return function(t)
	-- History

	t.test("history interpolates between snapshots", function()
		local h = History.new(1)
		History.push(h, snap(1, 0))
		History.push(h, snap(2, 10))
		local s = History.sample(h, 1.25) :: Snapshot.Snapshot
		t.near(s.X, 2.5)
		t.eq(s.T, 1.25)
	end)

	t.test("history holds the ends instead of guessing", function()
		local h = History.new(1)
		History.push(h, snap(1, 0))
		History.push(h, snap(2, 10))
		t.eq((History.sample(h, 0) :: Snapshot.Snapshot).X, 0)
		t.eq((History.sample(h, 5) :: Snapshot.Snapshot).X, 10)
		t.eq(History.sample(History.new(1), 1), nil)
	end)

	t.test("history drops out-of-order snapshots and trims old ones", function()
		local h = History.new(1)
		History.push(h, snap(1, 0))
		History.push(h, snap(3, 30))
		History.push(h, snap(2, 20)) -- arrived late
		t.eq(#h.Entries, 1, "the t = 1 entry is more than 1 s older than t = 3")
		t.eq((History.latest(h) :: Snapshot.Snapshot).X, 30)
	end)

	t.test("history finds an attack by move and serial in a time window", function()
		local attacker = scenario(3)
		t.truthy(History.findAttack(attacker, "Jab", 1, 10, 10.5) ~= nil, "jab serial 1")
		t.eq(History.findAttack(attacker, "Jab", 2, 10, 10.5), nil)
		t.eq(History.findAttack(attacker, "SideSmash", 1, 10, 10.5), nil)
		t.eq(History.findAttack(attacker, "Jab", 1, 11, 12), nil)
	end)

	-- Snapshot

	t.test("snapshot round-trips a fighter's position and attack", function()
		local f = Fighter.new(ctx, 1, 4, 7)
		f.Body.Facing = -1
		f.Attack = { Name = "Jab", Serial = 3, Frame = 5, Hit = {} }
		local s = Snapshot.fromFighter(f, 12.5)
		t.eq(s.Attack, "Jab")
		t.eq(s.Serial, 3)
		t.eq(s.AttackFrame, 5)
		local ghost = Snapshot.toGhost(s, 9, ctx)
		t.eq(ghost.Id, 9)
		t.eq(ghost.Body.X, 4)
		t.eq(ghost.Body.Facing, -1)
		t.eq(ghost.Attack, nil, "ghosts never attack")
	end)

	t.test("sanitize accepts a good snapshot from a client", function()
		local raw = Snapshot.fromFighter(Fighter.new(ctx, 1, 4, 7), 12.5)
		raw.Percent = 999 -- clients don't decide damage
		local clean = Snapshot.sanitize(raw, ctx.Moveset, NetConfig) :: Snapshot.Snapshot
		t.eq(clean.X, 4)
		t.eq(clean.Percent, 0)
	end)

	t.test("snapshot carries shield and dodge state to ghosts", function()
		local f = Fighter.new(ctx, 1, 0, 0)
		f.Defense = "Roll"
		f.DefenseFrame = 6
		f.Shield = 30
		local ghost = Snapshot.toGhost(Snapshot.fromFighter(f, 1), 2, ctx)
		t.eq(ghost.Defense, "Roll")
		t.eq(ghost.DefenseFrame, 6)
		t.eq(ghost.Shield, 30)
		t.truthy(Fighter.isIntangible(ghost, ctx), "a ghost mid-roll is intangible too")
	end)

	t.test("sanitize rejects malformed or out-of-range snapshots", function()
		local good = Snapshot.fromFighter(Fighter.new(ctx, 1, 4, 7), 12.5)
		local function with(key: string, value: any): any
			local raw = table.clone(good) :: any
			raw[key] = value
			return raw
		end
		t.eq(Snapshot.sanitize("nope", ctx.Moveset, NetConfig), nil)
		t.eq(Snapshot.sanitize(with("X", 0 / 0), ctx.Moveset, NetConfig), nil, "NaN")
		t.eq(Snapshot.sanitize(with("X", math.huge), ctx.Moveset, NetConfig), nil, "infinity")
		t.eq(Snapshot.sanitize(with("VX", 500), ctx.Moveset, NetConfig), nil, "absurd speed")
		t.eq(Snapshot.sanitize(with("Mode", "Flying"), ctx.Moveset, NetConfig), nil, "unknown mode")
		t.eq(Snapshot.sanitize(with("Attack", "InstaKill"), ctx.Moveset, NetConfig), nil, "unknown move")
		t.eq(Snapshot.sanitize(with("Facing", 0), ctx.Moveset, NetConfig), nil, "bad facing")
		t.eq(Snapshot.sanitize(with("Defense", "GodMode"), ctx.Moveset, NetConfig), nil, "unknown defense")
		t.eq(Snapshot.sanitize(with("Shield", 0 / 0), ctx.Moveset, NetConfig), nil, "NaN shield")
	end)

	-- Hit validation

	t.test("a believable claim passes", function()
		local attacker, victim = scenario(3)
		local ok, reason = HitValidation.check(claim(), attacker, victim, ctx, NetConfig, 10.2)
		t.truthy(ok, reason)
	end)

	t.test("claims for moves that weren't in the attacker's history fail", function()
		local attacker, victim = scenario(3)
		t.eq(HitValidation.check(claim({ Serial = 2 }), attacker, victim, ctx, NetConfig, 10.2), false)
		t.eq(
			HitValidation.check(claim({ Move = "SideSmash", Frame = 17 }), attacker, victim, ctx, NetConfig, 10.2),
			false
		)
	end)

	t.test("claims on a non-active frame fail", function()
		local attacker, victim = scenario(3)
		t.eq(HitValidation.check(claim({ Frame = 1 }), attacker, victim, ctx, NetConfig, 10.2), false)
		t.eq(HitValidation.check(claim({ Move = "Nope" }), attacker, victim, ctx, NetConfig, 10.2), false)
	end)

	t.test("claims about moments too far in the past or future fail", function()
		local attacker, victim = scenario(3)
		t.eq(HitValidation.check(claim(), attacker, victim, ctx, NetConfig, 11), false, "too old")
		t.eq(HitValidation.check(claim({ T = 10.4 }), attacker, victim, ctx, NetConfig, 10.2), false, "future")
	end)

	t.test("claims on a victim that was mid-dodge fail", function()
		local attacker = scenario(3)
		local victim = History.new(NetConfig.HistorySeconds)
		for i = 0, 10 do
			History.push(victim, snap(10 + i / 30, 3, { Defense = "SpotDodge", DefenseFrame = 8 }))
		end
		local ok, reason = HitValidation.check(claim(), attacker, victim, ctx, NetConfig, 10.2)
		t.eq(ok, false)
		t.eq(reason, "victim was dodging")
	end)

	t.test("a claim on a shielding victim passes and reports the shield", function()
		local attacker = scenario(3)
		local victim = History.new(NetConfig.HistorySeconds)
		for i = 0, 10 do
			History.push(victim, snap(10 + i / 30, 3, { Defense = "Shield", DefenseFrame = 20 }))
		end
		local ok, _, victimGhost = HitValidation.check(claim(), attacker, victim, ctx, NetConfig, 10.2)
		t.truthy(ok, "blocked hits still count, as shield hits")
		t.truthy(victimGhost and Fighter.isShielding(victimGhost), "server can tell it was blocked")
	end)

	t.test("claims on a victim that was out of range fail", function()
		local attacker, victim = scenario(15)
		local ok = HitValidation.check(claim(), attacker, victim, ctx, NetConfig, 10.2)
		t.eq(ok, false)
	end)

	t.test("claims with the attacker facing away fail", function()
		local attacker, victim = scenario(-4)
		local ok = HitValidation.check(claim(), attacker, victim, ctx, NetConfig, 10.2)
		t.eq(ok, false)
	end)

	t.test("isNewHit: one hit per attack, later attacks only, not impossibly fast", function()
		t.truthy(HitValidation.isNewHit(nil, claim(), NetConfig), "first hit on this victim")
		local last = { Serial = 1, T = 10.1 }
		t.eq(HitValidation.isNewHit(last, claim(), NetConfig), false, "same attack again")
		t.eq(HitValidation.isNewHit(last, claim({ Serial = 0 }), NetConfig), false, "an older attack")
		t.eq(HitValidation.isNewHit(last, claim({ Serial = 2, T = 10.15 }), NetConfig), false, "too soon")
		t.truthy(HitValidation.isNewHit(last, claim({ Serial = 2, T = 10.4 }), NetConfig), "a later attack")
	end)

	t.test("a claim whose attack hasn't arrived yet says so (the server retries those)", function()
		local attacker = History.new(NetConfig.HistorySeconds)
		local _, victim = scenario(3)
		History.push(attacker, snap(10, 0))
		local ok, reason = HitValidation.check(claim(), attacker, victim, ctx, NetConfig, 10.2)
		t.eq(ok, false)
		t.eq(reason, "attack not in history")
	end)

	t.test("checkKO accepts a fighter that reached the blast zone, rejects one that didn't", function()
		local zone = Combat.blastZone(ctx) :: any
		local near = History.new(NetConfig.HistorySeconds)
		History.push(near, snap(10, 0))
		History.push(near, snap(10.1, zone.MaxX - 2))
		t.truthy(HitValidation.checkKO(near, zone, NetConfig), "flew out to the right")
		local safe = History.new(NetConfig.HistorySeconds)
		History.push(safe, snap(10, 0))
		History.push(safe, snap(10.1, 20))
		t.eq(HitValidation.checkKO(safe, zone, NetConfig), false, "never left the middle")
		t.truthy(HitValidation.checkKO(safe, nil, NetConfig), "no stage to check against")
	end)

	t.test("sanitize rejects malformed claims", function()
		t.truthy(HitValidation.sanitize(claim()) ~= nil, "a good claim")
		t.eq(HitValidation.sanitize(nil), nil)
		local bad = table.clone(claim()) :: any
		bad.T = "soon"
		t.eq(HitValidation.sanitize(bad), nil)
	end)

	-- Shared hit maths

	t.test("computeHit + applyHit match a local hit exactly", function()
		local a = Fighter.new(ctx, 1, 0, 0)
		local v = Fighter.new(ctx, 2, 3, 0)
		v.Percent = 40
		local result = Combat.computeHit(ctx, TestMoveset.SideSmash :: any, 1, v.Percent, v.Weight, 2)
		local hit = Combat.applyHit(v, result)
		t.eq(hit.Percent, 40 + TestMoveset.SideSmash.Damage)
		t.truthy(hit.Body.VX > 0, "launched away from the attacker")
		t.eq(hit.Hitstun, result.Hitstun)
		t.eq(hit.Hitstop, result.VictimHitstop)
		t.eq(a.Hitstop, 0, "applyHit doesn't touch the attacker")
	end)

	t.test("attacks get increasing serial numbers", function()
		local f = Fighter.new(ctx, 1, 0, 1)
		for _ = 1, 120 do
			f = Fighter.step(f, Fighter.neutralIntent(), ctx)
		end
		local press = Fighter.neutralIntent()
		press.AttackPressed = true
		f = Fighter.step(f, press, ctx)
		t.eq((f.Attack :: Fighter.Attack).Serial, 1)
		for _ = 1, 60 do
			f = Fighter.step(f, Fighter.neutralIntent(), ctx)
		end
		f = Fighter.step(f, press, ctx)
		t.eq((f.Attack :: Fighter.Attack).Serial, 2)
	end)
end
