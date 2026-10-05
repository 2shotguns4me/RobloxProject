--!strict
local Framing = require("../../src/client/Camera/Framing")

local CFG = {
	fieldOfView = 40,
	paddingX = 8,
	paddingTop = 7,
	paddingBottom = 4,
	minDistance = 28,
	maxDistance = 110,
	followSpeed = 6,
	zoomInSpeed = 2.5,
	zoomOutSpeed = 6,
}
local ASPECT = 16 / 9

local function p(x: number, y: number)
	return { X = x, Y = y }
end

return function(t)
	t.test("no targets gives no frame", function()
		t.eq(Framing.computeTarget({}, CFG, ASPECT, nil), nil)
	end)

	t.test("a single target is centred (with padding bias) at min zoom", function()
		local f = Framing.computeTarget({ p(10, 5) }, CFG, ASPECT, nil) :: Framing.Frame
		t.near(f.x, 10, 1e-9)
		t.near(f.y, 5 + (CFG.paddingTop - CFG.paddingBottom) / 2, 1e-9)
		t.near(f.distance, CFG.minDistance, 1e-9)
	end)

	t.test("wide spread fits every target plus padding", function()
		local pts = { p(-40, 0), p(40, 2) }
		local f = Framing.computeTarget(pts, CFG, ASPECT, nil) :: Framing.Frame
		t.near(f.x, 0, 1e-9)
		local hw, hh = Framing.viewHalfExtents(f.distance, CFG.fieldOfView, ASPECT)
		t.near(hw, 40 + CFG.paddingX, 1e-6, "width is the limiting axis and fits exactly")
		t.truthy(hh * 2 >= (2 + CFG.paddingTop) - (0 - CFG.paddingBottom), "height fits too")
	end)

	t.test("tall spread is limited by height", function()
		local f = Framing.computeTarget({ p(0, 0), p(0, 40) }, CFG, ASPECT, nil) :: Framing.Frame
		local _, hh = Framing.viewHalfExtents(f.distance, CFG.fieldOfView, ASPECT)
		t.near(hh, (40 + CFG.paddingTop + CFG.paddingBottom) / 2, 1e-6)
	end)

	t.test("distance clamps to maxDistance", function()
		local f = Framing.computeTarget({ p(-500, 0), p(500, 0) }, CFG, ASPECT, nil) :: Framing.Frame
		t.eq(f.distance, CFG.maxDistance)
	end)

	t.test("distanceFor and viewHalfExtents are inverses", function()
		local d = Framing.distanceFor(30, 10, CFG.fieldOfView, ASPECT)
		local hw = Framing.viewHalfExtents(d, CFG.fieldOfView, ASPECT)
		t.near(hw, 30, 1e-9)
	end)

	t.test("centre is clamped so the view stays inside the stage bounds", function()
		local bounds = { minX = -60, maxX = 60, minY = -10, maxY = 45 }
		local f = Framing.computeTarget({ p(58, 0) }, CFG, ASPECT, bounds) :: Framing.Frame
		local hw, hh = Framing.viewHalfExtents(f.distance, CFG.fieldOfView, ASPECT)
		t.near(f.x + hw, bounds.maxX, 1e-6, "right edge pinned to the bound")
		t.truthy(f.y - hh >= bounds.minY - 1e-6, "bottom edge inside the bound")
	end)

	t.test("bounds cap the zoom-out so the view never exceeds the stage", function()
		local bounds = { minX = -50, maxX = 50, minY = -10, maxY = 60 }
		local f = Framing.computeTarget({ p(-200, 0), p(200, 0) }, CFG, ASPECT, bounds) :: Framing.Frame
		local hw, hh = Framing.viewHalfExtents(f.distance, CFG.fieldOfView, ASPECT)
		t.truthy(hw <= 50 + 1e-6, "view width inside bounds")
		t.truthy(hh <= 35 + 1e-6, "view height inside bounds")
		t.near(f.x, 0, 1e-6)
	end)

	t.test("bounds smaller than the min-zoom view centre the camera", function()
		local bounds = { minX = 0, maxX = 10, minY = 0, maxY = 4 }
		local f = Framing.computeTarget({ p(9, 3) }, CFG, ASPECT, bounds) :: Framing.Frame
		t.eq(f.distance, CFG.minDistance, "min zoom wins over bounds")
		t.near(f.x, 5, 1e-9)
		t.near(f.y, 2, 1e-9)
	end)

	t.test("damp: no time means no movement; long time converges", function()
		t.eq(Framing.damp(0, 10, 6, 0), 0)
		t.near(Framing.damp(0, 10, 6, 10), 10, 1e-6)
		local half = Framing.damp(0, 10, math.log(2), 1)
		t.near(half, 5, 1e-9, "closes exp(-speed*dt) of the gap")
	end)

	t.test("damp is frame-rate independent", function()
		local a = 0
		for _ = 1, 60 do
			a = Framing.damp(a, 10, 6, 1 / 60)
		end
		local b = 0
		for _ = 1, 30 do
			b = Framing.damp(b, 10, 6, 1 / 30)
		end
		t.near(a, b, 1e-9)
	end)

	t.test("step zooms out faster than it zooms in", function()
		local here = { x = 0, y = 0, distance = 50 }
		local out = Framing.step(here, { x = 0, y = 0, distance = 80 }, CFG, 0.1)
		local into = Framing.step(here, { x = 0, y = 0, distance = 20 }, CFG, 0.1)
		t.truthy((out.distance - 50) > (50 - into.distance), "zoom-out covers more ground")
	end)
end
