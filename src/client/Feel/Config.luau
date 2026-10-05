--!strict
--[[
	Client feel tunables and asset references. Per-tier numbers live in
	ReplicatedStorage.Shared.Feel.HitTiers; this module holds everything else.

	Assets: no real IDs exist yet. Every ID below is an empty string, and empty means
	"silent / use the code-generated placeholder". Systems also look for assets by name
	under ReplicatedStorage.Assets.Sounds and ReplicatedStorage.Assets.VFX, so the team can
	drop an asset into Studio without touching code. Missing assets never error.
]]

local Config = {}

-- Trauma camera shake (Eiserloh). Report: ~0.6 studs translation, ~1.5 deg roll at trauma 1.
Config.Shake = {
	maxOffset = 0.6, -- studs at trauma 1
	maxRoll = math.rad(1.5), -- radians at trauma 1
	decayPerSecond = 1.2, -- linear trauma decay (report: 1.0-1.5)
	frequency = 25, -- noise samples per second
	exponent = 2, -- shake = trauma ^ exponent
	kickSeconds = 0.15, -- directional kick decay time
}

-- Phones make shake feel bigger on a small screen (report 2.8: ~0.6 on touch).
-- Applied on top of the screenShake setting (0.7 default * 0.85 ~= 0.6).
Config.TouchShakeMultiplier = 0.85

-- Sound layers. Each entry is a list of alternate asset IDs ("rbxassetid://123"); one is
-- picked at random per play. `AssetName` is the child looked up under Assets.Sounds: it may be
-- an AudioPlayer / Sound (its asset is used) or a Folder of them (alternates).
Config.Sounds = {
	Snap = { ids = { "" }, assetName = "HitSnap" },
	Body = { ids = { "" }, assetName = "HitBody" },
	Tail = { ids = { "" }, assetName = "HitTail" },
	KOSting = { ids = { "" }, assetName = "KOSting" },
	Dash = { ids = { "" }, assetName = "MoveDash" },
	Jump = { ids = { "" }, assetName = "MoveJump" },
	Land = { ids = { "" }, assetName = "MoveLand" },
} :: { [string]: { ids: { string }, assetName: string } }

Config.Audio = {
	voicesPerLayer = 4, -- pooled AudioPlayers per layer so overlapping hits don't cut off
	hitsBusVolume = 1,
	movementVolume = 0.35,
	movementPitchVariance = 0.08,
	duckAttackSeconds = 0.02,
	duckReleaseSeconds = 0.12,
	slowMoWorldPitch = 0.8, -- music pitch during KO slow-mo (report: 0.7-0.8)
}

-- VFX. Texture IDs empty = Roblox's default particle texture. Asset names are looked up under
-- Assets.VFX: a child Attachment/Folder holding ParticleEmitters is cloned instead of the placeholder.
Config.VFX = {
	poolSize = 8, -- round-robin spark/dust attachments
	sparkTexture = "",
	dustTexture = "",
	hitSparkAssetName = "HitSpark",
	dustAssetName = "Dust",
	sparkLifetime = { 0.15, 0.3 },
	sparkSpeed = { 18, 32 },
	sparkDrag = 8,
	sparkSize = 0.5, -- studs at scale 1
	dust = {
		Dash = { particles = 6, size = 1.2, speed = { 3, 6 }, lifetime = { 0.2, 0.35 } },
		Jump = { particles = 8, size = 1.1, speed = { 2, 5 }, lifetime = { 0.2, 0.3 } },
		Land = { particles = 10, size = 1.4, speed = { 4, 8 }, lifetime = { 0.25, 0.35 } },
	} :: { [string]: { particles: number, size: number, speed: { number }, lifetime: { number } } },
	dustColor = { 200, 195, 185 },
}

-- Highlight hit flash. Report 2.4: white fill ~0.2 transparency, then fade via red tint over 0.1 s.
Config.Flash = {
	fillTransparencyAtFull = 0.2, -- at flashIntensity 1
	fadeSeconds = 0.12,
	fadeColor = { 255, 90, 90 },
	reducedOutlineColor = { 255, 230, 120 }, -- "reduce flashing": outline change instead of fill
	maxPerSecondPerTarget = 3, -- WCAG 2.3.1
	screenMaxPerWindow = 1, -- full-screen tints: 1 per 0.5 s (report 1.9)
	screenWindowSeconds = 0.5,
}

-- Haptics. Report 1.6: max one rumble start per ~50 ms, take the max when overlapping.
Config.Haptics = {
	minIntervalSeconds = 0.05,
	blastZoneLocalOnly = true,
}

-- KO background tint (Lighting ColorCorrectionEffect).
Config.Tint = {
	koBrightness = -0.15,
	koSaturation = -0.3,
	finalTint = { 255, 120, 120 }, -- Smash "Finish Zoom" red
	reducedScale = 0.4, -- tint strength when reduceFlashing is on (and never red)
}

-- KO punch-in looks this far (0-1) toward the impact point (report 2.3: 20-40%).
Config.PunchLookAt = 0.3

return Config
