--!strict
local CameraShake = require("../../src/client/Feel/CameraShake")

local CFG = {
	maxOffset = 0.6,
	maxRoll = math.rad(1.5),
	decayPerSecond = 1.2,
	frequency = 25,
	exponent = 2,
	kickSeconds = 0.15,
}

return function(t)
	t.test("trauma clamps to [0, 1]", function()
		local s = CameraShake.new(CFG)
		s:AddTrauma(0.7)
		s:AddTrauma(0.7)
		t.eq(s:GetTrauma(), 1)
		s:AddTrauma(-5)
		t.eq(s:GetTrauma(), 0)
	end)

	t.test("trauma decays linearly and stops at zero", function()
		local s = CameraShake.new(CFG)
		s:AddTrauma(1)
		s:Sample(0.25)
		t.near(s:GetTrauma(), 0.7, 1e-9)
		s:Sample(0.25)
		t.near(s:GetTrauma(), 0.4, 1e-9)
		s:Sample(10)
		t.eq(s:GetTrauma(), 0)
	end)

	t.test("shake is trauma squared", function()
		local s = CameraShake.new(CFG)
		s:AddTrauma(0.5)
		t.near(s:GetShake(), 0.25, 1e-9)
		s:AddTrauma(0.5)
		t.near(s:GetShake(), 1, 1e-9)
	end)

	t.test("no trauma means no offset", function()
		local s = CameraShake.new(CFG)
		local x, y, r = s:Sample(1 / 60)
		t.eq(x, 0)
		t.eq(y, 0)
		t.eq(r, 0)
	end)

	t.test("offsets stay within trauma^2 * max", function()
		local s = CameraShake.new(CFG)
		local maxSeen = 0
		for i = 1, 600 do
			s:AddTrauma(1) -- hold trauma at 1 before each sample
			local x, y, r = s:Sample(1 / 60)
			t.truthy(math.abs(x) <= CFG.maxOffset + 1e-9, `x {x} within max at step {i}`)
			t.truthy(math.abs(y) <= CFG.maxOffset + 1e-9, `y {y} within max`)
			t.truthy(math.abs(r) <= CFG.maxRoll + 1e-9, `roll {r} within max`)
			maxSeen = math.max(maxSeen, math.abs(x), math.abs(y))
		end
		t.truthy(maxSeen > 0.05, "noise actually moves the camera")

		local small = CameraShake.new(CFG)
		for _ = 1, 600 do
			small:Reset()
			small:AddTrauma(0.12) -- light-hit trauma
			local x, y = small:Sample(1 / 60)
			t.truthy(math.abs(x) <= CFG.maxOffset * 0.0144 + 1e-9, "light hit is near-invisible (x)")
			t.truthy(math.abs(y) <= CFG.maxOffset * 0.0144 + 1e-9, "light hit is near-invisible (y)")
		end
	end)

	t.test("noise is continuous (no frame-to-frame jumps)", function()
		local s = CameraShake.new(CFG)
		s:AddTrauma(1)
		local px = s:Sample(1 / 240)
		for _ = 1, 100 do
			s:AddTrauma(1)
			local x = s:Sample(1 / 240)
			t.truthy(math.abs(x - px) < CFG.maxOffset * 0.5, "smooth noise, not random jitter")
			px = x
		end
	end)

	t.test("scale 0 (shake setting off) silences everything but trauma still decays", function()
		local s = CameraShake.new(CFG)
		s:SetScale(0)
		s:AddTrauma(1)
		s:Kick(1, 0, 0.5)
		local x, y, r = s:Sample(0.1)
		t.eq(x, 0)
		t.eq(y, 0)
		t.eq(r, 0)
		t.near(s:GetTrauma(), 0.88, 1e-9)
	end)

	t.test("scale is clamped to [0, 1]", function()
		local s = CameraShake.new(CFG)
		s:SetScale(3)
		t.eq(s:GetScale(), 1)
		s:SetScale(-1)
		t.eq(s:GetScale(), 0)
	end)

	t.test("kick pushes along the direction and fades out", function()
		local s = CameraShake.new(CFG)
		s:Kick(3, 0, 0.3) -- direction is normalized
		local x, y = s:Sample(0.05)
		t.near(x, 0.3, 1e-9, "full kick on the first frame")
		t.near(y, 0, 1e-9)
		local x2 = s:Sample(0.05)
		t.near(x2, 0.2, 1e-9, "linear fade")
		s:Sample(0.05)
		local x4 = s:Sample(0.05)
		t.eq(x4, 0, "gone after kickSeconds")
	end)

	t.test("zero-length kick is ignored", function()
		local s = CameraShake.new(CFG)
		s:Kick(0, 0, 1)
		local x, y = s:Sample(0.05)
		t.eq(x, 0)
		t.eq(y, 0)
	end)
end
