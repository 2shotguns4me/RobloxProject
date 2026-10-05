--!strict
--[[
	Side-on camera that follows one fighter along the 2.5D plane. Framing both fighters
	in a match comes with match flow.
]]

local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)

local FighterCamera = {}

function FighterCamera.start(getFocus: () -> Vector3?)
	local current: Vector3? = nil

	RunService:BindToRenderStep("FighterCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local camera = workspace.CurrentCamera
		local focus = getFocus()
		if not camera or not focus then
			return
		end

		local alpha = 1 - math.exp(-Config.FollowSpeed * dt)
		local smoothed = if current then current:Lerp(focus, alpha) else focus
		current = smoothed

		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = Config.FieldOfView
		camera.CFrame = CFrame.lookAt(
			smoothed + Vector3.new(0, Config.Height, Config.Distance),
			smoothed + Vector3.new(0, Config.LookHeight, 0)
		)
	end)
end

return FighterCamera
