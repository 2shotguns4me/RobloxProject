--!strict
--[[
	Feel: one entry point for hit, KO and movement juice. Client-only, cosmetic only.

		local frames, result = Feel.PlayHit({
			position = contactPoint, victim = victimModel, damage = 14, isKO = false,
			direction = launchDir, attackerIsLocal = true, victimIsLocal = false,
		})
		-- freeze the victim for `frames` 60 Hz frames, the attacker for result.attackerFrames

		Feel.GetTimeScale()            -- 1, or 0.25 during KO slow-mo; multiply sim dt by this
		Feel.TimeScaleChanged:Connect(function(new, old) end)
		Feel.GetVisualOffset(victimModel)  -- add to the victim's *visual* root during hitstop

	The simulation owns hitstop: PlayHit only computes and returns it. Slow-mo is only a
	request on Feel.TimeScale; nothing here touches physics. Every effect is wrapped so a
	failure in one (e.g. a missing API on some device) never blocks the others.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local SharedFeel = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Feel")
local HitTiers = require(SharedFeel:WaitForChild("HitTiers"))
local Envelope = require(SharedFeel:WaitForChild("Envelope"))
local Signal = require(SharedFeel:WaitForChild("Signal"))
local TimeScaleClass = require(SharedFeel:WaitForChild("TimeScale"))

local CameraShake = require("./CameraShake")
local Config = require("./Config")
local FlashLimiter = require("./FlashLimiter")
local Haptics = require("./Haptics")
local HitFlash = require("./HitFlash")
local HitSpark = require("./HitSpark")
local ImpactAudio = require("./ImpactAudio")
local FightCamera = require("../Camera/FightCamera")
local Settings = require("../Settings/Settings")

export type HitParams = {
	position: Vector3,
	victim: Instance?, -- Model (or part) to flash/shake; nil for spectator-only effects
	damage: number,
	isKO: boolean?,
	direction: Vector3?, -- launch direction; aims the spark and the camera kick
	attackerIsLocal: boolean,
	victimIsLocal: boolean,
	isProjectile: boolean?, -- attacker gets no hitstop
	isElectric: boolean?, -- x1.5 hitstop
	victimAirborne: boolean?, -- victim shake is vertical in the air, horizontal on the ground
	playerCount: number?, -- 3+ players shortens hitstop (Smash FFA rule)
	isFinalKO: boolean?, -- game-winning KO: red "Finish Zoom" tint
}

export type HitResult = {
	tier: HitTiers.TierName,
	victimFrames: number,
	attackerFrames: number,
	victimSeconds: number,
	attackerSeconds: number,
}

export type KOParams = {
	position: Vector3,
	direction: Vector3?,
	isFinal: boolean?,
}

export type MovementKind = "Dash" | "Jump" | "Land"
export type MovementOptions = { direction: Vector3?, intensity: number? }

type ShakeEntry = { started: number, duration: number, amplitude: number, airborne: boolean }

local Feel = {}

Feel.TimeScale = TimeScaleClass.new()
Feel.TimeScaleChanged = Feel.TimeScale.Changed
-- Fired after every PlayHit; UI (damage % pop) and debug tools can listen.
Feel.HitPlayed = Signal.new() :: Signal.Signal<HitParams, HitResult>

local shake = CameraShake.new()
local victimShakes: { [Instance]: ShakeEntry } = setmetatable({}, { __mode = "k" }) :: any
local screenLimiter = FlashLimiter.new(Config.Flash.screenMaxPerWindow, Config.Flash.screenWindowSeconds)
local tintEffect: ColorCorrectionEffect? = nil
local initialized = false

local function safe(label: string, fn: (...any) -> (), ...: any)
	local ok, err = pcall(fn, ...)
	if not ok then
		warn(`[Feel] {label} failed: {err}`)
	end
end

local function shakeMultiplier(): number
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	return if touch then Config.TouchShakeMultiplier else 1
end

function Feel.Init()
	if initialized then
		return
	end
	initialized = true
	Settings.Observe("screenShake", function(value)
		shake:SetScale(value * shakeMultiplier())
	end)
	FightCamera.SetShakeSource(shake)
	FightCamera.SetPunchLookAt(Config.PunchLookAt)
	RunService.Heartbeat:Connect(function()
		Feel.TimeScale:Update()
	end)
end

function Feel.GetShake(): CameraShake.CameraShake
	return shake
end

function Feel.GetTimeScale(): number
	return Feel.TimeScale:Get()
end

-- Victim hitstop shake offset (studs) for `target` right now; Vector3.zero when not shaking.
function Feel.GetVisualOffset(target: Instance): Vector3
	local entry = victimShakes[target]
	if not entry then
		return Vector3.zero
	end
	local elapsed = os.clock() - entry.started
	if elapsed >= entry.duration then
		victimShakes[target] = nil
		return Vector3.zero
	end
	local dx, dy = Envelope.victimShake(entry.amplitude, elapsed, entry.duration, entry.airborne)
	return Vector3.new(dx, dy, 0)
end

local function getTint(): ColorCorrectionEffect
	if tintEffect and tintEffect.Parent then
		return tintEffect
	end
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "FeelTint"
	cc.Parent = Lighting
	tintEffect = cc
	return cc
end

local function playTint(isFinal: boolean)
	local intensity: number = Settings.Get("flashIntensity")
	local reduced: boolean = Settings.Get("reduceFlashing")
	if intensity <= 0 and not reduced then
		return
	end
	if not screenLimiter:TryConsume("screen", os.clock()) then
		return
	end
	local strength = if reduced then Config.Tint.reducedScale else intensity
	local cc = getTint()
	local hold = if isFinal then HitTiers.KO.finalTintSeconds else HitTiers.KO.tintSeconds
	cc.Brightness = Config.Tint.koBrightness * strength
	cc.Saturation = Config.Tint.koSaturation * strength
	-- Saturated red full-screen flashes are the riskiest kind; never with reduceFlashing.
	if isFinal and not reduced then
		local red = Config.Tint.finalTint
		cc.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(red[1], red[2], red[3]), strength)
	else
		cc.TintColor = Color3.new(1, 1, 1)
	end
	task.delay(hold, function()
		TweenService:Create(cc, TweenInfo.new(0.15), {
			Brightness = 0,
			Saturation = 0,
			TintColor = Color3.new(1, 1, 1),
		}):Play()
	end)
end

--[[
	KO signature: slow-mo request + zoom punch toward the impact + background tint + music
	pitch-down. Slow-mo and zoom respect the slowMo setting; the tint respects the flash settings.
	Called by PlayHit when isKO is set; call directly only for KOs without a hit (e.g. self-destruct).
]]
function Feel.PlayKO(params: KOParams)
	Feel.Init()
	local ko = HitTiers.KO
	local tier = HitTiers.get("KO")
	if Settings.Get("slowMo") then
		Feel.TimeScale:Request(ko.slowMoScale, ko.slowMoSeconds)
		safe(
			"KO punch",
			FightCamera.Punch,
			tier.fovPunch,
			tier.punchInSeconds,
			ko.slowMoSeconds,
			tier.punchOutSeconds,
			params.position
		)
		safe("KO pitch", ImpactAudio.SetWorldPitch, Config.Audio.slowMoWorldPitch, ko.slowMoSeconds)
	end
	safe("KO tint", playTint, params.isFinal == true)
end

--[[
	Plays every hit effect for one confirmed or predicted hit and returns the hitstop:
	(victimFrames, result). Frames are 60 Hz; result also has seconds and attacker frames.
]]
function Feel.PlayHit(params: HitParams): (number, HitResult)
	Feel.Init()
	local isKO = params.isKO == true
	local tierName = HitTiers.tierForDamage(params.damage, isKO)
	local tier = HitTiers.get(tierName)
	local victimFrames, attackerFrames = HitTiers.hitstopFrames(params.damage, {
		isKO = isKO,
		isElectric = params.isElectric,
		isProjectile = params.isProjectile,
		playerCount = params.playerCount,
	})
	local result: HitResult = {
		tier = tierName,
		victimFrames = victimFrames,
		attackerFrames = attackerFrames,
		victimSeconds = HitTiers.framesToSeconds(victimFrames),
		attackerSeconds = HitTiers.framesToSeconds(attackerFrames),
	}

	safe("spark", HitSpark.Play, params.position, tier.vfx, params.direction)
	safe("audio", ImpactAudio.PlayHit, tier.sound)

	local victim = params.victim
	if victim then
		safe("flash", HitFlash.Flash, victim, tier.vfx.flashFrames)
		victimShakes[victim] = {
			started = os.clock(),
			duration = result.victimSeconds,
			amplitude = tier.victimShakeStuds,
			airborne = params.victimAirborne == true,
		}
	end

	shake:AddTrauma(tier.cameraTrauma)
	local dir = params.direction
	if dir and tier.kickStuds > 0 then
		shake:Kick(dir.X, dir.Y, tier.kickStuds)
	end
	if not isKO and tier.fovPunch > 0 then
		-- Non-KO punches are camera motion, so they follow the screen-shake slider.
		local fraction = tier.fovPunch * shake:GetScale()
		safe(
			"punch",
			FightCamera.Punch,
			fraction,
			tier.punchInSeconds,
			tier.punchHoldSeconds,
			tier.punchOutSeconds,
			nil
		)
	end

	if params.victimIsLocal then
		safe("rumble", Haptics.Play, tier.victimRumble)
	end
	if params.attackerIsLocal then
		safe("rumble", Haptics.Play, tier.attackerRumble)
	end

	if isKO then
		Feel.PlayKO({ position = params.position, direction = dir, isFinal = params.isFinalKO })
	end

	Feel.HitPlayed:Fire(params, result)
	return victimFrames, result
end

-- Fighter crossed the blast zone: full trauma burst, big spark, explosion haptic.
function Feel.PlayBlastZoneExit(position: Vector3, direction: Vector3?, localInvolved: boolean)
	Feel.Init()
	shake:AddTrauma(HitTiers.KO.blastZoneTrauma)
	safe("blast spark", HitSpark.Play, position, HitTiers.get("KO").vfx, direction)
	if localInvolved then
		safe("blast rumble", Haptics.PlayExplosion)
	end
end

-- Dash / jump / land dust (+ movement sound if an asset exists).
function Feel.PlayMovement(kind: MovementKind, position: Vector3, opts: MovementOptions?)
	Feel.Init()
	local o: MovementOptions = opts or {}
	safe("dust", HitSpark.PlayDust, kind, position, o.direction, o.intensity)
	safe("move audio", ImpactAudio.PlayMovement, kind, o.intensity)
end

return Feel
