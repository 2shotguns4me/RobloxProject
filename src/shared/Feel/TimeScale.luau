--!strict
--[[
	Global simulation time-scale requests (KO slow-mo). Pure; the clock is injectable.

	This is the seam between the feel layer and the future fixed-step simulation:
	the feel layer *requests* slow-mo, the simulation *reads* the scale and multiplies its
	step dt by it. Nothing here touches physics.

		local scale = timeScale:Get()        -- 1 normally, 0.25 during KO slow-mo
		timeScale.Changed:Connect(function(new, old) ... end)  -- fired by :Update()

	Overlapping requests take the minimum (slowest) scale. Durations are in real seconds.
	Per-fighter hitstop is NOT handled here; Feel.PlayHit returns the hitstop duration and
	the simulation freezes the involved fighters itself.
]]

local Signal = require("./Signal")

local TimeScale = {}
TimeScale.__index = TimeScale

type Request = { id: number, scale: number, endsAt: number }

export type TimeScale = {
	Changed: Signal.Signal<number, number>,
	Request: (self: TimeScale, scale: number, durationSeconds: number) -> number,
	Cancel: (self: TimeScale, id: number) -> (),
	Get: (self: TimeScale) -> number,
	Update: (self: TimeScale) -> number,
	Clear: (self: TimeScale) -> (),
}

function TimeScale.new(clock: (() -> number)?): TimeScale
	local self = setmetatable({
		Changed = Signal.new() :: Signal.Signal<number, number>,
		_clock = clock or os.clock,
		_requests = {} :: { Request },
		_nextId = 0,
		_last = 1,
	}, TimeScale)
	return (self :: any) :: TimeScale
end

-- Returns an id usable with :Cancel. Scale is clamped to [0, 1].
function TimeScale.Request(self: any, scale: number, durationSeconds: number): number
	self._nextId += 1
	local s = math.clamp(scale, 0, 1)
	table.insert(
		self._requests,
		{ id = self._nextId, scale = s, endsAt = self._clock() + math.max(0, durationSeconds) }
	)
	return self._nextId
end

function TimeScale.Cancel(self: any, id: number)
	for i, r in self._requests do
		if r.id == id then
			table.remove(self._requests, i)
			return
		end
	end
end

function TimeScale.Get(self: any): number
	local now = self._clock()
	local scale = 1
	local requests: { Request } = self._requests
	for i = #requests, 1, -1 do
		local r = requests[i]
		if now >= r.endsAt then
			table.remove(requests, i)
		elseif r.scale < scale then
			scale = r.scale
		end
	end
	return scale
end

-- Recomputes and fires Changed(new, old) when the value moved. Call once per frame.
function TimeScale.Update(self: any): number
	local scale = TimeScale.Get(self)
	if scale ~= self._last then
		local old = self._last
		self._last = scale
		self.Changed:Fire(scale, old)
	end
	return scale
end

function TimeScale.Clear(self: any)
	table.clear(self._requests)
end

return TimeScale
