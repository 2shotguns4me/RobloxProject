--!strict
--[[
	Pure framing math for the side-on 2.5D fighting camera (Smash-style).

	The camera looks down -Z at the stage plane. A frame is (x, y, distance): the point on
	the plane the camera centres on and how far back it sits. Points only need .X and .Y,
	so Vector3s work in Roblox and plain tables work in tests.

	computeTarget: fit every point plus padding, keep within [minDistance, maxDistance],
	never show past the stage bounds (zoom capped so the view fits; centre clamped).
	step: exponential smoothing toward a target, zooming out faster than in.
]]

local Framing = {}

export type Point = { X: number, Y: number }
export type Bounds = { minX: number, maxX: number, minY: number, maxY: number }
export type Frame = { x: number, y: number, distance: number }
export type FramingConfig = {
	fieldOfView: number,
	paddingX: number,
	paddingTop: number,
	paddingBottom: number,
	minDistance: number,
	maxDistance: number,
	followSpeed: number,
	zoomInSpeed: number,
	zoomOutSpeed: number,
}

local function tanHalf(fovDeg: number): number
	return math.tan(math.rad(fovDeg) / 2)
end

-- Half-width and half-height of the visible plane at `distance`.
function Framing.viewHalfExtents(distance: number, fovDeg: number, aspect: number): (number, number)
	local hh = distance * tanHalf(fovDeg)
	return hh * aspect, hh
end

-- Distance needed to show a half-width/half-height region.
function Framing.distanceFor(halfWidth: number, halfHeight: number, fovDeg: number, aspect: number): number
	local needHalfHeight = math.max(halfHeight, halfWidth / aspect)
	return needHalfHeight / tanHalf(fovDeg)
end

local function clampAxis(center: number, half: number, lo: number, hi: number): number
	if hi - lo <= half * 2 then
		return (lo + hi) / 2
	end
	return math.clamp(center, lo + half, hi - half)
end

-- Returns nil when there are no points (caller keeps its current frame).
function Framing.computeTarget(points: { Point }, cfg: FramingConfig, aspect: number, bounds: Bounds?): Frame?
	if #points == 0 then
		return nil
	end
	local minX, maxX = math.huge, -math.huge
	local minY, maxY = math.huge, -math.huge
	for _, p in points do
		minX = math.min(minX, p.X)
		maxX = math.max(maxX, p.X)
		minY = math.min(minY, p.Y)
		maxY = math.max(maxY, p.Y)
	end
	minX -= cfg.paddingX
	maxX += cfg.paddingX
	minY -= cfg.paddingBottom
	maxY += cfg.paddingTop

	local cx, cy = (minX + maxX) / 2, (minY + maxY) / 2
	local distance = Framing.distanceFor((maxX - minX) / 2, (maxY - minY) / 2, cfg.fieldOfView, aspect)
	local maxDistance = cfg.maxDistance
	if bounds then
		-- Never zoom out further than the whole stage-bounds rectangle.
		local fit = Framing.distanceFor((bounds.maxX - bounds.minX) / 2, 0, cfg.fieldOfView, aspect)
		local fitH = ((bounds.maxY - bounds.minY) / 2) / tanHalf(cfg.fieldOfView)
		maxDistance = math.min(maxDistance, math.min(fit, fitH))
	end
	distance = math.clamp(distance, cfg.minDistance, math.max(cfg.minDistance, maxDistance))

	local frame = { x = cx, y = cy, distance = distance }
	if bounds then
		return Framing.clampToBounds(frame, cfg, aspect, bounds)
	end
	return frame
end

-- Moves a frame's centre so its view stays inside `bounds` (centred if the view is larger).
function Framing.clampToBounds(frame: Frame, cfg: FramingConfig, aspect: number, bounds: Bounds): Frame
	local hw, hh = Framing.viewHalfExtents(frame.distance, cfg.fieldOfView, aspect)
	return {
		x = clampAxis(frame.x, hw, bounds.minX, bounds.maxX),
		y = clampAxis(frame.y, hh, bounds.minY, bounds.maxY),
		distance = frame.distance,
	}
end

-- Frame-rate independent exponential approach: fraction of the gap closed after dt.
function Framing.damp(current: number, target: number, speed: number, dt: number): number
	if dt <= 0 then
		return current
	end
	return target + (current - target) * math.exp(-speed * dt)
end

function Framing.step(current: Frame, target: Frame, cfg: FramingConfig, dt: number): Frame
	local zoomSpeed = if target.distance > current.distance then cfg.zoomOutSpeed else cfg.zoomInSpeed
	return {
		x = Framing.damp(current.x, target.x, cfg.followSpeed, dt),
		y = Framing.damp(current.y, target.y, cfg.followSpeed, dt),
		distance = Framing.damp(current.distance, target.distance, zoomSpeed, dt),
	}
end

return Framing
