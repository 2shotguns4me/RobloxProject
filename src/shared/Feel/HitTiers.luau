--!strict
-- Hit tiers (Light / Medium / Heavy / KO) and the hitstop formula.
--
-- Pure data + math: no Roblox services or datatypes, so it runs under Lune and can be
-- shared by the client feel layer and the (future) fixed-step simulation.
--
-- Source: docs/research/game-feel.md, "Hit tier table (starting values)" and
-- "Hitstop formula". Every number here is a first tuning pass; change them here, not
-- in the systems that read them. Timing is in 60 Hz frames unless a name says Seconds/Ms.

local HitTiers = {}

HitTiers.FPS = 60

export type TierName = "Light" | "Medium" | "Heavy" | "KO"

-- One rumble pulse. `waveform` (optional) is a list of {timeMs, intensity 0-1} keys for a
-- HapticEffect custom waveform; without it Haptics builds a simple spike-then-decay.
-- `motor` is used only by the legacy HapticService fallback (gamepad motors).
export type Rumble = {
	durationMs: number,
	intensity: number,
	motor: "Small" | "Large" | "Both",
	mobile: boolean, -- phones are coarse; light tiers skip them (report 1.6)
	waveform: { { number } }?,
}

export type SoundSpec = {
	layers: { string }, -- layer names, looked up in the client Feel Config / Assets.Sounds
	pitchVariance: number, -- +/- fraction applied to PlaybackSpeed per layer
	volume: number,
	lowGainDb: number, -- extra low end on the voice equalizer
	duckDb: number, -- music duck depth (0 = no duck)
	duckSeconds: number,
}

export type VfxSpec = {
	scale: number, -- spark size multiplier
	particles: number, -- burst count (keep <= 30 for mobile, report 2.8)
	color: { number }, -- {r, g, b} 0-255 (Color3 is not available in pure code)
	flashFrames: number, -- Highlight white-flash hold
}

export type Tier = {
	name: TierName,
	hitstopFramesRange: { number }, -- informational: what the formula yields for the tier's damage band
	victimShakeStuds: number, -- victim visual shake amplitude during hitstop
	cameraTrauma: number, -- added to the camera trauma pool (0-1)
	fovPunch: number, -- fraction of FOV to punch in (0.05 = 5%)
	punchInSeconds: number,
	punchHoldSeconds: number,
	punchOutSeconds: number,
	kickStuds: number, -- directional camera kick along the launch direction
	victimRumble: Rumble,
	attackerRumble: Rumble?,
	sound: SoundSpec,
	vfx: VfxSpec,
}

HitTiers.Order = { "Light", "Medium", "Heavy", "KO" } :: { TierName }

HitTiers.Tiers = {
	Light = {
		name = "Light",
		hitstopFramesRange = { 3, 6 }, -- report says 3-5; the formula gives 6 at 6%
		victimShakeStuds = 0.10,
		cameraTrauma = 0.12, -- report: 0.10-0.15, barely visible after squaring
		fovPunch = 0,
		punchInSeconds = 0,
		punchHoldSeconds = 0,
		punchOutSeconds = 0,
		kickStuds = 0,
		victimRumble = { durationMs = 60, intensity = 0.25, motor = "Small", mobile = false },
		attackerRumble = { durationMs = 40, intensity = 0.15, motor = "Small", mobile = false },
		sound = {
			layers = { "Snap" },
			pitchVariance = 0.10,
			volume = 0.5,
			lowGainDb = 0,
			duckDb = 0,
			duckSeconds = 0,
		},
		vfx = { scale = 0.6, particles = 10, color = { 255, 250, 220 }, flashFrames = 1 },
	} :: Tier,

	Medium = {
		name = "Medium",
		hitstopFramesRange = { 6, 9 }, -- report says 5-8; formula output for 7-12%
		victimShakeStuds = 0.20,
		cameraTrauma = 0.30, -- report: 0.25-0.35
		fovPunch = 0.025, -- report: none or 2-3%
		punchInSeconds = 0.06,
		punchHoldSeconds = 0,
		punchOutSeconds = 0.2,
		kickStuds = 0,
		victimRumble = { durationMs = 100, intensity = 0.5, motor = "Both", mobile = true },
		attackerRumble = { durationMs = 60, intensity = 0.3, motor = "Small", mobile = true },
		sound = {
			layers = { "Snap", "Body" },
			pitchVariance = 0.07,
			volume = 0.7,
			lowGainDb = 1.5,
			duckDb = 0,
			duckSeconds = 0,
		},
		vfx = { scale = 1.0, particles = 18, color = { 255, 220, 120 }, flashFrames = 2 },
	} :: Tier,

	Heavy = {
		name = "Heavy",
		hitstopFramesRange = { 9, 13 }, -- formula output for 13-20%
		victimShakeStuds = 0.35,
		cameraTrauma = 0.52, -- report: 0.45-0.6
		fovPunch = 0.05, -- report: 4-6%, ease back over 0.25 s
		punchInSeconds = 0.06,
		punchHoldSeconds = 0,
		punchOutSeconds = 0.25,
		kickStuds = 0.3, -- report: 0.2-0.5 toward launch direction on heavy/KO
		victimRumble = {
			durationMs = 180,
			intensity = 0.8,
			motor = "Large",
			mobile = true,
			waveform = { { 0, 0.85 }, { 60, 0.5 }, { 180, 0 } },
		},
		attackerRumble = { durationMs = 100, intensity = 0.5, motor = "Large", mobile = true },
		sound = {
			layers = { "Snap", "Body", "Tail" },
			pitchVariance = 0.05,
			volume = 0.9,
			lowGainDb = 3,
			duckDb = -4,
			duckSeconds = 0.15,
		},
		vfx = { scale = 1.5, particles = 26, color = { 255, 140, 60 }, flashFrames = 3 },
	} :: Tier,

	KO = {
		name = "KO",
		hitstopFramesRange = { 15, 24 },
		victimShakeStuds = 0.45,
		cameraTrauma = 0.8, -- plus a separate 1.0 burst on blast-zone exit
		fovPunch = 0.12, -- report: zoom 10-15% toward impact over 0.08 s, return 0.35 s
		punchInSeconds = 0.08,
		punchHoldSeconds = 0.4, -- held during slow-mo
		punchOutSeconds = 0.35,
		kickStuds = 0.5,
		victimRumble = {
			durationMs = 300,
			intensity = 1.0,
			motor = "Large",
			mobile = true,
			waveform = { { 0, 1.0 }, { 80, 0.6 }, { 200, 0.3 }, { 300, 0 } },
		},
		attackerRumble = {
			durationMs = 300,
			intensity = 1.0,
			motor = "Large",
			mobile = true,
			waveform = { { 0, 1.0 }, { 80, 0.6 }, { 200, 0.3 }, { 300, 0 } },
		},
		sound = {
			layers = { "KOSting", "Snap", "Body", "Tail" },
			pitchVariance = 0.05,
			volume = 1.0,
			lowGainDb = 4,
			duckDb = -6, -- report wants a 0.4 s low-pass of the mix; a deeper duck stands in for now
			duckSeconds = 0.4,
		},
		vfx = { scale = 2.0, particles = 30, color = { 255, 80, 200 }, flashFrames = 3 },
	} :: Tier,
} :: { [TierName]: Tier }

