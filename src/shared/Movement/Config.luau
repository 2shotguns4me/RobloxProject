--!strict
--[[
	Movement tuning. Distances are studs, timing is 60 Hz frames, so speeds are
	studs per frame (multiply by 60 for studs per second).

	Starting values follow the "baseline example" column of the calibration table in
	docs/research/mechanics-design-prompt.md, with 1 SU (character height) = 5 studs.
	Per-fighter overrides come later, from each character's data file.
]]

return {
	-- Body (feet at the fighter's position)
	BodyHalfWidth = 1,
	BodyHeight = 5,

	-- Stick
	StickDeadzone = 0.2, -- below this the stick counts as neutral
	RunThreshold = 0.7, -- at or above this the fighter runs instead of walks
	DownThreshold = 0.6, -- how far down counts as "down" (fast-fall, drop through)

	-- Ground
	WalkSpeed = 0.25, -- 15 studs/s
	RunSpeed = 0.5, -- 30 studs/s
	GroundAccel = 0.05,
	GroundFriction = 0.04,

	-- Jumps
	JumpSquat = 4, -- frames on the ground before leaving it
	FullHopHeight = 12,
	ShortHopHeight = 6.6, -- 55% of a full hop; jump released during jump squat
	DoubleJumpHeight = 10.8, -- 90% of a full hop
	AirJumps = 1,

	-- Air
	Gravity = 0.042, -- full hop reaches its apex in about 24 frames
	MaxFallSpeed = 0.8,
	FastFallSpeed = 1.16, -- 1.45x max fall speed
	AirSpeed = 0.4,
	AirAccel = 0.025,
	AirFriction = 0.01,

	-- Timing
	LandingLag = 3, -- frames after landing before acting again
	JumpBuffer = 9, -- a jump pressed this many frames early still comes out
	DropThroughFrames = 12, -- frames pass-through platforms are ignored after dropping
}
