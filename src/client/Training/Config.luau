--!strict
return {
	Enabled = true, -- spawn an opponent next to you
	-- "Bot" fights back (tuning in src/shared/Bot/Config.luau); "Dummy" just stands there.
	Opponent = "Bot",
	SpawnOffsetX = 20, -- studs to the right of the spawn point
	Color = Color3.fromRGB(230, 150, 60),
	Depth = 2, -- studs, along the camera axis (looks only)
}
