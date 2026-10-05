--!strict
--[[
	The server's side of multiplayer fights. It owns everyone's damage %: clients simulate
	and send their own fighter, but only the server decides hits and KOs.

	- State: sanitizes each client's snapshot, records it in that player's history, and relays
	  it to every player (the sender too, so it learns its own server %), with the server's %
	  and a version number that goes up whenever that % changes.
	- HitClaim: one claim per attack per victim (HitValidation.isNewHit), checked against both
	  fighters' recorded history (HitValidation.check). A claim whose attack hasn't arrived yet
	  is checked once more shortly after. Then the hit is worked out (Combat.computeHit, or
	  Combat.computeShieldHit if the victim was shielding) and sent to everyone; the victim's
	  client applies it. Shields and dodges are judged by the server's own DefenseGuard, not
	  just what the victim's client reports.
	- KO: accepted if the player's recent history reaches the blast zone (HitValidation.checkKO);
	  their % resets and everyone sees the KO.

	Movement itself is still trusted from clients for now; checking it is later netcode work.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Combat = require(Shared.Combat.Combat)
local CombatConfig = require(Shared.Combat.Config)
local Fighter = require(Shared.Combat.Fighter)
local DefenseGuard = require(Shared.Net.DefenseGuard)
local TestMoveset = require(Shared.Combat.TestMoveset)
local MovementConfig = require(Shared.Movement.Config)
local History = require(Shared.Net.History)
local HitValidation = require(Shared.Net.HitValidation)
local NetConfig = require(Shared.Net.Config)
local Remotes = require(Shared.Net.Remotes)
local Snapshot = require(Shared.Net.Snapshot)
local StageGeometry = require(Shared.Stage.StageGeometry)

local MatchServer = {}

type Record = {
	History: History.History,
	Percent: number,
	PercentVersion: number, -- goes up every time Percent changes
	Weight: number,
	LastHits: { [number]: HitValidation.LastHit }, -- by victim UserId
	Guard: DefenseGuard.Guard,
}

local ctx: Fighter.Context = {
	Movement = MovementConfig,
	Combat = CombatConfig,
	Stage = { Solids = {}, Platforms = {} },
	Moveset = TestMoveset :: any, -- placeholder until the first fighter design exists
}
local records: { [Player]: Record } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function addPlayer(player: Player)
	records[player] = {
		History = History.new(NetConfig.HistorySeconds),
		Percent = 0,
		PercentVersion = 0,
		Weight = CombatConfig.DefaultWeight,
		LastHits = {},
		Guard = DefenseGuard.new(ctx),
	}
end

local function setPercent(record: Record, percent: number)
	record.Percent = percent
	record.PercentVersion += 1
end

local function onState(player: Player, raw: any)
	local record = records[player]
	local s = Snapshot.sanitize(raw, ctx.Moveset, NetConfig)
	if not record or not s then
		return
	end
	-- The client stamps its own time; keep it within what the server will rewind to.
	local t = now()
	s.T = math.clamp(s.T, t - NetConfig.MaxRewindSeconds, t)
	local newest = History.latest(record.History)
	History.push(record.History, s)
	if History.latest(record.History) ~= newest then
		DefenseGuard.observe(record.Guard, s, ctx)
	end

	local relayed = table.clone(s)
	relayed.Percent = record.Percent
	local relay = Remotes.unreliable("Relay")
	for _, other in Players:GetPlayers() do
		relay:FireClient(other, player.UserId, relayed, record.PercentVersion)
	end
end

local function processClaim(player: Player, claim: HitValidation.Claim, isRetry: boolean)
	local attacker = records[player]
	local victimPlayer = Players:GetPlayerByUserId(claim.VictimId)
	local victim = if victimPlayer and victimPlayer ~= player then records[victimPlayer] else nil
	if not attacker or not victim then
		return
	end
	if not HitValidation.isNewHit(attacker.LastHits[claim.VictimId], claim, NetConfig) then
		return
	end

	local ok, reason, victimGhost =
		HitValidation.check(claim, attacker.History, victim.History, ctx, NetConfig, now(), victim.Guard)
	if not ok then
		if reason == "attack not in history" and not isRetry then
			-- The state showing this attack may still be on its way; look again shortly.
			task.delay(NetConfig.AttackRetrySeconds, processClaim, player, claim, true)
		elseif RunService:IsStudio() then
			warn(`[MatchServer] rejected hit from {player.Name}: {reason}`)
		end
		return
	end
	attacker.LastHits[claim.VictimId] = { Serial = claim.Serial, T = claim.T }

	local a = History.sample(attacker.History, claim.T) :: Snapshot.Snapshot
	local v = (victimGhost :: Fighter.State).Body
	local move = ctx.Moveset[claim.Move]
	local playerCount = #Players:GetPlayers()
	local hit = {
		AttackerId = player.UserId,
		VictimId = claim.VictimId,
		Move = claim.Move,
		Result = nil :: Combat.HitResult?,
		ShieldResult = nil :: Combat.ShieldHitResult?, -- set instead of Result when blocked
		PercentVersion = victim.PercentVersion,
		X = v.X,
		Y = v.Y + MovementConfig.BodyHeight / 2,
	}
	if victimGhost and DefenseGuard.shieldBlocks(victim.Guard, victimGhost) then
		local blocked = Combat.computeShieldHit(ctx, move, a.Facing, playerCount)
		DefenseGuard.damageShield(victim.Guard, blocked.ShieldDamage)
		hit.ShieldResult = blocked
	else
		local result = Combat.computeHit(ctx, move, a.Facing, victim.Percent, victim.Weight, playerCount)
		setPercent(victim, result.Percent)
		hit.Result = result
		hit.PercentVersion = victim.PercentVersion
	end
	Remotes.reliable("Hit"):FireAllClients(hit)
end

local function onHitClaim(player: Player, raw: any)
	local claim = HitValidation.sanitize(raw)
	if claim then
		processClaim(player, claim, false)
	end
end

local function onKO(player: Player)
	local record = records[player]
	if not record or not HitValidation.checkKO(record.History, Combat.blastZone(ctx), NetConfig) then
		return
	end
	setPercent(record, 0)
	local last = History.latest(record.History)
	Remotes.reliable("KOed")
		:FireAllClients(player.UserId, if last then last.X else 0, if last then last.Y else 0, record.PercentVersion)
end

function MatchServer.start()
	ctx.Stage = StageGeometry.read()
	StageGeometry.onChanged(function()
		ctx.Stage = StageGeometry.read()
	end)

	Remotes.unreliable("State").OnServerEvent:Connect(onState)
	Remotes.unreliable("Relay")
	Remotes.reliable("HitClaim").OnServerEvent:Connect(onHitClaim)
	Remotes.reliable("Hit")
	Remotes.reliable("KO").OnServerEvent:Connect(onKO)
	Remotes.reliable("KOed")

	Players.PlayerAdded:Connect(addPlayer)
	Players.PlayerRemoving:Connect(function(player)
		records[player] = nil
		for _, record in records do
			record.LastHits[player.UserId] = nil
		end
	end)
	for _, player in Players:GetPlayers() do
		addPlayer(player)
	end
end

return MatchServer
