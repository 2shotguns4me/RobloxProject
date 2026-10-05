--!strict
--[[
	Sliding-window rate limiter for flashes (WCAG 2.3.1: never more than 3 flashes in any
	1-second window). Pure; pass `now` in seconds. Keys are any value (e.g. a victim Model).

		local limiter = FlashLimiter.new(3, 1)
		if limiter:TryConsume(model, os.clock()) then flash() end
]]

local FlashLimiter = {}
FlashLimiter.__index = FlashLimiter

export type FlashLimiter = {
	TryConsume: (self: FlashLimiter, key: any, now: number) -> boolean,
	Count: (self: FlashLimiter, key: any, now: number) -> number,
	Forget: (self: FlashLimiter, key: any) -> (),
}

function FlashLimiter.new(maxCount: number, windowSeconds: number): FlashLimiter
	local self = setmetatable({
		_max = maxCount,
		_window = windowSeconds,
		_stamps = setmetatable({}, { __mode = "k" }) :: { [any]: { number } },
	}, FlashLimiter)
	return (self :: any) :: FlashLimiter
end

local function prune(stamps: { number }, now: number, window: number)
	-- A flash at time s is inside the window while now - s < window.
	while #stamps > 0 and now - stamps[1] >= window do
		table.remove(stamps, 1)
	end
end

function FlashLimiter.Count(self: any, key: any, now: number): number
	local stamps = self._stamps[key]
	if not stamps then
		return 0
	end
	prune(stamps, now, self._window)
	return #stamps
end

function FlashLimiter.TryConsume(self: any, key: any, now: number): boolean
	local stamps = self._stamps[key]
	if not stamps then
		stamps = {}
		self._stamps[key] = stamps
	end
	prune(stamps, now, self._window)
	if #stamps >= self._max then
		return false
	end
	table.insert(stamps, now)
	return true
end

function FlashLimiter.Forget(self: any, key: any)
	self._stamps[key] = nil
end

return FlashLimiter
