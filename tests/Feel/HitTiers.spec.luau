--!strict
local HitTiers = require("../../src/shared/Feel/HitTiers")

return function(t)
	t.test("hitstop base formula clamp(floor(d*0.5+3), 3, 20)", function()
		local cases = {
			{ 0, 3 },
			{ 1, 3 }, -- floor(3.5)
			{ 2, 4 },
			{ 3, 4 },
			{ 10, 8 },
			{ 15, 10 }, -- report's worked example
			{ 33, 19 },
			{ 34, 20 },
			{ 35, 20 }, -- capped
			{ 999, 20 },
			{ -10, 3 }, -- never below the minimum
		}
		for _, c in cases do
			local victim, attacker = HitTiers.hitstopFrames(c[1])
			t.eq(victim, c[2], `damage {c[1]}`)
			t.eq(attacker, c[2], `attacker freezes too at damage {c[1]}`)
		end
	end)

	t.test("NaN damage falls back to the minimum", function()
		local v = HitTiers.hitstopFrames(0 / 0)
		t.eq(v, 3)
	end)

	t.test("KO: x1.5, min 15 frames (0.25 s), max 24 frames (0.40 s)", function()
		t.eq((HitTiers.hitstopFrames(2, { isKO = true })), 15, "low damage KO lifts to the floor")
		t.eq((HitTiers.hitstopFrames(15, { isKO = true })), 15) -- 10 * 1.5
		t.eq((HitTiers.hitstopFrames(18, { isKO = true })), 18) -- 12 * 1.5
		t.eq((HitTiers.hitstopFrames(20, { isKO = true })), 20) -- 13 * 1.5 = 19.5 rounds up
		t.eq((HitTiers.hitstopFrames(100, { isKO = true })), 24, "capped at 0.40 s")
		t.near(HitTiers.framesToSeconds(15), 0.25, 1e-9)
		t.near(HitTiers.framesToSeconds(24), 0.40, 1e-9)
	end)

	t.test("electric multiplies by 1.5 after the KO clamp, hard cap 30", function()
		t.eq((HitTiers.hitstopFrames(10, { isElectric = true })), 12) -- 8 * 1.5
		t.eq((HitTiers.hitstopFrames(1, { isElectric = true })), 5) -- 3 * 1.5 = 4.5 -> 5
		t.eq((HitTiers.hitstopFrames(100, { isKO = true, isElectric = true })), 30) -- 24 * 1.5 = 36 -> cap
	end)

	t.test("projectile: attacker gets zero hitstop, victim unchanged", function()
		local victim, attacker = HitTiers.hitstopFrames(15, { isProjectile = true })
		t.eq(victim, 10)
		t.eq(attacker, 0)
		local kv, ka = HitTiers.hitstopFrames(15, { isProjectile = true, isKO = true })
		t.eq(kv, 15)
		t.eq(ka, 0)
	end)

	t.test("player count shortens hitstop for 3+ players only", function()
		t.eq((HitTiers.hitstopFrames(15, { playerCount = 2 })), 10)
		t.eq((HitTiers.hitstopFrames(15, { playerCount = 4 })), 9) -- 10 * 0.862
		t.eq((HitTiers.hitstopFrames(0, { playerCount = 8 })), 2) -- 3 * 0.75 = 2.25
		t.eq((HitTiers.hitstopFrames(0, { playerCount = 12 })), 2, "more than 8 uses the 8-player value")
	end)

	t.test("tierForDamage boundaries", function()
		t.eq(HitTiers.tierForDamage(0), "Light")
		t.eq(HitTiers.tierForDamage(1), "Light")
		t.eq(HitTiers.tierForDamage(6), "Light")
		t.eq(HitTiers.tierForDamage(6.5), "Medium")
		t.eq(HitTiers.tierForDamage(7), "Medium")
		t.eq(HitTiers.tierForDamage(12), "Medium")
		t.eq(HitTiers.tierForDamage(13), "Heavy")
		t.eq(HitTiers.tierForDamage(20), "Heavy")
		t.eq(HitTiers.tierForDamage(60), "Heavy")
		t.eq(HitTiers.tierForDamage(1, true), "KO", "KO overrides damage")
		t.eq(HitTiers.tierForDamage(30, false), "Heavy")
	end)

	t.test("tier table is complete and escalates", function()
		local prev = nil
		for _, name in HitTiers.Order do
			local tier = HitTiers.get(name)
			t.eq(tier.name, name)
			t.truthy(tier.cameraTrauma >= 0 and tier.cameraTrauma <= 1, `{name} trauma in [0,1]`)
			t.truthy(tier.victimRumble.intensity > 0 and tier.victimRumble.intensity <= 1, `{name} rumble in (0,1]`)
			t.truthy(tier.vfx.particles <= 30, `{name} stays within the mobile particle budget`)
			t.truthy(#tier.sound.layers >= 1, `{name} has sound layers`)
			if prev then
				t.truthy(tier.cameraTrauma > prev.cameraTrauma, `{name} trauma above {prev.name}`)
				t.truthy(tier.victimShakeStuds > prev.victimShakeStuds, `{name} shake above {prev.name}`)
				t.truthy(#tier.sound.layers >= #prev.sound.layers, `{name} has at least as many layers`)
			end
			prev = tier
		end
	end)

	t.test("get rejects unknown tiers", function()
		t.throws(function()
			HitTiers.get("Mega" :: any)
		end)
	end)

	t.test("formula output stays inside each tier's informational range", function()
		for damage = 1, 20 do
			local name = HitTiers.tierForDamage(damage)
			local range = HitTiers.get(name).hitstopFramesRange
			local frames = HitTiers.hitstopFrames(damage)
			t.truthy(frames >= range[1] and frames <= range[2], `damage {damage} ({name}) gave {frames}f`)
		end
	end)
end
