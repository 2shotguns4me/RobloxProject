--!strict
--[[
	Combat tuning: knockback, hitstun, attack buffering and blast zones. Distances are studs,
	timing is 60 Hz frames, speeds are studs per frame.

	The knockback formula uses Smash Ultimate's shape (see Knockback.luau); the constants
	below are its coefficients. Starting values follow docs/research/mechanics-design-prompt.md.
]]

return {
	-- Knockback formula coefficients
	KnockbackMultiplier = 1.4,
	KnockbackFlat = 18,
	DefaultWeight = 100, -- higher = flies less far

	-- Launch speed is knockback * this, in studs per frame. With LaunchDecay below, the test
	-- moveset's side smash KOs a weight-100 fighter from mid-stage on the test stage at
	-- about 95%; a tilt needs well over 200%.
	LaunchSpeedPerKnockback = 0.012,

	-- Studs per frame of horizontal launch speed lost each frame of hitstun (Smash uses a
	-- fixed decay too), so travel grows with the square of knockback, not without limit.
	LaunchDecay = 0.017,

	-- Hitstun frames = knockback * this (research baseline 0.38, range 0.30-0.45).
	HitstunPerKnockback = 0.38,

	-- An attack pressed this many frames early (during landing lag, jump squat, hitstop)
	-- still comes out.
	AttackBuffer = 9,

	-- Landing lag for an aerial that doesn't set its own.
	DefaultAerialLandingLag = 10,

	-- Blast zones: how far past the outermost stage parts a fighter must go to be KO'd.
	BlastZone = {
		Side = 60,
		Top = 80,
		Bottom = 50,
	},
}
