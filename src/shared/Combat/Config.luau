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

	-- Defense: shield, dodges and DI. Starting values from the calibration table in
	-- docs/research/mechanics-design-prompt.md. Dodges are intangible (attacks pass through)
	-- from frame Start to frame End.
	Defense = {
		ShieldMax = 55, -- shield health
		ShieldDrain = 0.12, -- health lost per frame while held
		ShieldRegen = 0.09, -- health regained per frame while not shielding
		ShieldDamageMultiplier = 1, -- shield health lost per % of damage blocked
		ShieldStunBase = 2, -- frames stuck in shield after blocking: base + damage * per
		ShieldStunPerDamage = 0.5,
		ShieldPushPerDamage = 0.03, -- studs per frame the blocker slides back, per % blocked
		ShieldDropLag = 7, -- frames after letting go of shield before acting
		ShieldBreakStun = 120, -- frames stunned when the shield breaks
		ShieldAfterBreak = 30, -- shield health once the stun wears off
		SpotDodge = { Start = 3, End = 17, Total = 26 },
		Roll = { Start = 4, End = 16, Total = 30, Speed = 0.4, MoveFrames = 16 },
		AirDodge = { Start = 3, End = 29, Total = 40, LandingLag = 10 },
		DIMaxDegrees = 14, -- holding sideways to the launch bends it by up to this much
	},
}
