--!strict
--[[
	Bot opponent tuning. Distances are studs, timing is 60 Hz frames, chances are 0-1.
	The bot is a testing partner, so it's deliberately easy. Lower the decision frames and
	raise the chances for a harder bot.
]]

return {
	-- How often the bot rethinks its plan (a random number of frames in this range). This is
	-- its reaction time: about 0.3-0.7 s.
	MinDecisionFrames = 18,
	MaxDecisionFrames = 42,

	-- Close enough to attack: horizontal and vertical distance between the two fighters' feet.
	AttackRangeX = 4.5,
	AttackRangeY = 3,

	-- Picking an attack when in range.
	SmashPercent = 90, -- prefers smashes once the target has at least this much damage
	SmashChance = 0.35, -- at or above SmashPercent
	TiltChance = 0.3, -- otherwise tilt instead of jab this often
	AerialChance = 0.25, -- jump and neutral-air a target that's above it and close
	AerialDelayFrames = 8, -- frames after jumping before the aerial

	-- Sometimes it just waits, so it isn't a perfect machine.
	IdleChance = 0.3,

	-- Stops this far from the edge rather than chasing a target off the stage.
	EdgeMargin = 4,

	-- Frames to hold jump for a full hop (must be longer than Movement's JumpSquat).
	FullHopHoldFrames = 8,
}
