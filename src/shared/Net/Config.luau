--!strict
--[[
	Multiplayer tuning. Times are seconds (network timing is wall-clock, not simulation
	frames), distances are studs, speeds are studs per frame.
]]

return {
	-- Each client sends its fighter's state every this many 60 Hz frames (and every frame
	-- while attacking, so the server sees each attack).
	SendEveryFrames = 2,

	-- Other fighters are shown and hit-tested this far in the past, so there are always two
	-- received states to interpolate between. Roughly two send intervals plus jitter.
	InterpolationDelay = 0.1,

	-- How much state history the server (and each client) keeps per fighter.
	HistorySeconds = 1,

	-- The server rejects hit claims about moments older than this (caps lag compensation).
	MaxRewindSeconds = 0.35,
	-- ...or claimed to be in the future by more than this (clock jitter).
	FutureSlackSeconds = 0.05,

	-- Hitbox/hurtbox overlap checks on the server are this many studs more forgiving than the
	-- client's, to absorb interpolation differences.
	HitTolerance = 1.5,

	-- Extra seconds either side of an attack when the server looks for it in the attacker's
	-- history (states arrive only ~30 times a second).
	AttackSlackSeconds = 0.1,

	-- A claim can arrive before the state showing its attack (they travel separately); the
	-- server checks such a claim once more after this long.
	AttackRetrySeconds = 0.1,

	-- One attacker can't land hits on the same victim closer together than this. The fastest
	-- move (jab) takes about 0.23 s, so real play never gets near it.
	MinHitIntervalSeconds = 0.15,

	-- A KO report is accepted if the fighter was within this many studs of being outside the
	-- blast zone at some point in its recorded history.
	KOTolerance = 10,

	-- Sanity limits on state from clients; anything beyond is dropped.
	MaxPosition = 1e5,
	MaxSpeed = 50,
	MaxAttackFrame = 1000,
	MaxShield = 1000,
}
