--!strict
--[[
	Victim hit flash with a pooled Highlight (one per target, created on first flash, toggled
	after that, destroyed with the target).

	- White fill for N frames, then a fade through a red tint (report 2.4).
	- Strength follows the flashIntensity setting; 0 disables it.
	- reduceFlashing: no fill, only a brief outline colour change (report 1.9).
	- Never more than 3 flashes per second per target (WCAG 2.3.1); extra flashes are dropped.
]]

local TweenService = game:GetService("TweenService")

local Config = require("./Config")
local FlashLimiter = require("./FlashLimiter")
local Settings = require("../Settings/Settings")

local HitFlash = {}

type Entry = { highlight: Highlight, tween: Tween?, token: number, conn: RBXScriptConnection }

local entries: { [Instance]: Entry } = {}
local limiter = FlashLimiter.new(Config.Flash.maxPerSecondPerTarget, 1)

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function entryFor(target: Instance): Entry
	local entry = entries[target]
	if entry and entry.highlight.Parent then
		return entry
	end
	local h = Instance.new("Highlight")
	h.Name = "FeelHitFlash"
	h.Adornee = target
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.FillTransparency = 1
	h.OutlineTransparency = 1
	h.Enabled = false
	h.Parent = target
	local conn = target.Destroying:Connect(function()
		HitFlash.Release(target)
	end)
	local e: Entry = { highlight = h, tween = nil, token = 0, conn = conn }
	entries[target] = e
	return e
end

-- Flash `target` for `frames` 60 Hz frames. Returns true if a flash was shown.
function HitFlash.Flash(target: Instance?, frames: number): boolean
	if not target or not target.Parent then
		return false
	end
	local intensity: number = Settings.Get("flashIntensity")
	local reduced: boolean = Settings.Get("reduceFlashing")
	if intensity <= 0 and not reduced then
		return false
	end
	if not limiter:TryConsume(target, os.clock()) then
		return false
	end

	local entry = entryFor(target)
	local h = entry.highlight
	if entry.tween then
		entry.tween:Cancel()
	end
	entry.token += 1
	local token = entry.token
	local cfg = Config.Flash

	h.Enabled = true
	if reduced then
		h.FillTransparency = 1
		h.OutlineColor = rgb(cfg.reducedOutlineColor)
		h.OutlineTransparency = 1 - 0.8 * math.max(intensity, 0.5)
	else
		h.OutlineTransparency = 1
		h.FillColor = Color3.new(1, 1, 1)
		h.FillTransparency = 1 - (1 - cfg.fillTransparencyAtFull) * intensity
	end

	task.delay(frames / 60, function()
		if token ~= entry.token or not h.Parent then
			return
		end
		local goal = if reduced
			then { OutlineTransparency = 1 }
			else { FillTransparency = 1, FillColor = rgb(cfg.fadeColor) }
		local tween = TweenService:Create(h, TweenInfo.new(cfg.fadeSeconds), goal)
		entry.tween = tween
		tween.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed and token == entry.token then
				h.Enabled = false -- disabled Highlights still use a slot, but skip rendering
			end
		end)
		tween:Play()
	end)
	return true
end

-- Destroy the pooled Highlight for a target (called automatically when it is destroyed).
function HitFlash.Release(target: Instance)
	local entry = entries[target]
	if not entry then
		return
	end
	entries[target] = nil
	entry.conn:Disconnect()
	if entry.tween then
		entry.tween:Cancel()
	end
	entry.highlight:Destroy()
	limiter:Forget(target)
end

return HitFlash
