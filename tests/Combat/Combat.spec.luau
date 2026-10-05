--!strict
-- Unit tests for src/shared/Combat. Run with: lune run tests/run Combat

local Combat = require("../../src/shared/Combat/Combat")
local CombatConfig = require("../../src/shared/Combat/Config")
local Fighter = require("../../src/shared/Combat/Fighter")
local Knockback = require("../../src/shared/Combat/Knockback")
local TestMoveset = require("../../src/shared/Combat/TestMoveset")
local HitTiers = require("../../src/shared/Feel/HitTiers")
local MovementConfig = require("../../src/shared/Movement/Config")

type State = Fighter.State
type Intent = Fighter.Intent

-- Same width as the main platform of src/server/TestStage, with its top at y = 0.
local ctx: Fighter.Context = {
	Movement = MovementConfig,
	Combat = CombatConfig,
	Stage = { Solids = { { MinX = -55, MaxX = 55, MinY = -10, MaxY = 0 } }, Platforms = {} },
	Moveset = TestMoveset :: any,
}

local function intent(fields: { [string]: any }?): Intent
	local i = Fighter.neutralIntent()
	if fields then
		for k, v in fields do
			(i :: any)[k] = v
		end
	end
	return i
end

local function settle(f: State): State
	for _ = 1, 120 do
		f = Fighter.step(f, intent(), ctx)
	end
	return f
end

-- Two grounded fighters: attacker at x = 0 facing right, victim `gap` studs to the right.
local function pair(gap: number): (State, State)
	local a = settle(Fighter.new(ctx, 1, 0, 1))
	local v = settle(Fighter.new(ctx, 2, gap, 1))
	return a, v
end

-- Steps both fighters (attacker gets `first` on frame 1) and resolves hits, for up to
-- `frames` frames. Returns the final states and every hit seen.
local function play(a: State, v: State, first: Intent, frames: number): (State, State, { Combat.Hit })
	local allHits = {}
	for frame = 1, frames do
		a = Fighter.step(a, if frame == 1 then first else intent(), ctx)
		v = Fighter.step(v, intent(), ctx)
		local list, hits = Combat.resolveHits({ a, v }, ctx)
		a, v = list[1], list[2]
		for _, hit in hits do
			table.insert(allHits, hit)
		end
	end
	return a, v, allHits
end

