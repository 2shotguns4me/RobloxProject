--!strict
local FlashLimiter = require("../../src/client/Feel/FlashLimiter")

return function(t)
	t.test("never more than 3 flashes in any 1 s window per target", function()
		local l = FlashLimiter.new(3, 1)
		local a = {}
		t.truthy(l:TryConsume(a, 0.0))
		t.truthy(l:TryConsume(a, 0.1))
		t.truthy(l:TryConsume(a, 0.2))
		t.eq(l:TryConsume(a, 0.3), false, "4th in the window is dropped")
		t.eq(l:TryConsume(a, 0.99), false)
		t.truthy(l:TryConsume(a, 1.0), "first flash left the window")
		t.eq(l:Count(a, 1.0), 3)
	end)

	t.test("dropped flashes do not count", function()
		local l = FlashLimiter.new(3, 1)
		local a = {}
		for i = 0, 9 do
			l:TryConsume(a, i * 0.05)
		end
		t.eq(l:Count(a, 0.5), 3)
		t.truthy(l:TryConsume(a, 1.0))
	end)

	t.test("targets are independent", function()
		local l = FlashLimiter.new(3, 1)
		local a, b = {}, {}
		for _ = 1, 3 do
			l:TryConsume(a, 0)
		end
		t.eq(l:TryConsume(a, 0), false)
		t.truthy(l:TryConsume(b, 0))
	end)

	t.test("screen limiter: 1 per 0.5 s", function()
		local l = FlashLimiter.new(1, 0.5)
		t.truthy(l:TryConsume("screen", 0))
		t.eq(l:TryConsume("screen", 0.49), false)
		t.truthy(l:TryConsume("screen", 0.5))
	end)

	t.test("Forget resets a target", function()
		local l = FlashLimiter.new(1, 1)
		local a = {}
		l:TryConsume(a, 0)
		l:Forget(a)
		t.truthy(l:TryConsume(a, 0))
	end)
end
