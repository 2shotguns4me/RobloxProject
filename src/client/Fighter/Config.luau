--!strict
return {
	-- Blast zones come from the stage (Combat/Config). With no stage parts yet, falling this
	-- far below the spawn point counts as a KO instead.
	FallRespawnDepth = 150,
	-- Used when the stage has no "StageSpawn" part (or it hasn't streamed in yet).
	FallbackSpawn = { X = 0, Y = 110 },
	-- If the game hitches, simulate at most this many frames at once and drop the rest.
	MaxStepsPerUpdate = 5,
	-- Blocked hits play the hit effects as if they did this fraction of the damage.
	BlockFeelScale = 0.4,

	-- Shield bubble (DefenseView): radius in studs at full and empty shield, and its colours.
	ShieldRadiusFull = 3.6,
	ShieldRadiusEmpty = 1.5,
	ShieldFullColor = Color3.fromRGB(120, 200, 255),
	ShieldEmptyColor = Color3.fromRGB(255, 70, 60),
	ShieldTransparency = 0.55,
	-- How see-through a fighter is while a dodge makes it intangible.
	DodgeTransparency = 0.6,
}
