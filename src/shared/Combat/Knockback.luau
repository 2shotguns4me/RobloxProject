--!strict
--[[
	Knockback math. Pure.

	Knockback uses Smash Ultimate's formula shape:

		kb = ((p/10 + p*d/20) * (200 / (w + 100)) * Multiplier + Flat) * (g / 100) + b

	p = victim's percent after the hit, d = damage, w = weight, g = knockback growth,
	b = base knockback. Knockback grows with percent, so the same attack sends a fighter
	further the more damage they've taken.
]]

local Knockback = {}

export type Config = {
	KnockbackMultiplier: number,
	KnockbackFlat: number,
	LaunchSpeedPerKnockback: number,
	HitstunPerKnockback: number,
}

function Knockback.compute(
	config: Config,
	percentAfterHit: number,
	damage: number,
	weight: number,
	baseKnockback: number,
	growth: number
): number
	local p = percentAfterHit
	local scaled = (p / 10 + p * damage / 20) * (200 / (weight + 100)) * config.KnockbackMultiplier
	return (scaled + config.KnockbackFlat) * (growth / 100) + baseKnockback
end

-- Launch velocity (studs per frame). angleDegrees: 0 = straight forward, 90 = straight up.
-- facing is the attacker's facing (1 = right, -1 = left).
function Knockback.launchVelocity(
	config: Config,
	knockback: number,
	angleDegrees: number,
	facing: number
): (number, number)
	local speed = knockback * config.LaunchSpeedPerKnockback
	local radians = math.rad(angleDegrees)
	return math.cos(radians) * speed * facing, math.sin(radians) * speed
end

function Knockback.hitstunFrames(config: Config, knockback: number): number
	return math.floor(knockback * config.HitstunPerKnockback)
end

return Knockback
