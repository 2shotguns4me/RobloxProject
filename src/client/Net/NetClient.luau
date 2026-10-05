--!strict
--[[
	The client's side of multiplayer. Sends your fighter's state and your hit claims, keeps a
	short history of every other fighter from the server's relay, tracks your own damage % as
	the server sees it, and hands over confirmed hits and KOs.

	Other fighters are shown and hit-tested NetConfig.InterpolationDelay in the past, between
	two received states, so they move smoothly despite packets arriving ~30 times a second.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatFolder = Shared:WaitForChild("Combat")
local NetFolder = Shared:WaitForChild("Net")
local Combat = require(CombatFolder:WaitForChild("Combat"))
local Fighter = require(CombatFolder:WaitForChild("Fighter"))
local History = require(NetFolder:WaitForChild("History"))
local HitValidation = require(NetFolder:WaitForChild("HitValidation"))
local NetConfig = require(NetFolder:WaitForChild("Config"))
local Remotes = require(NetFolder:WaitForChild("Remotes"))
local Snapshot = require(NetFolder:WaitForChild("Snapshot"))

local NetClient = {}

export type ConfirmedHit = {
	AttackerId: number,
	VictimId: number,
	Move: string,
	Result: Combat.HitResult,
	PercentVersion: number, -- the victim's % version after this hit
	X: number,
	Y: number,
}

export type ConfirmedKO = { UserId: number, X: number, Y: number, PercentVersion: number }

local histories: { [number]: History.History } = {}
local pendingHits: { ConfirmedHit } = {}
local pendingKOs: { ConfirmedKO } = {}

-- Your own % as the server last told you, and its version (higher = newer).
local serverPercent = 0
local serverPercentVersion = 0

local function noteMyPercent(percent: number, version: number)
	if version > serverPercentVersion then
		serverPercent = percent
		serverPercentVersion = version
	end
end

function NetClient.now(): number
	return Workspace:GetServerTimeNow()
end

function NetClient.start()
	local myUserId = Players.LocalPlayer.UserId
	Remotes.unreliable("Relay").OnClientEvent:Connect(function(userId: number, s: Snapshot.Snapshot, version: number)
		if userId == myUserId then
			noteMyPercent(s.Percent, version)
			return
		end
		local h = histories[userId]
		if not h then
			h = History.new(NetConfig.HistorySeconds)
			histories[userId] = h
		end
		History.push(h, s)
	end)
	Remotes.reliable("Hit").OnClientEvent:Connect(function(hit: ConfirmedHit)
		if hit.VictimId == myUserId then
			noteMyPercent(hit.Result.Percent, hit.PercentVersion)
		end
		table.insert(pendingHits, hit)
	end)
	Remotes.reliable("KOed").OnClientEvent:Connect(function(userId: number, x: number, y: number, version: number)
		if userId == myUserId then
			noteMyPercent(0, version)
		end
		table.insert(pendingKOs, { UserId = userId, X = x, Y = y, PercentVersion = version })
	end)
	Players.PlayerRemoving:Connect(function(player)
		histories[player.UserId] = nil
	end)
end

function NetClient.sendState(f: Fighter.State)
	Remotes.unreliable("State"):FireServer(Snapshot.fromFighter(f, NetClient.now()))
end

function NetClient.sendHitClaim(claim: HitValidation.Claim)
	Remotes.reliable("HitClaim"):FireServer(claim)
end

function NetClient.sendKO()
	Remotes.reliable("KO"):FireServer()
end

-- Your damage % according to the server (the truth whenever other players are around).
function NetClient.serverPercent(): number
	return serverPercent
end

-- Confirmed hits and KOs received since the last call (the simulation applies them in order).
function NetClient.takeHits(): { ConfirmedHit }
	local hits = pendingHits
	pendingHits = {}
	return hits
end

function NetClient.takeKOs(): { ConfirmedKO }
	local kos = pendingKOs
	pendingKOs = {}
	return kos
end

-- Every other fighter as a ghost (id = their UserId), placed where they were
-- InterpolationDelay ago. Also returns, per ghost, the time of the position it shows: that
-- moment, or the newest state if nothing newer has arrived yet. Hit claims report it.
function NetClient.ghosts(ctx: Fighter.Context): ({ Fighter.State }, { [number]: number })
	local t = NetClient.now() - NetConfig.InterpolationDelay
	local list = {}
	local times = {}
	for userId, h in histories do
		local latest = History.latest(h)
		-- Skip fighters we haven't heard from in a while (left, or their character is gone).
		if latest and t - latest.T < NetConfig.HistorySeconds then
			local s = History.sample(h, t)
			if s then
				table.insert(list, Snapshot.toGhost(s, userId, ctx))
				times[userId] = math.min(t, latest.T)
			end
		end
	end
	return list, times
end

return NetClient
