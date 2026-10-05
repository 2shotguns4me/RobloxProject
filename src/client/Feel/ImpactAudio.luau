--!strict
--[[
	Layered impact audio on the new Audio API.

	Graph (built lazily, client-only, so the sounds are heard only by this client):

		voice AudioPlayer --Wire--> voice AudioEqualizer --Wire--> SFX AudioFader --Wire--> AudioDeviceOutput
		(music players) --Wire--> Music AudioFader --Wire--> AudioPitchShifter --Wire--> AudioDeviceOutput

	- Each tier lists layers (Snap / Body / Tail / KOSting); each layer plays one random alternate
	  with PlaybackSpeed randomized by the tier's pitch variance, and extra low end per tier.
	- Heavy and KO tiers briefly duck the Music fader. Music code should wire its AudioPlayers into
	  ImpactAudio.GetMusicInput() to be ducked and pitched down during KO slow-mo.
	- Asset IDs come from Config.Sounds plus ReplicatedStorage.Assets.Sounds. With no IDs, every
	  call returns silently and no audio instances are created.
]]

local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Assets = require("./Assets")
local Config = require("./Config")

type SoundSpec = {
	layers: { string },
	pitchVariance: number,
	volume: number,
	lowGainDb: number,
	duckDb: number,
	duckSeconds: number,
}

type Voice = { player: AudioPlayer, eq: AudioEqualizer }

local ImpactAudio = {}

local rng = Random.new()
local folder: Folder? = nil
local sfxFader: AudioFader? = nil
local musicFader: AudioFader? = nil
local pitchShifter: AudioPitchShifter? = nil

local idCache: { [string]: { string } } = {}
local voices: { [string]: { Voice } } = {}
local nextVoice: { [string]: number } = {}

local duckUntil = 0
local duckLevel = 1
local duckToken = 0
local pitchToken = 0

local function wire(source: Instance, target: Instance)
	local w = Instance.new("Wire")
	w.SourceInstance = source
	w.TargetInstance = target
	w.Parent = source
end

local function ensureGraph(): Folder
	if folder and folder.Parent then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "FeelAudio"

	local output = Instance.new("AudioDeviceOutput")
	output.Name = "Output"
	output.Parent = f

	local sfx = Instance.new("AudioFader")
	sfx.Name = "SFX"
	sfx.Volume = Config.Audio.hitsBusVolume
	sfx.Parent = f
	wire(sfx, output)

	local music = Instance.new("AudioFader")
	music.Name = "Music"
	music.Parent = f

	local shifter = Instance.new("AudioPitchShifter")
	shifter.Name = "MusicPitch"
	shifter.Bypass = true
	shifter.Parent = f
	wire(music, shifter)
	wire(shifter, output)

	f.Parent = Workspace -- audio objects are parented under Workspace in the API examples
	folder, sfxFader, musicFader, pitchShifter = f, sfx, music, shifter
	table.clear(voices)
	return f
end

local function idsFor(layer: string): { string }
	local cached = idCache[layer]
	if cached then
		return cached
	end
	local spec = Config.Sounds[layer]
	local ids = if spec then Assets.audioIds(spec.ids, spec.assetName) else {}
	idCache[layer] = ids
	return ids
end

local function voiceFor(layer: string): Voice
	local f = ensureGraph()
	local pool = voices[layer]
	if not pool then
		pool = {}
		voices[layer] = pool
		for i = 1, Config.Audio.voicesPerLayer do
			local player = Instance.new("AudioPlayer")
			player.Name = `{layer}{i}`
			player.Parent = f
			local eq = Instance.new("AudioEqualizer")
			eq.Name = `{layer}{i}EQ`
			eq.Parent = f
			wire(player, eq)
			wire(eq, sfxFader :: AudioFader)
			table.insert(pool, { player = player, eq = eq })
		end
	end
	local i = (nextVoice[layer] or 0) % #pool + 1
	nextVoice[layer] = i
	return pool[i]
end

-- Plays one layer. Returns false (silently) when the layer has no asset.
function ImpactAudio.PlayLayer(layer: string, volume: number, pitchVariance: number, lowGainDb: number?): boolean
	local ids = idsFor(layer)
	if #ids == 0 then
		return false
	end
	local voice = voiceFor(layer)
	local player = voice.player
	local id = ids[rng:NextInteger(1, #ids)]
	if player.Asset ~= id then
		player.Asset = id
	end
	player.Volume = volume
	player.PlaybackSpeed = 1 + rng:NextNumber(-pitchVariance, pitchVariance)
	voice.eq.LowGain = lowGainDb or 0
	player.TimePosition = 0
	player:Play()
	return true
end

function ImpactAudio.PlayHit(sound: SoundSpec)
	for _, layer in sound.layers do
		-- The KO sting stays at normal pitch so it cuts through (report 1.5).
		local variance = if layer == "KOSting" then 0 else sound.pitchVariance
		ImpactAudio.PlayLayer(layer, sound.volume, variance, sound.lowGainDb)
	end
	if sound.duckDb < 0 and sound.duckSeconds > 0 then
		ImpactAudio.Duck(sound.duckDb, sound.duckSeconds)
	end
end

function ImpactAudio.PlayMovement(kind: string, intensity: number?)
	ImpactAudio.PlayLayer(kind, Config.Audio.movementVolume * (intensity or 1), Config.Audio.movementPitchVariance, 0)
end

-- Music duck by `db` (negative) for `seconds`; overlapping ducks keep the deepest level and the
-- latest end. No-op until something has wired music into GetMusicInput().
function ImpactAudio.Duck(db: number, seconds: number)
	local fader = musicFader
	if not fader or not fader.Parent then
		return
	end
	local now = os.clock()
	local level = 10 ^ (db / 20)
	if now < duckUntil then
		level = math.min(level, duckLevel)
	end
	duckLevel = level
	duckUntil = math.max(duckUntil, now + seconds)
	duckToken += 1
	local token = duckToken
	TweenService:Create(fader, TweenInfo.new(Config.Audio.duckAttackSeconds), { Volume = level }):Play()
	task.delay(duckUntil - now, function()
		if token ~= duckToken then
			return
		end
		duckLevel = 1
		TweenService:Create(fader, TweenInfo.new(Config.Audio.duckReleaseSeconds), { Volume = 1 }):Play()
	end)
end

-- Pitch the music bus down (KO slow-mo) for `seconds`.
function ImpactAudio.SetWorldPitch(pitch: number, seconds: number)
	local shifter = pitchShifter
	if not shifter or not shifter.Parent then
		return
	end
	pitchToken += 1
	local token = pitchToken
	shifter.Pitch = pitch
	shifter.Bypass = false
	task.delay(seconds, function()
		if token == pitchToken then
			shifter.Bypass = true
		end
	end)
end

-- Audio node that music AudioPlayers should Wire into (gets ducking + slow-mo pitch).
function ImpactAudio.GetMusicInput(): AudioFader
	ensureGraph()
	return musicFader :: AudioFader
end

-- Forget cached IDs (call after adding assets under Assets.Sounds at runtime).
function ImpactAudio.RefreshAssets()
	table.clear(idCache)
end

-- Preload every configured layer. Yields; call from a loading screen.
function ImpactAudio.Preload()
	local toLoad: { any } = {}
	for layer in Config.Sounds do
		for _, id in idsFor(layer) do
			table.insert(toLoad, id) -- PreloadAsync accepts content ID strings
		end
	end
	if #toLoad > 0 then
		pcall(function()
			ContentProvider:PreloadAsync(toLoad)
		end)
	end
end

return ImpactAudio
