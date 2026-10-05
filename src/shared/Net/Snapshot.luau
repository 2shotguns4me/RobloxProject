--!strict
--[[
	A fighter's state as sent over the network, about 30 times a second. Pure.

	Clients send their own snapshot to the server; the server checks it (sanitize), records it
	and relays it to everyone else with the server's damage % filled in. Receivers turn
	snapshots back into "ghost" fighters for hit detection and the camera.
]]

local Fighter = require("../Combat/Fighter")
local Movement = require("../Movement/Movement")

local Snapshot = {}

export type Snapshot = {
	T: number, -- server time (workspace:GetServerTimeNow()) the state is from
	X: number,
	Y: number,
	VX: number,
	VY: number,
	Facing: number,
	Mode: Movement.Mode,
	Attack: string, -- move name, "" when not attacking
	AttackFrame: number,
	Serial: number, -- the attack's serial (0 when not attacking)
	Hitstun: boolean,
	Defense: string, -- Fighter.Defense, "" when none
	DefenseFrame: number,
	Shield: number, -- shield health (for drawing the bubble)
	Percent: number, -- filled in by the server when relaying; clients' own values are ignored
}

local MODES: { [string]: Movement.Mode } = {
	Ground = "Ground",
	JumpSquat = "JumpSquat",
	Air = "Air",
	Landing = "Landing",
}

local DEFENSES: { [string]: Fighter.Defense } = {
	Shield = "Shield",
	ShieldDrop = "ShieldDrop",
	ShieldBreak = "ShieldBreak",
	SpotDodge = "SpotDodge",
	Roll = "Roll",
	AirDodge = "AirDodge",
}

function Snapshot.fromFighter(f: Fighter.State, t: number): Snapshot
	local attack = f.Attack
	local body = f.Body
	return {
		T = t,
		X = body.X,
		Y = body.Y,
		VX = body.VX,
		VY = body.VY,
		Facing = body.Facing,
		Mode = body.Mode,
		Attack = if attack then attack.Name else "",
		AttackFrame = if attack then attack.Frame else 0,
		Serial = if attack then attack.Serial else 0,
		Hitstun = f.Hitstun > 0,
		Defense = f.Defense or "",
		DefenseFrame = f.DefenseFrame,
		Shield = f.Shield,
		Percent = f.Percent,
	}
end

-- A stand-in fighter at the snapshot's position and defensive state, for hit detection and the
-- camera. It never attacks (remote attacks are confirmed by the server, not detected locally).
function Snapshot.toGhost(s: Snapshot, id: number, ctx: Fighter.Context): Fighter.State
	local f = Fighter.new(ctx, id, s.X, s.Y)
	local body = f.Body
	body.VX = s.VX
	body.VY = s.VY
	body.Facing = s.Facing
	body.Mode = s.Mode
	f.Percent = s.Percent
	f.Defense = DEFENSES[s.Defense]
	f.DefenseFrame = s.DefenseFrame
	f.Shield = s.Shield
	return f
end

export type Limits = {
	MaxPosition: number,
	MaxSpeed: number,
	MaxAttackFrame: number,
	MaxShield: number,
}

-- A real number (not NaN or infinite) no bigger than `limit` either way.
function Snapshot.isFiniteNumber(v: any, limit: number): boolean
	return type(v) == "number" and v == v and math.abs(v) <= limit
end

local isFiniteNumber = Snapshot.isFiniteNumber

-- Checks a snapshot that arrived from a client. Returns a clean copy, or nil if anything is
-- missing, the wrong type, not finite, or out of range. Never trust client data as-is.
function Snapshot.sanitize(raw: any, moveset: Fighter.Moveset, limits: Limits): Snapshot?
	if type(raw) ~= "table" then
		return nil
	end
	local mode = MODES[raw.Mode]
	local attack: string = raw.Attack
	if not mode or type(attack) ~= "string" or type(raw.Hitstun) ~= "boolean" then
		return nil
	end
	local defense = raw.Defense
	if defense ~= "" and DEFENSES[defense] == nil then
		return nil
	end
	if attack ~= "" and moveset[attack] == nil then
		return nil
	end
	local position, speed = limits.MaxPosition, limits.MaxSpeed
	if
		not isFiniteNumber(raw.T, 1e10)
		or not isFiniteNumber(raw.X, position)
		or not isFiniteNumber(raw.Y, position)
		or not isFiniteNumber(raw.VX, speed)
		or not isFiniteNumber(raw.VY, speed)
		or not isFiniteNumber(raw.AttackFrame, limits.MaxAttackFrame)
		or not isFiniteNumber(raw.Serial, 1e9)
		or not isFiniteNumber(raw.DefenseFrame, limits.MaxAttackFrame)
		or not isFiniteNumber(raw.Shield, limits.MaxShield)
		or (raw.Facing ~= 1 and raw.Facing ~= -1)
	then
		return nil
	end
	local clean: Snapshot = {
		T = raw.T,
		X = raw.X,
		Y = raw.Y,
		VX = raw.VX,
		VY = raw.VY,
		Facing = raw.Facing,
		Mode = mode :: Movement.Mode,
		Attack = attack,
		AttackFrame = math.floor(raw.AttackFrame),
		Serial = math.floor(raw.Serial),
		Hitstun = raw.Hitstun,
		Defense = defense,
		DefenseFrame = math.floor(raw.DefenseFrame),
		Shield = raw.Shield,
		Percent = 0,
	}
	return clean
end

return Snapshot
