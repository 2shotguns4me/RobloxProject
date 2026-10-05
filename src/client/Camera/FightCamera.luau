--!strict
--[[
	Side-on 2.5D fighting camera. Frames a set of target positions Smash-style, clamps to the
	stage bounds, then layers additive effects on top of the base CFrame each render frame:
	the shake offset (from a CameraShake) and FOV punches (zoom toward an impact point).

		FightCamera.Start()
		FightCamera.SetTargets({ fighterA.Position, fighterB.Position })  -- call every frame or on change
		FightCamera.SetBounds({ minX = -60, maxX = 60, minY = -10, maxY = 45 })
		FightCamera.SetShakeSource(Feel.GetShake())   -- Feel does this for you
		FightCamera.Punch(0.12, 0.08, 0.4, 0.35, impactPosition)
		FightCamera.Stop()

	Framing math lives in ./Framing (pure, unit-tested).
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require("./Config")
local Framing = require("./Framing")
local Envelope =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Feel"):WaitForChild("Envelope"))

export type Bounds = Framing.Bounds
type ShakeSource = { Step: (self: any, dt: number) -> CFrame }
type Punch = {
	fraction: number,
	inTime: number,
	hold: number,
	outTime: number,
	started: number,
	focus: Vector3?,
}

local FightCamera = {}

local targets: { Vector3 } = {}
local bounds: Bounds? = nil
local planeZ = Config.PlaneZ
local current: Framing.Frame? = nil
local shakeSource: ShakeSource? = nil
local punches: { Punch } = {}
local running = false
local savedCameraType: Enum.CameraType? = nil
local savedFov: number? = nil
local snapNext = false

function FightCamera.SetTargets(positions: { Vector3 })
	targets = positions
end

-- Stage bounds the view must stay inside (the visible blast-zone box, not the kill box).
function FightCamera.SetBounds(newBounds: Bounds?)
	bounds = newBounds
end

function FightCamera.SetPlaneZ(z: number)
	planeZ = z
end

function FightCamera.SetShakeSource(source: ShakeSource?)
	shakeSource = source
end

-- Jump straight to the target framing on the next frame (round start, respawn).
function FightCamera.Snap()
	snapNext = true
end

--[[
	FOV punch-in: narrows the FOV by `fraction` (0.05 = 5%) with an ease-out over inTime,
	holds, then eases back over outTime. With `focus`, the look-at drifts toward that point by
	Feel's PunchLookAt amount at full strength. The strongest active punch wins.
]]
function FightCamera.Punch(fraction: number, inTime: number, holdTime: number, outTime: number, focus: Vector3?)
	if fraction <= 0 then
		return
	end
	table.insert(punches, {
		fraction = fraction,
		inTime = inTime,
		hold = holdTime,
		outTime = outTime,
		started = os.clock(),
		focus = focus,
	})
end

local punchLookAt = 0.3
function FightCamera.SetPunchLookAt(amount: number)
	punchLookAt = math.clamp(amount, 0, 1)
end

local function evaluatePunches(): (number, Vector3?, number)
	local now = os.clock()
	local best, bestFocus, bestEnv = 0, nil, 0
	for i = #punches, 1, -1 do
		local p = punches[i]
		local t = now - p.started
		if t >= Envelope.punchLength(p.inTime, p.hold, p.outTime) then
			table.remove(punches, i)
		else
			local env = Envelope.punch(t, p.inTime, p.hold, p.outTime)
			local amount = env * p.fraction
			if amount > best then
				best, bestFocus, bestEnv = amount, p.focus, env
			end
		end
	end
	return best, bestFocus, bestEnv
end

function FightCamera.GetFrame(): Framing.Frame?
	return current
end

local function render(dt: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		-- The default camera scripts can reset this on respawn.
		camera.CameraType = Enum.CameraType.Scriptable
	end
	local cfg = Config.Framing
	local viewport = camera.ViewportSize
	local aspect = if viewport.Y > 0 then viewport.X / viewport.Y else 16 / 9

	local target = Framing.computeTarget(targets :: any, cfg, aspect, bounds)
	if target then
		if current == nil or snapNext then
			current = target
			snapNext = false
		else
			current = Framing.step(current, target, cfg, dt)
		end
	end
	local frame = current
	if not frame then
		return
	end
	if bounds then
		frame = Framing.clampToBounds(frame, cfg, aspect, bounds)
	end

	local focus = Vector3.new(frame.x, frame.y, planeZ)
	local punchAmount, punchFocus, punchEnv = evaluatePunches()
	if punchFocus then
		local p = Vector3.new(punchFocus.X, punchFocus.Y, planeZ)
		focus = focus:Lerp(p, punchLookAt * punchEnv)
	end

	local base = CFrame.new(focus)
		* CFrame.Angles(-math.rad(Config.PitchDegrees), 0, 0)
		* CFrame.new(0, 0, frame.distance)
	local offset = if shakeSource then shakeSource:Step(dt) else CFrame.identity
	camera.CFrame = base * offset
	camera.Focus = CFrame.new(focus)
	camera.FieldOfView = cfg.fieldOfView * (1 - punchAmount)
end

function FightCamera.Start()
	if running then
		return
	end
	running = true
	local camera = Workspace.CurrentCamera
	if camera then
		savedCameraType = camera.CameraType
		savedFov = camera.FieldOfView
		camera.CameraType = Enum.CameraType.Scriptable
	end
	snapNext = true
	RunService:BindToRenderStep(Config.RenderStepName, Enum.RenderPriority.Camera.Value + 1, render)
end

function FightCamera.Stop()
	if not running then
		return
	end
	running = false
	RunService:UnbindFromRenderStep(Config.RenderStepName)
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = savedCameraType or Enum.CameraType.Custom
		if savedFov then
			camera.FieldOfView = savedFov
		end
	end
	table.clear(punches)
	current = nil
end

function FightCamera.IsRunning(): boolean
	return running
end

return FightCamera
