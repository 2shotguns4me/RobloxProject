--!strict
--[[
	Rumble / haptics per hit tier.

	Primary: HapticEffect (gamepads and most modern phones). One Custom-waveform effect is
	pre-built per rumble definition and reused with :Play().
	Fallback: HapticService:SetMotor on Gamepad1, used only if HapticEffect can't be created.

	Rules (report 1.6): skip when the rumble setting is off; skip tiers marked mobile = false on
	touch; at most one rumble start per ~50 ms; when hits overlap, the stronger one wins
	(a weaker rumble never interrupts a stronger one still playing).
]]

local HapticService = game:GetService("HapticService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require("./Config")
local Settings = require("../Settings/Settings")

type Rumble = {
	durationMs: number,
	intensity: number,
	motor: "Small" | "Large" | "Both",
	mobile: boolean,
	waveform: { { number } }?,
}

local Haptics = {}

local effects: { [Rumble]: HapticEffect } = {}
local explosionEffect: HapticEffect? = nil
local hapticEffectAvailable: boolean? = nil
local folder: Folder? = nil

local lastStart = -math.huge
local activeUntil = -math.huge
local activeIntensity = 0
local motorToken = 0

local function getFolder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "FeelHaptics"
	f.Parent = Workspace -- HapticEffects are parented to Workspace (API docs)
	folder = f
	return f
end

local function isTouchOnly(): boolean
	local last = UserInputService:GetLastInputType()
	return last == Enum.UserInputType.Touch
end

local function waveformKeys(rumble: Rumble): { FloatCurveKey }
	local raw = rumble.waveform or { { 0, rumble.intensity }, { rumble.durationMs, 0 } }
	local keys = {}
	for _, k in raw do
		table.insert(keys, FloatCurveKey.new(k[1], k[2], Enum.KeyInterpolationMode.Linear))
	end
	return keys
end

local function createEffect(effectType: Enum.HapticEffectType, keys: { FloatCurveKey }?): HapticEffect?
	if hapticEffectAvailable == false then
		return nil
	end
	local ok, effect = pcall(function()
		local e = Instance.new("HapticEffect")
		e.Type = effectType
		if keys then
			e:SetWaveformKeys(keys)
		end
		e.Parent = getFolder()
		return e
	end)
	hapticEffectAvailable = ok
	return if ok then effect else nil
end

local function effectFor(rumble: Rumble): HapticEffect?
	local e = effects[rumble]
	if e and e.Parent then
		return e
	end
	local created = createEffect(Enum.HapticEffectType.Custom, waveformKeys(rumble))
	if created then
		effects[rumble] = created
	end
	return created
end

local function playMotorFallback(rumble: Rumble)
	local input = Enum.UserInputType.Gamepad1
	if not HapticService:IsVibrationSupported(input) then
		return
	end
	local motors: { Enum.VibrationMotor } = {}
	if rumble.motor == "Small" or rumble.motor == "Both" then
		table.insert(motors, Enum.VibrationMotor.Small)
	end
	if rumble.motor == "Large" or rumble.motor == "Both" then
		table.insert(motors, Enum.VibrationMotor.Large)
	end
	motorToken += 1
	local token = motorToken
	for _, m in motors do
		if HapticService:IsMotorSupported(input, m) then
			HapticService:SetMotor(input, m, rumble.intensity)
		end
	end
	task.delay(rumble.durationMs / 1000, function()
		if token ~= motorToken then
			return -- a newer rumble owns the motors
		end
		for _, m in motors do
			if HapticService:IsMotorSupported(input, m) then
				HapticService:SetMotor(input, m, 0)
			end
		end
	end)
end

-- Rate-limit + max-wins gate. Returns true if this rumble may start now.
local function admit(intensity: number, durationMs: number): boolean
	local now = os.clock()
	local overlapping = now < activeUntil
	if overlapping and intensity <= activeIntensity then
		return false
	end
	if now - lastStart < Config.Haptics.minIntervalSeconds and intensity <= activeIntensity then
		return false
	end
	lastStart = now
	activeUntil = now + durationMs / 1000
	activeIntensity = intensity
	return true
end

function Haptics.Play(rumble: Rumble?)
	if not rumble or not Settings.Get("rumble") then
		return
	end
	if not rumble.mobile and isTouchOnly() then
		return
	end
	if not admit(rumble.intensity, rumble.durationMs) then
		return
	end
	local effect = effectFor(rumble)
	if effect then
		effect:Play()
	else
		playMotorFallback(rumble)
	end
end

-- Blast-zone exit / explosions: the built-in GameplayExplosion preset.
function Haptics.PlayExplosion()
	if not Settings.Get("rumble") then
		return
	end
	if not admit(1, 400) then
		return
	end
	if not explosionEffect or not explosionEffect.Parent then
		explosionEffect = createEffect(Enum.HapticEffectType.GameplayExplosion, nil)
	end
	if explosionEffect then
		explosionEffect:Play()
	else
		playMotorFallback({ durationMs = 400, intensity = 1, motor = "Both", mobile = true })
	end
end

function Haptics.StopAll()
	for _, e in effects do
		e:Stop()
	end
	if explosionEffect then
		explosionEffect:Stop()
	end
	motorToken += 1
	local input = Enum.UserInputType.Gamepad1
	if hapticEffectAvailable == false and HapticService:IsVibrationSupported(input) then
		HapticService:SetMotor(input, Enum.VibrationMotor.Small, 0)
		HapticService:SetMotor(input, Enum.VibrationMotor.Large, 0)
	end
	activeUntil = -math.huge
	activeIntensity = 0
end

Settings.Changed:Connect(function(key, value)
	if key == "rumble" and value == false then
		Haptics.StopAll()
	end
end)

return Haptics
