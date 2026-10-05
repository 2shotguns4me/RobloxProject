--!strict
return {
	-- Blast zones come from the stage (Combat/Config). With no stage parts yet, falling this
	-- far below the spawn point counts as a KO instead.
	FallRespawnDepth = 150,
	-- Used when the stage has no "StageSpawn" part (or it hasn't streamed in yet).
	FallbackSpawn = { X = 0, Y = 110 },
	-- If the game hitches, simulate at most this many frames at once and drop the rest.
	MaxStepsPerUpdate = 5,
}
