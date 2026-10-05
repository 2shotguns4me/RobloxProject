--!strict
-- Unit tests for src/shared/Bot. Run with: lune run tests/run Bot

local Bot = require("../../src/shared/Bot/Bot")
local BotConfig = require("../../src/shared/Bot/Config")
local Combat = require("../../src/shared/Combat/Combat")
local CombatConfig = require("../../src/shared/Combat/Config")
local Fighter = require("../../src/shared/Combat/Fighter")
local TestMoveset = require("../../src/shared/Combat/TestMoveset")
local MovementConfig = require("../../src/shared/Movement/Config")

type State = Fighter.State

-- Same width as the main platform of src/server/TestStage, with its top at y = 0.
local ctx: Fighter.Context = {
	Movement = MovementConfig,
	Combat = CombatConfig,
	Stage = { Solids = { { MinX = -55, MaxX = 55, MinY = -10, MaxY = 0 } }, Platforms = {} },
	Moveset = TestMoveset :: any,
}
local config: Bot.Config = BotConfig

local function settle(f: State): State
	for _ = 1, 120 do
		f = Fighter.step(f, Fighter.neutralIntent(), ctx)
	end
	return f
end

-- Runs the bot (id 1) against a target that never presses anything (id 2), resolving
-- hits. Stops early if `stop` returns true. Returns the final states and every hit.
local function simulate(
	me: State,
	target: State,
	frames: number,
	seed: number?,
	stop: ((State, State) -> boolean)?
): (State, State, { Combat.Hit })
	local bot = Bot.new(seed or 7)
	local allHits = {}
	for _ = 1, frames do
		local intent
		intent, bot = Bot.decide(bot, me, target, ctx, config)
		me = Fighter.step(me, intent, ctx)
		target = Fighter.step(target, Fighter.neutralIntent(), ctx)
		local list, hits = Combat.resolveHits({ me, target }, ctx)
		me, target = list[1], list[2]
		for _, hit in hits do
			table.insert(allHits, hit)
		end
		if stop and stop(me, target) then
			break
		end
	end
	return me, target, allHits
end

return function(t)
	t.test("walks towards a far-away target", function()
		local me = settle(Fighter.new(ctx, 1, -30, 1))
		local target = settle(Fighter.new(ctx, 2, 30, 1))
		local startGap = target.Body.X - me.Body.X
		me = simulate(me, target, 90, 7, function(a, b)
			return math.abs(b.Body.X - a.Body.X) <= BotConfig.AttackRangeX
		end)
		t.truthy(target.Body.X - me.Body.X < startGap, "gap should shrink")
	end)

	t.test("attacks and hits a target in range", function()
		local me = settle(Fighter.new(ctx, 1, 0, 1))
		local target = settle(Fighter.new(ctx, 2, 3, 1))
		local _, hurt, hits = simulate(me, target, 120)
		t.truthy(#hits > 0, "bot should land a hit within 2 seconds")
		t.truthy(hurt.Percent > 0, "target should take damage")
	end)

	t.test("turns around to hit a target behind it", function()
		local me = settle(Fighter.new(ctx, 1, 0, 1))
		me.Body.Facing = 1
		local target = settle(Fighter.new(ctx, 2, -3, 1))
		local _, _, hits = simulate(me, target, 120)
		t.truthy(#hits > 0, "bot should hit a target behind it")
	end)

	t.test("smashes a heavily damaged target", function()
		local me = settle(Fighter.new(ctx, 1, 0, 1))
		local target = settle(Fighter.new(ctx, 2, 3, 1))
		target.Percent = 150
		local _, _, hits = simulate(me, target, 300)
		local smashed = false
		for _, hit in hits do
			if hit.Move == "SideSmash" then
				smashed = true
			end
		end
		t.truthy(smashed, "bot should use a smash on a target at 150%")
	end)

	t.test("eventually KOs a target that never moves", function()
		local me = settle(Fighter.new(ctx, 1, 0, 1))
		local target = settle(Fighter.new(ctx, 2, 3, 1))
		local zone = Combat.blastZone(ctx) :: any
		local _, out = simulate(me, target, 60 * 60, 7, function(_, b)
			return Combat.isOutside(b, zone)
		end)
		t.truthy(Combat.isOutside(out, zone), `target should be KO'd within a minute, at {out.Percent}%`)
	end)

	t.test("doesn't follow a target off the edge", function()
		local me = settle(Fighter.new(ctx, 1, 40, 1))
		-- A target hovering past the right edge, out of reach.
		local target = Fighter.new(ctx, 2, 70, 20)
		local bot = Bot.new(3)
		for _ = 1, 240 do
			local intent
			intent, bot = Bot.decide(bot, me, target, ctx, config)
			me = Fighter.step(me, intent, ctx)
			target.Body.Y = 20 -- keep it floating there
			target.Body.VY = 0
		end
		t.eq(me.Body.Mode == "Air" and me.Body.Y < 0, false, "bot should still be on the stage")
		t.truthy(me.Body.X <= 55, `bot walked off the stage to x = {me.Body.X}`)
	end)

	t.test("recovers to the stage after being knocked off", function()
		-- Just past the right edge, level with the stage top, falling, with its double jump.
		local me = Fighter.new(ctx, 1, 62, 2)
		me.Body.VX = 0.3
		local target = settle(Fighter.new(ctx, 2, 0, 1))
		local zone = Combat.blastZone(ctx) :: any
		me = simulate(me, target, 300, 7, function(a)
			return a.Body.Mode == "Ground" or Combat.isOutside(a, zone)
		end)
		t.eq(me.Body.Mode, "Ground", "bot should land back on the stage")
	end)

	t.test("doesn't act while in hitstun", function()
		local me = settle(Fighter.new(ctx, 1, 0, 1))
		me.Hitstun = 30
		local target = settle(Fighter.new(ctx, 2, 3, 1))
		local intent = Bot.decide(Bot.new(1), me, target, ctx, config)
		t.eq(intent, Fighter.neutralIntent())
	end)

	t.test("same seed, same fight", function()
		local function run(seed: number): (number, number)
			local me = settle(Fighter.new(ctx, 1, -10, 1))
			local target = settle(Fighter.new(ctx, 2, 10, 1))
			local a, b = simulate(me, target, 600, seed)
			return a.Body.X, b.Percent
		end
		local x1, p1 = run(42)
		local x2, p2 = run(42)
		t.eq(x1, x2)
		t.eq(p1, p2)
	end)

	t.test("two bots can fight for a long time without errors", function()
		local a = settle(Fighter.new(ctx, 1, -10, 1))
		local b = settle(Fighter.new(ctx, 2, 10, 1))
		local botA, botB = Bot.new(11), Bot.new(99)
		local zone = Combat.blastZone(ctx) :: any
		local kos = 0
		for _ = 1, 60 * 120 do
			local ia, ib
			ia, botA = Bot.decide(botA, a, b, ctx, config)
			ib, botB = Bot.decide(botB, b, a, ctx, config)
			a = Fighter.step(a, ia, ctx)
			b = Fighter.step(b, ib, ctx)
			local list = Combat.resolveHits({ a, b }, ctx)
			a, b = list[1], list[2]
			if Combat.isOutside(a, zone) then
				a, kos = settle(Fighter.new(ctx, 1, -10, 1)), kos + 1
			end
			if Combat.isOutside(b, zone) then
				b, kos = settle(Fighter.new(ctx, 2, 10, 1)), kos + 1
			end
		end
		t.truthy(kos > 0, "two minutes of bot vs bot should produce at least one KO")
	end)
end
