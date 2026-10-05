--!strict
-- Unit tests for src/shared/Net/DefenseGuard. Run with: lune run tests/run DefenseGuard

local CombatConfig = require("../../src/shared/Combat/Config")
local Fighter = require("../../src/shared/Combat/Fighter")
local TestMoveset = require("../../src/shared/Combat/TestMoveset")
local MovementConfig = require("../../src/shared/Movement/Config")
local DefenseGuard = require("../../src/shared/Net/DefenseGuard")
local Snapshot = require("../../src/shared/Net/Snapshot")

local D = CombatConfig.Defense

local ctx: Fighter.Context = {
	Movement = MovementConfig,
	Combat = CombatConfig,
	Stage = { Solids = { { MinX = -55, MaxX = 55, MinY = -10, MaxY = 0 } }, Platforms = {} },
	Moveset = TestMoveset :: any,
}

local function snap(t: number, defense: string, frame: number): Snapshot.Snapshot
	local f = Fighter.new(ctx, 1, 0, 0)
	local s = Snapshot.fromFighter(f, t)
	s.Defense = defense
	s.DefenseFrame = frame
	return s
end

local function ghost(defense: Fighter.Defense?, frame: number): Fighter.State
	local f = Fighter.new(ctx, 1, 0, 0)
	f.Defense = defense
	f.DefenseFrame = frame
	return f
end

return function(t)
	t.test("a real dodge is intangible during its window, timed by the server", function()
		local g = DefenseGuard.new(ctx)
		DefenseGuard.observe(g, snap(10, "SpotDodge", 1), ctx)
		local w = D.SpotDodge
		local during = 10 + (w.Start + 1 - 1) / 60
		t.truthy(DefenseGuard.intangibleAt(g, ghost("SpotDodge", w.Start + 1), during, ctx), "inside the window")
		local after = 10 + (w.End + 3 - 1) / 60
		t.eq(DefenseGuard.intangibleAt(g, ghost("SpotDodge", w.End + 3), after, ctx), false, "after the window")
	end)

	t.test("a client stuck reporting the same dodge frame isn't intangible for long", function()
		local g = DefenseGuard.new(ctx)
		local w = D.SpotDodge
		for i = 0, 60 do
			DefenseGuard.observe(g, snap(10 + i / 30, "SpotDodge", w.Start + 1), ctx)
		end
		t.eq(DefenseGuard.intangibleAt(g, ghost("SpotDodge", w.Start + 1), 12, ctx), false)
	end)

	t.test("dodges started faster than they can really finish don't count", function()
		local g = DefenseGuard.new(ctx)
		DefenseGuard.observe(g, snap(10, "SpotDodge", 1), ctx)
		DefenseGuard.observe(g, snap(10.05, "", 0), ctx)
		DefenseGuard.observe(g, snap(10.1, "SpotDodge", 1), ctx) -- only 6 frames later
		t.eq(DefenseGuard.intangibleAt(g, ghost("SpotDodge", D.SpotDodge.Start), 10.1 + 5 / 60, ctx), false)
	end)

	t.test("a shield the server thinks is empty doesn't block", function()
		local g = DefenseGuard.new(ctx)
		local shieldGhost = ghost("Shield", 10)
		DefenseGuard.observe(g, snap(10, "Shield", 1), ctx)
		t.truthy(DefenseGuard.shieldBlocks(g, shieldGhost), "a fresh shield blocks")
		-- Reported as held for far longer than a shield lasts.
		DefenseGuard.observe(g, snap(10 + (D.ShieldMax / D.ShieldDrain) / 60 + 1, "Shield", 9999), ctx)
		t.eq(DefenseGuard.shieldBlocks(g, shieldGhost), false)
	end)

	t.test("blocked hits wear the server's shield down too, and it regenerates", function()
		local g = DefenseGuard.new(ctx)
		DefenseGuard.observe(g, snap(10, "Shield", 1), ctx)
		DefenseGuard.damageShield(g, D.ShieldMax)
		t.eq(DefenseGuard.shieldBlocks(g, ghost("Shield", 5)), false)
		DefenseGuard.observe(g, snap(10.1, "", 0), ctx)
		DefenseGuard.observe(g, snap(20, "Shield", 1), ctx)
		t.truthy(DefenseGuard.shieldBlocks(g, ghost("Shield", 1)), "regenerated after ten seconds down")
	end)

	t.test("a fighter not reporting a dodge is never intangible", function()
		local g = DefenseGuard.new(ctx)
		DefenseGuard.observe(g, snap(10, "", 0), ctx)
		t.eq(DefenseGuard.intangibleAt(g, ghost(nil, 0), 10, ctx), false)
	end)
end
