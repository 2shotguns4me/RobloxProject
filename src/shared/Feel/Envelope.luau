--!strict
-- Small pure easing/envelope helpers used by camera punch and victim shake.

local Envelope = {}

function Envelope.easeOutQuad(x: number): number
	local t = math.clamp(x, 0, 1)
	return 1 - (1 - t) * (1 - t)
end

function Envelope.easeInOutQuad(x: number): number
	local t = math.clamp(x, 0, 1)
	if t < 0.5 then
		return 2 * t * t
	end
	return 1 - ((-2 * t + 2) ^ 2) / 2
end

--[[
	Attack-hold-release envelope in [0, 1] at time t (seconds since start):
	ease out to 1 over inTime, hold for holdTime, ease back to 0 over outTime.
	Returns 0 before start and after it ends.
]]
function Envelope.punch(t: number, inTime: number, holdTime: number, outTime: number): number
	if t < 0 then
		return 0
	end
	if t < inTime then
		return Envelope.easeOutQuad(t / inTime)
	end
	t -= inTime
	if t < holdTime then
		return 1
	end
	t -= holdTime
	if t < outTime then
		return 1 - Envelope.easeInOutQuad(t / outTime)
	end
	return 0
end

function Envelope.punchLength(inTime: number, holdTime: number, outTime: number): number
	return inTime + holdTime + outTime
end

--[[
	Victim hitstop shake (Sakurai): alternate sign every 60 Hz frame, decay linearly over the
	freeze, horizontal when grounded, vertical when airborne. Returns (dx, dy) in studs.
]]
function Envelope.victimShake(amplitude: number, elapsed: number, duration: number, airborne: boolean): (number, number)
	if duration <= 0 or elapsed < 0 or elapsed >= duration then
		return 0, 0
	end
	local frame = math.floor(elapsed * 60)
	local sign = if frame % 2 == 0 then 1 else -1
	local mag = amplitude * (1 - elapsed / duration) * sign
	if airborne then
		return 0, mag
	end
	return mag, 0
end

return Envelope
