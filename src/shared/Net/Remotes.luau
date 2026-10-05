--!strict
--[[
	The RemoteEvents multiplayer uses, kept in ReplicatedStorage.Remotes. The server creates
	them; clients wait for them.

	Unreliable (latest state matters, a lost packet is fine):
		State   client -> server   my fighter's Snapshot, ~30 times a second
		Relay   server -> client   (userId, Snapshot, percentVersion) for every fighter, yours
		                           included, with the server's % filled in
	Reliable:
		HitClaim  client -> server   "I hit them" (HitValidation.Claim)
		Hit       server -> all      a confirmed hit: attacker, victim, move, Combat.HitResult
		KO        client -> server   "I went past the blast zone"
		KOed      server -> all      (userId, x, y, percentVersion) a confirmed KO
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local FOLDER_NAME = "Remotes"

local function folder(): Instance
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if existing then
			return existing
		end
		local created = Instance.new("Folder")
		created.Name = FOLDER_NAME
		created.Parent = ReplicatedStorage
		return created
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

local function find(name: string, className: string): Instance
	local parent = folder()
	if RunService:IsServer() then
		local existing = parent:FindFirstChild(name)
		if existing then
			return existing
		end
		local remote = Instance.new(className)
		remote.Name = name
		remote.Parent = parent
		return remote
	end
	return parent:WaitForChild(name)
end

-- Looked up once, then reused (State and Relay fire ~30 times a second per player).
local cache: { [string]: Instance } = {}

local function get(name: string, className: string): Instance
	local cached = cache[name]
	if cached then
		return cached
	end
	local remote = find(name, className)
	cache[name] = remote
	return remote
end

function Remotes.unreliable(name: "State" | "Relay"): UnreliableRemoteEvent
	return get(name, "UnreliableRemoteEvent") :: UnreliableRemoteEvent
end

function Remotes.reliable(name: "HitClaim" | "Hit" | "KO" | "KOed"): RemoteEvent
	return get(name, "RemoteEvent") :: RemoteEvent
end

return Remotes
