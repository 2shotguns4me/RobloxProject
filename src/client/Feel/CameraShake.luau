--!strict
--[[
	Trauma-based camera shake (Squirrel Eiserloh, GDC 2016).

	- Hits add trauma in [0, 1]; trauma decays linearly.
	- shake = trauma ^ exponent (2 by default), so light hits are near-invisible.
	- Offsets come from smooth noise (math.noise) with a different seed per axis.
	- Optional directional kick (pushes the camera along the launch direction, decays fast).
	- Everything is multiplied by `scale` (the screen-shake setting).

	Pure math in :Sample (runs under Lune); :Step wraps it in a CFrame for the camera.
	The returned CFrame is an additive offset: apply as base * offset, never accumulate it.
]]

local Config = require("./Config")

local CameraShake = {}
CameraShake.__index = CameraShake

export type ShakeConfig = {
	maxOffset: number,
	maxRoll: number,
	decayPerSecond: number,
	frequency: number,
	exponent: number,
	kickSeconds: number,
}

export type CameraShake = {
	AddTrauma: (self: CameraShake, amount: number) -> (),
	Kick: (self: CameraShake, dirX: number, dirY: number, studs: number) -> (),
	SetScale: (self: CameraShake, scale: number) -> (),
	GetScale: (self: CameraShake) -> number,
	GetTrauma: (self: CameraShake) -> number,
	GetShake: (self: CameraShake) -> number,
	Sample: (self: CameraShake, dt: number) -> (number, number, number),
	Step: (self: CameraShake, dt: number) -> CFrame,
	Reset: (self: CameraShake) -> (),
}

function CameraShake.new(cfg: ShakeConfig?, seed: number?): CameraShake
	local self = setmetatable({
		_cfg = cfg or Config.Shake,
		_trauma = 0,
		_scale = 1,
		_time = 0,
		_seed = seed or 0,
		_kickX = 0,
		_kickY = 0,
		_kickT = 0, -- remaining kick time
	}, CameraShake)
	return (self :: any) :: CameraShake
end

function CameraShake.AddTrauma(self: any, amount: number)
	self._trauma = math.clamp(self._trauma + amount, 0, 1)
end

-- Kick toward (dirX, dirY) by `studs`; a newer kick replaces an older one.
function CameraShake.Kick(self: any, dirX: number, dirY: number, studs: number)
	local len = math.sqrt(dirX * dirX + dirY * dirY)
	if len < 1e-6 or studs <= 0 then
		return
	end
	self._kickX = dirX / len * studs
	self._kickY = dirY / len * studs
	self._kickT = self._cfg.kickSeconds
end

function CameraShake.SetScale(self: any, scale: number)
	self._scale = math.clamp(scale, 0, 1)
end

function CameraShake.GetScale(self: any): number
	return self._scale
end

function CameraShake.GetTrauma(self: any): number
	return self._trauma
end

function CameraShake.GetShake(self: any): number
	return self._trauma ^ self._cfg.exponent
end

-- Advances time by dt and returns (x studs, y studs, roll radians). Samples with the
-- current trauma, then decays it.
function CameraShake.Sample(self: any, dt: number): (number, number, number)
	local cfg: ShakeConfig = self._cfg
	self._time += dt
	local s = (self._trauma ^ cfg.exponent) * self._scale
	local x, y, roll = 0, 0, 0
	if s > 0 then
		local t = self._time * cfg.frequency
		local seed = self._seed
		-- math.noise is 0 at integer lattice points; the .5 offsets keep axes decorrelated.
		x = math.clamp(math.noise(t, seed + 0.5, 1.5), -1, 1) * cfg.maxOffset * s
		y = math.clamp(math.noise(seed + 10.5, t, 2.5), -1, 1) * cfg.maxOffset * s
		roll = math.clamp(math.noise(t, seed + 20.5, 3.5), -1, 1) * cfg.maxRoll * s
	end
	if self._kickT > 0 then
		local k = (self._kickT / cfg.kickSeconds) * self._scale
		x += self._kickX * k
		y += self._kickY * k
		self._kickT = math.max(0, self._kickT - dt)
	end
	self._trauma = math.max(0, self._trauma - cfg.decayPerSecond * dt)
	return x, y, roll
end

function CameraShake.Step(self: any, dt: number): CFrame
	local x, y, roll = CameraShake.Sample(self, dt)
	return CFrame.new(x, y, 0) * CFrame.Angles(0, 0, roll)
end

function CameraShake.Reset(self: any)
	self._trauma = 0
	self._kickT = 0
end

return CameraShake
