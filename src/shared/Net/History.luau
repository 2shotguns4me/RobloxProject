--!strict
--[[
	A short, time-ordered record of one fighter's snapshots. Pure.

	The server keeps one per player to check hit claims against where fighters really were
	("rewind"); clients keep one per remote fighter to show and hit-test them slightly in the
	past, interpolating between received states.
]]

local Snapshot = require("./Snapshot")

local History = {}

export type History = {
	Entries: { Snapshot.Snapshot }, -- oldest first
	KeepSeconds: number,
}

function History.new(keepSeconds: number): History
	return { Entries = {}, KeepSeconds = keepSeconds }
end

-- Adds a snapshot. Ones older than the newest entry (out-of-order packets) are dropped.
-- Entries older than KeepSeconds before the newest are trimmed.
function History.push(h: History, s: Snapshot.Snapshot)
	local entries = h.Entries
	local last = entries[#entries]
	if last and s.T <= last.T then
		return
	end
	table.insert(entries, s)
	local cutoff = s.T - h.KeepSeconds
	while #entries > 1 and entries[1].T < cutoff do
		table.remove(entries, 1)
	end
end

function History.latest(h: History): Snapshot.Snapshot?
	return h.Entries[#h.Entries]
end

-- The state at time t: interpolated between the two snapshots around it. Before the first
-- or after the last snapshot it holds that snapshot (no guessing ahead). Nil if empty.
function History.sample(h: History, t: number): Snapshot.Snapshot?
	local entries = h.Entries
	local n = #entries
	if n == 0 then
		return nil
	end
	if t <= entries[1].T then
		return entries[1]
	end
	if t >= entries[n].T then
		return entries[n]
	end
	for i = n - 1, 1, -1 do
		local a = entries[i]
		if a.T <= t then
			local b = entries[i + 1]
			local alpha = (t - a.T) / (b.T - a.T)
			local s = table.clone(a)
			s.T = t
			s.X = a.X + (b.X - a.X) * alpha
			s.Y = a.Y + (b.Y - a.Y) * alpha
			s.VX = a.VX + (b.VX - a.VX) * alpha
			s.VY = a.VY + (b.VY - a.VY) * alpha
			return s
		end
	end
	return entries[1]
end

-- The first snapshot between fromT and toT showing the given attack (move and serial), if any.
function History.findAttack(h: History, move: string, serial: number, fromT: number, toT: number): Snapshot.Snapshot?
	for _, s in h.Entries do
		if s.T >= fromT and s.T <= toT and s.Serial == serial and s.Attack == move then
			return s
		end
	end
	return nil
end

return History
