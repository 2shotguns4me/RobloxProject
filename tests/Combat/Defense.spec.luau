--!strict
-- Unit tests for shield, dodges and DI in src/shared/Combat. Run with: lune run tests/run Defense

local Combat = require("../../src/shared/Combat/Combat")
local CombatConfig = require("../../src/shared/Combat/Config")
local Fighter = require("../../src/shared/Combat/Fighter")
local TestMoveset = require("../../src/shared/Combat/TestMoveset")
local MovementConfig = require("../../src/shared/Movement/Config")

type State = Fighter.State
type Intent = Fighter.Intent

local D = CombatConfig.Defense

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

local function run(f: State, frames: number, i: Intent?): State
	for _ = 1, frames do
		f = Fighter.step(f, i or intent(), ctx)
	end
	return f
end

local function grounded(x: number?): State
	return run(Fighter.new(ctx, 1, x or 0, 1), 120)
end

local function shielding(x: number?): State
	return run(grounded(x), 2, intent({ ShieldHeld = true }))
end

-- Attacker at x = 0 jabbing the victim, both stepped and resolved until the jab's active frame.
local function jabInto(victim: State, victimIntent: Intent): (State, State, { Combat.Hit })
	local a = grounded(0)
	a = Fighter.step(a, intent({ AttackPressed = true }), ctx)
	victim = Fighter.step(victim, victimIntent, ctx)
	local hits = {}
	for _ = 1, TestMoveset.Jab.Startup do
		a = Fighter.step(a, intent(), ctx)
		victim = Fighter.step(victim, victimIntent, ctx)
		local list, frameHits = Combat.resolveHits({ a, victim }, ctx)
		a, victim = list[1], list[2]
		for _, h in frameHits do
			table.insert(hits, h)
		end
	end
	return a, victim, hits
end