-- KO sequence tunables (slow-mo, background tint). Report: slow-mo 0.25x for 0.35-0.5 s.
HitTiers.KO = {
	slowMoScale = 0.25,
	slowMoSeconds = 0.4,
	tintSeconds = 0.1, -- non-final KO: background darken
	finalTintSeconds = 0.4, -- game-winning KO: red tint held through slow-mo
	blastZoneTrauma = 1.0,
}

-- Upper damage bound (inclusive) for each non-KO tier. Report: 1-6 light, 7-12 medium, 13-20 heavy.
HitTiers.LightMaxDamage = 6
HitTiers.MediumMaxDamage = 12

-- Hitstop formula constants.
HitTiers.Hitstop = {
	perDamage = 0.5,
	base = 3,
	minFrames = 3,
	maxFrames = 20,
	koMultiplier = 1.5,
	koMinFrames = 15, -- 0.25 s
	koMaxFrames = 24, -- 0.40 s
	electricMultiplier = 1.5,
	hardCapFrames = 30, -- Smash's cap; only reachable by electric KO hits
	-- Smash Ultimate scales hitlag down with player count so FFAs don't stutter.
	-- [unverified] values beyond 3 players are from memory of SmashWiki: Hitlag; re-check.
	playerCountMultiplier = { [3] = 0.925, [4] = 0.862, [5] = 0.8, [6] = 0.75, [7] = 0.75, [8] = 0.75 } :: { [number]: number },
}

local function clamp(x: number, lo: number, hi: number): number
	if x < lo then
		return lo
	elseif x > hi then
		return hi
	end
	return x
end

local function round(x: number): number
	return math.floor(x + 0.5)
end

function HitTiers.tierForDamage(damage: number, isKO: boolean?): TierName
	if isKO then
		return "KO"
	end
	if damage <= HitTiers.LightMaxDamage then
		return "Light"
	elseif damage <= HitTiers.MediumMaxDamage then
		return "Medium"
	end
	return "Heavy"
end

function HitTiers.get(name: TierName): Tier
	local tier = HitTiers.Tiers[name]
	assert(tier, `unknown hit tier {name}`)
	return tier
end

export type HitstopOptions = {
	isKO: boolean?,
	isElectric: boolean?,
	isProjectile: boolean?,
	playerCount: number?,
}

--[[
	Returns (victimFrames, attackerFrames), both whole 60 Hz frames.

	frames = clamp(floor(damage * 0.5 + 3), 3, 20)
	KO:        frames = clamp(round(frames * 1.5), 15, 24)
	electric:  frames = round(frames * 1.5)
	players:   frames = max(1, round(frames * multiplier)) for 3+ players
	projectile: attacker frames = 0 (only the projectile freezes, as in Smash)
]]
function HitTiers.hitstopFrames(damage: number, opts: HitstopOptions?): (number, number)
	local o: HitstopOptions = opts or {}
	local h = HitTiers.Hitstop
	local d = if damage ~= damage then 0 else damage -- NaN guard
	local frames = clamp(math.floor(d * h.perDamage + h.base), h.minFrames, h.maxFrames)

	if o.isKO then
		frames = clamp(round(frames * h.koMultiplier), h.koMinFrames, h.koMaxFrames)
	end
	if o.isElectric then
		frames = round(frames * h.electricMultiplier)
	end
	local count = o.playerCount
	if count then
		local mult = h.playerCountMultiplier[math.min(count, 8)]
		if mult then
			frames = math.max(1, round(frames * mult))
		end
	end
	frames = math.min(frames, h.hardCapFrames)

	local attackerFrames = if o.isProjectile then 0 else frames
	return frames, attackerFrames
end

function HitTiers.framesToSeconds(frames: number): number
	return frames / HitTiers.FPS
end

return HitTiers