return function(t)
	t.test("knockback grows with the victim's percent", function()
		local low = Knockback.compute(CombatConfig, 20, 10, 100, 30, 90)
		local high = Knockback.compute(CombatConfig, 120, 10, 100, 30, 90)
		t.truthy(high > low, "more percent should mean more knockback")
	end)

	t.test("heavier fighters take less knockback", function()
		local light = Knockback.compute(CombatConfig, 80, 10, 80, 30, 90)
		local heavy = Knockback.compute(CombatConfig, 80, 10, 120, 30, 90)
		t.truthy(heavy < light, "weight should reduce knockback")
	end)

	t.test("knockback matches the formula at a known point", function()
		-- p = 100, d = 10, w = 100: (10 + 50) * 1 * 1.4 + 18 = 102, * 0.9 + 30 = 121.8
		t.near(Knockback.compute(CombatConfig, 100, 10, 100, 30, 90), 121.8, 1e-9)
	end)

	t.test("launch angle 0 goes straight forward, 90 straight up", function()
		local vx, vy = Knockback.launchVelocity(CombatConfig, 100, 0, -1)
		t.near(vx, -100 * CombatConfig.LaunchSpeedPerKnockback, 1e-9)
		t.near(vy, 0, 1e-9)
		vx, vy = Knockback.launchVelocity(CombatConfig, 100, 90, 1)
		t.near(vx, 0, 1e-9)
		t.near(vy, 100 * CombatConfig.LaunchSpeedPerKnockback, 1e-9)
	end)

	t.test("attack with no direction is a jab", function()
		local a = Fighter.step(settle(Fighter.new(ctx, 1, 0, 1)), intent({ AttackPressed = true }), ctx)
		t.eq((a.Attack :: Fighter.Attack).Name, "Jab")
	end)

	t.test("attack while holding a direction is a tilt that faces that way", function()
		local a = Fighter.step(settle(Fighter.new(ctx, 1, 0, 1)), intent({ AttackPressed = true, MoveX = -1 }), ctx)
		t.eq((a.Attack :: Fighter.Attack).Name, "SideTilt")
		t.eq(a.Body.Facing, -1)
	end)

	t.test("smash aims the way it was pressed", function()
		local a = Fighter.step(settle(Fighter.new(ctx, 1, 0, 1)), intent({ SmashPressed = true, SmashX = -1 }), ctx)
		t.eq((a.Attack :: Fighter.Attack).Name, "SideSmash")
		t.eq(a.Body.Facing, -1)
	end)

	t.test("attack in the air is a neutral air", function()
		local a = Fighter.new(ctx, 1, 0, 30)
		a = Fighter.step(a, intent({ AttackPressed = true }), ctx)
		t.eq((a.Attack :: Fighter.Attack).Name, "NeutralAir")
	end)

	t.test("ground attacks root the fighter in place", function()
		local a = settle(Fighter.new(ctx, 1, 0, 1))
		local x = a.Body.X
		a = Fighter.step(a, intent({ AttackPressed = true }), ctx)
		for _ = 1, 5 do
			a = Fighter.step(a, intent({ MoveX = 1, JumpPressed = true, JumpHeld = true }), ctx)
		end
		t.eq(a.Body.X, x)
		t.eq(a.Body.Mode, "Ground")
	end)

	t.test("an attack ends after startup + active + endlag frames", function()
		local a = Fighter.step(settle(Fighter.new(ctx, 1, 0, 1)), intent({ AttackPressed = true }), ctx)
		local total = Fighter.totalFrames(TestMoveset.Jab)
		for _ = 2, total - 1 do
			a = Fighter.step(a, intent(), ctx)
		end
		t.truthy(a.Attack ~= nil, "still attacking on the last frame but one")
		a = Fighter.step(a, intent(), ctx)
		t.eq(a.Attack, nil)
	end)

	t.test("hitbox is only out during active frames", function()
		local a = Fighter.step(settle(Fighter.new(ctx, 1, 0, 1)), intent({ AttackPressed = true }), ctx)
		local move = TestMoveset.Jab
		for frame = 1, Fighter.totalFrames(move) - 1 do
			local active = frame > move.Startup and frame <= move.Startup + move.Active
			t.eq(Fighter.activeHitbox(a, ctx) ~= nil, active, `frame {frame}`)
			a = Fighter.step(a, intent(), ctx)
		end
	end)

	t.test("a jab hits a fighter in range: damage, launch, hitstun and hitstop", function()
		local a, v = pair(3)
		local hits
		a, v, hits = play(a, v, intent({ AttackPressed = true }), TestMoveset.Jab.Startup + 1)
		t.eq(#hits, 1)
		t.eq(v.Percent, TestMoveset.Jab.Damage)
		t.eq(v.Body.Mode, "Air")
		t.truthy(v.Body.VX > 0, "launched away from the attacker")
		t.truthy(v.Hitstun > 0, "victim is in hitstun")
		local victimFrames, attackerFrames = HitTiers.hitstopFrames(TestMoveset.Jab.Damage, { playerCount = 2 })
		t.eq(v.Hitstop, victimFrames)
		t.eq(a.Hitstop, attackerFrames)
	end)

	t.test("an attack out of range misses", function()
		local a, v = pair(10)
		local hits
		a, v, hits = play(a, v, intent({ AttackPressed = true }), 20)
		t.eq(#hits, 0)
		t.eq(v.Percent, 0)
	end)

	t.test("one attack hits a fighter only once", function()
		local a, v = pair(1)
		local hits
		a, v, hits = play(a, v, intent({ AttackPressed = true }), Fighter.totalFrames(TestMoveset.Jab) + 20)
		t.eq(#hits, 1)
		t.eq(v.Percent, TestMoveset.Jab.Damage)
	end)

	t.test("hitstop freezes the victim before it flies", function()
		local a, v = pair(3)
		a, v = play(a, v, intent({ AttackPressed = true }), TestMoveset.Jab.Startup + 1)
		local x = v.Body.X
		local frozen = v.Hitstop
		for _ = 1, frozen do
			v = Fighter.step(v, intent(), ctx)
			t.eq(v.Body.X, x)
		end
		v = Fighter.step(v, intent(), ctx)
		t.truthy(v.Body.X > x, "moves once hitstop ends")
	end)

	t.test("a victim in hitstun can't act", function()
		local a, v = pair(3)
		a, v = play(a, v, intent({ AttackPressed = true }), TestMoveset.Jab.Startup + 1)
		v = Fighter.step(v, intent({ AttackPressed = true, JumpPressed = true, JumpHeld = true }), ctx)
		t.eq(v.Attack, nil)
		t.eq(v.Body.Mode, "Air")
	end)

	t.test("the same smash sends a damaged fighter much further", function()
		local function launchSpeed(startPercent: number): number
			local a, v = pair(4)
			v.Percent = startPercent
			a, v = play(a, v, intent({ SmashPressed = true }), TestMoveset.SideSmash.Startup + 1)
			return v.Body.VX
		end
		t.truthy(launchSpeed(100) > 2 * launchSpeed(0), "knockback should scale with percent")
	end)

	t.test("a smash at high percent from mid-stage sends the fighter past the blast zone", function()
		local a, v = pair(4)
		v.Percent = 120
		a, v = play(a, v, intent({ SmashPressed = true }), 300)
		local zone = Combat.blastZone(ctx) :: any
		t.truthy(Combat.isOutside(v, zone), `victim should be KO'd, at x = {v.Body.X}`)
	end)

	t.test("a jab at 0% doesn't KO", function()
		local a, v = pair(3)
		a, v = play(a, v, intent({ AttackPressed = true }), 200)
		local zone = Combat.blastZone(ctx) :: any
		t.truthy(not Combat.isOutside(v, zone), "a jab should not KO")
		t.eq(v.Body.Mode, "Ground")
	end)

	t.test("landing during an aerial cancels it into that aerial's landing lag", function()
		local a = Fighter.new(ctx, 1, 0, 2)
		a = Fighter.step(a, intent({ AttackPressed = true }), ctx)
		t.eq((a.Attack :: Fighter.Attack).Name, "NeutralAir")
		while a.Body.Mode == "Air" do
			a = Fighter.step(a, intent(), ctx)
		end
		t.eq(a.Attack, nil)
		t.eq(a.Body.Mode, "Landing")
		t.eq(a.Body.LandingLagFrames, TestMoveset.NeutralAir.LandingLag)
	end)

	t.test("an attack pressed during landing lag comes out after it", function()
		local a = Fighter.new(ctx, 1, 0, 0.5)
		while a.Body.Mode ~= "Landing" do
			a = Fighter.step(a, intent(), ctx)
		end
		a = Fighter.step(a, intent({ AttackPressed = true }), ctx)
		for _ = 1, MovementConfig.LandingLag do
			a = Fighter.step(a, intent(), ctx)
		end
		t.truthy(a.Attack ~= nil, "buffered attack should start")
	end)

	t.test("blast zone surrounds the stage with the configured margins", function()
		local zone = Combat.blastZone(ctx) :: any
		t.eq(zone.MinX, -55 - CombatConfig.BlastZone.Side)
		t.eq(zone.MaxX, 55 + CombatConfig.BlastZone.Side)
		t.eq(zone.MinY, -10 - CombatConfig.BlastZone.Bottom)
		t.eq(zone.MaxY, 0 + CombatConfig.BlastZone.Top)
	end)
end