return function(t)
	-- Shield

	t.test("holding shield on the ground shields, and it drains", function()
		local f = shielding()
		t.eq(f.Defense, "Shield")
		local before = f.Shield
		f = run(f, 60, intent({ ShieldHeld = true }))
		t.near(f.Shield, before - 60 * D.ShieldDrain, 1e-6)
	end)

	t.test("shield regenerates while not shielding, up to its maximum", function()
		local f = grounded()
		f.Shield = 10
		f = run(f, 60)
		t.near(f.Shield, 10 + 60 * D.ShieldRegen, 1e-6)
		f = run(f, 2000)
		t.eq(f.Shield, D.ShieldMax)
	end)

	t.test("letting go of shield has a short drop lag", function()
		local f = shielding()
		f = Fighter.step(f, intent(), ctx)
		t.eq(f.Defense, "ShieldDrop")
		f = run(f, D.ShieldDropLag - 1)
		t.eq(f.Defense, nil)
	end)

	t.test("can't move while shielding, can jump straight out of it", function()
		local f = shielding()
		local x = f.Body.X
		f = run(f, 20, intent({ ShieldHeld = true, MoveX = 0.5 }))
		t.eq(f.Body.X, x)
		f = Fighter.step(f, intent({ ShieldHeld = true, JumpPressed = true, JumpHeld = true }), ctx)
		t.eq(f.Defense, nil)
		t.eq(f.Body.Mode, "JumpSquat")
	end)

	t.test("a shield held until empty breaks into a long stun", function()
		local f = shielding()
		f.Shield = 1
		for _ = 1, 20 do
			f = Fighter.step(f, intent({ ShieldHeld = true }), ctx)
			if f.Defense == "ShieldBreak" then
				break
			end
		end
		t.eq(f.Defense, "ShieldBreak")
		f = run(f, D.ShieldBreakStun - 5, intent({ AttackPressed = true, JumpPressed = true }))
		t.eq(f.Defense, "ShieldBreak", "still stunned, pressing buttons does nothing")
		f = run(f, 30)
		t.eq(f.Defense, nil)
		t.truthy(f.Shield >= D.ShieldAfterBreak, "shield partly restored")
	end)

	t.test("a blocked attack hits the shield, not the fighter", function()
		local victim = shielding(3)
		local held = intent({ ShieldHeld = true })
		local shieldBefore = victim.Shield
		local _, v, hits = jabInto(victim, held)
		t.eq(#hits, 1)
		t.truthy(hits[1].Shielded, "hit should be marked as blocked")
		t.eq(v.Percent, 0)
		t.eq(v.Body.Mode, "Ground", "no launch")
		t.truthy(v.Shield < shieldBefore - TestMoveset.Jab.Damage + 1, "shield took the damage")
		t.truthy(v.ShieldStun > 0, "stuck in shield briefly")
		t.truthy(v.Body.VX > 0, "pushed back, away from the attacker")
	end)

	t.test("a strong hit on a weak shield breaks it", function()
		local victim = shielding(3)
		victim.Shield = 2
		local _, v = jabInto(victim, intent({ ShieldHeld = true }))
		t.eq(v.Defense, "ShieldBreak")
	end)

	t.test("an attack pressed while shielding comes out after letting go", function()
		local f = shielding()
		f = Fighter.step(f, intent({ ShieldHeld = true, AttackPressed = true }), ctx)
		t.eq(f.Attack, nil, "can't attack from shield")
		f = run(f, D.ShieldDropLag + 1)
		t.truthy(f.Attack ~= nil, "buffered attack comes out after the drop lag")
	end)

	-- Dodges

	t.test("down while shielding spot dodges; attacks pass through it", function()
		local victim = shielding(3)
		victim = Fighter.step(victim, intent({ ShieldHeld = true, MoveY = -1 }), ctx)
		t.eq(victim.Defense, "SpotDodge")
		local _, v, hits = jabInto(victim, intent({ ShieldHeld = true, MoveY = -1 }))
		t.eq(#hits, 0, "jab should pass through the dodge")
		t.eq(v.Percent, 0)
	end)

	t.test("a spot dodge ends and is vulnerable again", function()
		local f = shielding()
		f = Fighter.step(f, intent({ ShieldHeld = true, MoveY = -1 }), ctx)
		f = run(f, D.SpotDodge.Total)
		t.eq(f.Defense, nil)
		t.eq(Fighter.isIntangible(f, ctx), false)
	end)

	t.test("a flick while shielding rolls that way, intangible for part of it", function()
		local f = shielding(0)
		local x = f.Body.X
		f = Fighter.step(f, intent({ ShieldHeld = true, MoveX = -1 }), ctx)
		t.eq(f.Defense, "Roll")
		local sawIntangible = false
		for _ = 1, D.Roll.Total do
			f = Fighter.step(f, intent({ ShieldHeld = true, MoveX = -1 }), ctx)
			sawIntangible = sawIntangible or Fighter.isIntangible(f, ctx)
		end
		t.truthy(sawIntangible, "roll should be intangible for part of it")
		t.truthy(f.Body.X < x - 4, `rolled left, from {x} to {f.Body.X}`)
	end)

	t.test("shield pressed in the air air-dodges, once per airtime", function()
		local f = run(grounded(), 1, intent({ JumpPressed = true, JumpHeld = true }))
		f = run(f, MovementConfig.JumpSquat + 2, intent({ JumpHeld = true }))
		t.eq(f.Body.Mode, "Air")
		f = Fighter.step(f, intent({ ShieldHeld = true }), ctx)
		t.eq(f.Defense, "AirDodge")
		f = run(f, D.AirDodge.Total)
		t.eq(f.Defense, nil)
		if f.Body.Mode == "Air" then
			f = Fighter.step(f, intent({ ShieldHeld = true }), ctx)
			t.eq(f.Defense, nil, "no second air dodge before landing")
		end
	end)

	t.test("landing during an air dodge has landing lag, and gives the air dodge back", function()
		local f = Fighter.new(ctx, 1, 0, 2)
		f = Fighter.step(f, intent({ ShieldHeld = true }), ctx)
		t.eq(f.Defense, "AirDodge")
		while f.Body.Mode == "Air" do
			f = Fighter.step(f, intent(), ctx)
		end
		t.eq(f.Body.Mode, "Landing")
		t.eq(f.Body.LandingLagFrames, D.AirDodge.LandingLag)
		t.eq(f.AirDodged, false)
	end)

	-- Edge cases found in review

	t.test("a blocked hit on a fighter that already dropped its shield only costs shield health", function()
		local f = grounded()
		f = Fighter.step(f, intent({ AttackPressed = true }), ctx)
		local blocked = Combat.computeShieldHit(ctx, TestMoveset.SideSmash :: any, 1, 2)
		local after = Combat.applyShieldHit(f, blocked)
		t.truthy(after.Attack ~= nil, "its attack carries on")
		t.eq(after.Defense, nil)
		t.eq(after.ShieldStun, 0)
		t.near(after.Shield, f.Shield - blocked.ShieldDamage, 1e-9)
	end)

	t.test("a shield broken by a hit cancels any attack", function()
		local f = shielding()
		f.Shield = 1
		f.Attack = { Name = "Jab", Serial = 1, Frame = 4, Hit = {} }
		local blocked = Combat.computeShieldHit(ctx, TestMoveset.Jab :: any, 1, 2)
		local after = Combat.applyShieldHit(f, blocked)
		t.eq(after.Defense, "ShieldBreak")
		t.eq(after.Attack, nil)
	end)

	t.test("leftover shield stun doesn't carry into the next shield", function()
		local f = shielding()
		f.ShieldStun = 8
		f.Defense = nil -- e.g. pushed off an edge mid-stun
		f = run(f, 10)
		f = Fighter.step(f, intent({ ShieldHeld = true }), ctx)
		t.eq(f.Defense, "Shield")
		t.eq(f.ShieldStun, 0)
	end)

	t.test("holding down through a spot dodge on a platform doesn't drop through it", function()
		local platformCtx = table.clone(ctx)
		platformCtx.Stage = {
			Solids = { { MinX = -55, MaxX = 55, MinY = -10, MaxY = 0 } },
			Platforms = { { MinX = -10, MaxX = 10, MinY = 19, MaxY = 20 } },
		}
		local f = Fighter.new(platformCtx, 1, 0, 25)
		for _ = 1, 120 do
			f = Fighter.step(f, intent(), platformCtx)
		end
		t.eq(f.Body.Y, 20, "standing on the platform")
		f = Fighter.step(f, intent({ ShieldHeld = true }), platformCtx)
		for _ = 1, D.SpotDodge.Total + D.ShieldDropLag + 10 do
			f = Fighter.step(f, intent({ ShieldHeld = true, MoveY = -1 }), platformCtx)
		end
		for _ = 1, 10 do
			f = Fighter.step(f, intent({ MoveY = -1 }), platformCtx)
		end
		t.eq(f.Body.Y, 20, "still on the platform")
	end)

	t.test("a second hit in the same frame as a shield break lands as a normal hit", function()
		local victim = shielding(0)
		victim.Shield = 1
		local left = run(Fighter.new(ctx, 2, -3, 1), 120)
		left.Body.Facing = 1
		local right = run(Fighter.new(ctx, 3, 3, 1), 120)
		right.Body.Facing = -1
		left = Fighter.step(left, intent({ AttackPressed = true }), ctx)
		right = Fighter.step(right, intent({ AttackPressed = true }), ctx)
		local held = intent({ ShieldHeld = true })
		victim = Fighter.step(victim, held, ctx)
		local hits = {}
		for _ = 1, TestMoveset.Jab.Startup do
			left = Fighter.step(left, intent(), ctx)
			right = Fighter.step(right, intent(), ctx)
			victim = Fighter.step(victim, held, ctx)
			local list, frameHits = Combat.resolveHits({ victim, left, right }, ctx)
			victim, left, right = list[1], list[2], list[3]
			for _, h in frameHits do
				table.insert(hits, h)
			end
		end
		t.eq(#hits, 2)
		t.truthy(hits[1].Shielded, "the first breaks the shield")
		t.eq(hits[2].Shielded, false, "the second gets through")
		t.eq(victim.Percent, TestMoveset.Jab.Damage)
	end)

	t.test("a shield break lasts ShieldBreakStun frames whether drained or hit", function()
		local drained = shielding()
		drained.Shield = D.ShieldDrain / 2
		drained = Fighter.step(drained, intent({ ShieldHeld = true }), ctx)
		t.eq(drained.Defense, "ShieldBreak")
		local frames = 1
		while drained.Defense == "ShieldBreak" do
			drained = Fighter.step(drained, intent(), ctx)
			frames += 1
		end
		t.eq(frames, D.ShieldBreakStun)
	end)

	-- DI and getting hit

	t.test("getting hit cancels shield and dodges and gives back the air dodge", function()
		local v = Fighter.new(ctx, 2, 3, 20)
		v.Defense = "AirDodge"
		v.DefenseFrame = D.AirDodge.End + 1 -- vulnerable tail end
		v.AirDodged = true
		local result = Combat.computeHit(ctx, TestMoveset.Jab :: any, 1, 0, 100, 2)
		v = Combat.applyHit(v, result)
		t.eq(v.Defense, nil)
		t.eq(v.AirDodged, false)
		t.truthy(v.DIPending, "DI waits for the hitstop to end")
	end)

	local function launchAngleWithDI(moveX: number, moveY: number): number
		local v = Fighter.new(ctx, 2, 0, 20)
		local result = Combat.computeHit(ctx, TestMoveset.SideSmash :: any, 1, 80, 100, 2)
		v = Combat.applyHit(v, result)
		while v.Hitstop > 0 do
			v = Fighter.step(v, intent({ MoveX = moveX, MoveY = moveY }), ctx)
		end
		return math.deg(math.atan2(v.Body.VY, v.Body.VX))
	end

	t.test("DI held at right angles bends the launch by DIMaxDegrees", function()
		local none = launchAngleWithDI(0, 0)
		t.near(none, TestMoveset.SideSmash.Angle, 1e-6)
		-- Launched up-right at 40 degrees; holding down-right is at right angles to it.
		local dir = math.rad(TestMoveset.SideSmash.Angle - 90)
		local bent = launchAngleWithDI(math.cos(dir), math.sin(dir))
		t.near(bent, TestMoveset.SideSmash.Angle - D.DIMaxDegrees, 1e-6)
	end)

	t.test("DI held along the launch doesn't change it", function()
		local dir = math.rad(TestMoveset.SideSmash.Angle)
		local along = launchAngleWithDI(math.cos(dir), math.sin(dir))
		t.near(along, TestMoveset.SideSmash.Angle, 1e-6)
	end)
end
