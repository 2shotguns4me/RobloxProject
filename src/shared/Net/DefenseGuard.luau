--!strict
--[[
	The server's own view of each player's defense, so a modified client can't block or dodge
	forever by reporting it. Pure.

	- Shield health is tracked here from how long the client reported shielding and from the
	  hits it blocked, with the same drain and regen as the simulation. A shield this guard
	  thinks is empty doesn't block: those hits land normally.
	- A dodge only counts as intangible during its real window, timed from when the server first
	  saw it (allowing for the frame the client says it was on), and a new dodge can't start
	  before the previous one could have finished.

	Feed it every accepted snapshot in time order with observe().
]]

local Fighter = require("../Combat/Fighter")
local Snapshot = require("./Snapshot")

local DefenseGuard = {}

export type Guard = {
	Shield: number,
	Shielding: boolean,
	LastT: number?,
	DodgeKind: string, -- "" when not dodging
	DodgeStart: number?, -- server time of the dodge's frame 1; nil = doesn't count
	NextDodgeAllowed: number,
}

local DODGES = { SpotDodge = true, Roll = true, AirDodge = true }

function DefenseGuard.new(ctx: Fighter.Context): Guard
	return {
		Shield = ctx.Combat.Defense.ShieldMax,
		Shielding = false,
		LastT = nil,
		DodgeKind = "",
		DodgeStart = nil,
		NextDodgeAllowed = -math.huge,
	}
end

function DefenseGuard.observe(g: Guard, s: Snapshot.Snapshot, ctx: Fighter.Context)
	local d = ctx.Combat.Defense
	local last = g.LastT
	local frames = if last then math.max(0, s.T - last) * 60 else 0
	if g.Shielding then
		g.Shield = math.max(0, g.Shield - d.ShieldDrain * frames)
	else
		g.Shield = math.min(d.ShieldMax, g.Shield + d.ShieldRegen * frames)
	end
	g.Shielding = s.Defense == "Shield"

	if DODGES[s.Defense] then
		if g.DodgeKind ~= s.Defense then
			-- A new dodge: work out when its frame 1 was.
			local window: Fighter.DodgeConfig = (d :: any)[s.Defense]
			local start = s.T - (math.max(s.DefenseFrame, 1) - 1) / 60
			if start >= g.NextDodgeAllowed then
				g.DodgeStart = start
				g.NextDodgeAllowed = start + window.Total / 60
			else
				g.DodgeStart = nil -- too soon after the last one to be real
			end
			g.DodgeKind = s.Defense
		end
	else
		g.DodgeKind = ""
		g.DodgeStart = nil
	end
	g.LastT = s.T
end

-- Whether a fighter that claims to be shielding really blocks: the server thinks its shield
-- still has health.
function DefenseGuard.shieldBlocks(g: Guard, victim: Fighter.State): boolean
	return Fighter.isShielding(victim) and g.Shield > 0
end

function DefenseGuard.damageShield(g: Guard, amount: number)
	g.Shield = math.max(0, g.Shield - amount)
end

-- Whether a fighter that claims to be dodging at time t really was intangible then, timed by
-- the server rather than by the client's frame count.
function DefenseGuard.intangibleAt(g: Guard, victim: Fighter.State, t: number, ctx: Fighter.Context): boolean
	local kind = victim.Defense
	local start = g.DodgeStart
	if not kind or not DODGES[kind] or kind ~= g.DodgeKind or not start then
		return false
	end
	local window: Fighter.DodgeConfig = (ctx.Combat.Defense :: any)[kind]
	local frame = math.floor((t - start) * 60 + 1e-6) + 1
	return frame >= window.Start and frame <= window.End
end

return DefenseGuard
