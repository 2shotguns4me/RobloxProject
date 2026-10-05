--!strict
-- Side-on 2.5D fighting camera tunables. Distances in studs, angles in degrees.

local Config = {}

Config.Framing = {
	fieldOfView = 40, -- vertical FOV (Roblox Camera.FieldOfView is vertical by default)
	paddingX = 8, -- studs of space left/right of the outermost targets
	paddingTop = 7, -- above the highest target (fighters are tall; positions are roots)
	paddingBottom = 4,
	minDistance = 28, -- closest zoom
	maxDistance = 110, -- farthest zoom
	followSpeed = 6, -- exponential smoothing rate for pan (1/s)
	zoomInSpeed = 2.5, -- slower zoom-in reads calmer
	zoomOutSpeed = 6, -- faster zoom-out so fighters never leave the frame
}

Config.PitchDegrees = 5 -- slight downward tilt; the camera orbits the focus point
Config.PlaneZ = 0 -- the stage plane fighters move in
Config.RenderStepName = "FightCamera"

return Config
