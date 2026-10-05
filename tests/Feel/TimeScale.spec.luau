--!strict
local TimeScale = require("../../src/shared/Feel/TimeScale")

return function(t)
	local function fakeClock()
		local now = 0
		return function()
			return now
		end, function(dt: number)
			now += dt
		end
	end

	t.test("defaults to 1", function()
		local clock = fakeClock()
		t.eq(TimeScale.new(clock):Get(), 1)
	end)

	t.test("slow-mo request applies for its real-time duration", function()
		local clock, advance = fakeClock()
		local ts = TimeScale.new(clock)
		ts:Request(0.25, 0.4)
		t.eq(ts:Get(), 0.25)
		advance(0.39)
		t.eq(ts:Get(), 0.25)
		advance(0.02)
		t.eq(ts:Get(), 1)
	end)

	t.test("overlapping requests take the slowest", function()
		local clock, advance = fakeClock()
		local ts = TimeScale.new(clock)
		ts:Request(0.5, 1)
		ts:Request(0.25, 0.2)
		t.eq(ts:Get(), 0.25)
		advance(0.3)
		t.eq(ts:Get(), 0.5)
	end)

	t.test("scale is clamped to [0, 1] and cancel works", function()
		local clock = fakeClock()
		local ts = TimeScale.new(clock)
		local id = ts:Request(-2, 1)
		t.eq(ts:Get(), 0)
		ts:Cancel(id)
		t.eq(ts:Get(), 1)
		ts:Request(5, 1)
		t.eq(ts:Get(), 1)
	end)

	t.test("Update fires Changed only on change", function()
		local clock, advance = fakeClock()
		local ts = TimeScale.new(clock)
		local events = {}
		ts.Changed:Connect(function(new, old)
			table.insert(events, { new, old })
		end)
		ts:Update()
		t.eq(#events, 0)
		ts:Request(0.25, 0.4)
		ts:Update()
		ts:Update()
		t.eq(#events, 1)
		t.eq(events[1][1], 0.25)
		t.eq(events[1][2], 1)
		advance(1)
		ts:Update()
		t.eq(#events, 2)
		t.eq(events[2][1], 1)
	end)
end
