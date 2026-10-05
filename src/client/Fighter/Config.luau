--!strict
return {
	-- Until blast zones and stocks exist, falling this far below the spawn point respawns you.
	FallRespawnDepth = 150,
	-- Used when the stage has no "StageSpawn" part (or it hasn't streamed in yet).
	FallbackSpawn = { X = 0, Y = 110 },
	-- If the game hitches, simulate at most this many frames at once and drop the rest.
	MaxStepsPerUpdate = 5,
}
