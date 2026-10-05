--!strict
--[[
	Particle bursts for hits (spark + flash core) and movement (dust puffs).

	A small round-robin pool of Attachments on one invisible anchored part is reused for every
	burst (report 2.5: don't Instance.new per hit). Each slot carries:
	  - the team's emitters, cloned from ReplicatedStorage.Assets.VFX.HitSpark / .Dust if present
	    (a ParticleEmitter, or any instance containing ParticleEmitters; an optional "EmitCount"
	    number attribute sets that emitter's burst at scale 1), or
	  - code-generated placeholder emitters using Roblox's default particle texture.
]]

local Workspace = game:GetService("Workspace")

local Assets = require("./Assets")
local Config = require("./Config")

type VfxSpec = { scale: number, particles: number, color: { number }, flashFrames: number }

type Slot = {
	attachment: Attachment,
	spark: { ParticleEmitter },
	sparkIsAsset: boolean,
	core: ParticleEmitter?,
	dust: { ParticleEmitter },
	dustIsAsset: boolean,
}

local HitSpark = {}

local anchor: Part? = nil
local slots: { Slot } = {}
local nextSlot = 0

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function placeholderEmitter(name: string, texture: string): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Enabled = false
	e.Rate = 0
	if texture ~= "" then
		e.Texture = texture
	end
	return e
end

local function cloneAssetEmitters(assetName: string, parent: Attachment): { ParticleEmitter }
	local asset = Assets.find("VFX", assetName)
	local out = {}
	if not asset then
		return out
	end
	local sources: { Instance } = if asset:IsA("ParticleEmitter") then { asset } else asset:GetDescendants()
	for _, src in sources do
		if src:IsA("ParticleEmitter") then
			local c = src:Clone()
			c.Enabled = false
			c.Parent = parent
			table.insert(out, c)
		end
	end
	return out
end

local function buildSlot(parent: BasePart, index: number): Slot
	local att = Instance.new("Attachment")
	att.Name = `FX{index}`
	att.Parent = parent

	local spark = cloneAssetEmitters(Config.VFX.hitSparkAssetName, att)
	local sparkIsAsset = #spark > 0
	local core: ParticleEmitter? = nil
	if not sparkIsAsset then
		local s = placeholderEmitter("Spark", Config.VFX.sparkTexture)
		s.LightEmission = 1
		s.Drag = Config.VFX.sparkDrag
		s.Lifetime = NumberRange.new(Config.VFX.sparkLifetime[1], Config.VFX.sparkLifetime[2])
		s.Transparency = NumberSequence.new(0, 1)
		s.Parent = att
		spark = { s }

		local c = placeholderEmitter("Core", Config.VFX.sparkTexture)
		c.LightEmission = 1
		c.Lifetime = NumberRange.new(0.05, 0.08) -- 1-2 frame flash core (report 1.4)
		c.Speed = NumberRange.new(0)
		c.Transparency = NumberSequence.new(0, 1)
		c.Parent = att
		core = c
	end

	local dust = cloneAssetEmitters(Config.VFX.dustAssetName, att)
	local dustIsAsset = #dust > 0
	if not dustIsAsset then
		local d = placeholderEmitter("Dust", Config.VFX.dustTexture)
		d.Color = ColorSequence.new(rgb(Config.VFX.dustColor))
		d.Transparency = NumberSequence.new(0.3, 1)
		d.Drag = 5
		d.Acceleration = Vector3.new(0, 3, 0)
		d.RotSpeed = NumberRange.new(-90, 90)
		d.Rotation = NumberRange.new(0, 360)
		d.Parent = att
		dust = { d }
	end

	return {
		attachment = att,
		spark = spark,
		sparkIsAsset = sparkIsAsset,
		core = core,
		dust = dust,
		dustIsAsset = dustIsAsset,
	}
end

local function ensurePool()
	if anchor and anchor.Parent then
		return
	end
	local p = Instance.new("Part")
	p.Name = "FeelFXAnchor"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.one
	p.CFrame = CFrame.identity
	table.clear(slots)
	for i = 1, Config.VFX.poolSize do
		table.insert(slots, buildSlot(p, i))
	end
	p.Parent = Workspace
	anchor = p
end

local function takeSlot(): Slot
	ensurePool()
	nextSlot = nextSlot % #slots + 1
	return slots[nextSlot]
end

-- Orients the attachment so its +Y (default EmissionDirection = Top) points along `dir`.
local function place(att: Attachment, position: Vector3, dir: Vector3?)
	if dir and dir.Magnitude > 1e-3 then
		local unit = dir.Unit
		local up = if math.abs(unit.Y) > 0.99 then Vector3.zAxis else Vector3.yAxis
		att.WorldCFrame = CFrame.lookAt(position, position + unit, up) * CFrame.Angles(-math.pi / 2, 0, 0)
	else
		att.WorldCFrame = CFrame.new(position)
	end
end

local function emitAsset(emitters: { ParticleEmitter }, defaultCount: number, scale: number)
	for _, e in emitters do
		local base = e:GetAttribute("EmitCount")
		local count = if type(base) == "number" then base else defaultCount
		e:Emit(math.max(1, math.round(count * scale)))
	end
end

-- Hit spark at `position`, sized/coloured by the tier's VFX spec, sprayed along `direction`.
function HitSpark.Play(position: Vector3, vfx: VfxSpec, direction: Vector3?)
	local slot = takeSlot()
	place(slot.attachment, position, direction)
	if slot.sparkIsAsset then
		emitAsset(slot.spark, vfx.particles, vfx.scale)
		return
	end
	local color = rgb(vfx.color)
	local size = Config.VFX.sparkSize * vfx.scale
	local s = slot.spark[1]
	s.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	s.Size = NumberSequence.new(size, 0)
	s.Speed = NumberRange.new(Config.VFX.sparkSpeed[1] * vfx.scale, Config.VFX.sparkSpeed[2] * vfx.scale)
	s.SpreadAngle = if direction then Vector2.new(55, 55) else Vector2.new(180, 180)
	s:Emit(vfx.particles)
	local core = slot.core
	if core then
		core.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
		core.Size = NumberSequence.new(size * 5, size * 7)
		core:Emit(1)
	end
end

export type DustKind = "Dash" | "Jump" | "Land"

-- Dust puff. `direction` is where the dust should travel (e.g. opposite the dash);
-- `intensity` scales size and count (e.g. landing fall speed, 0-1.5).
function HitSpark.PlayDust(kind: DustKind, position: Vector3, direction: Vector3?, intensity: number?)
	local spec = Config.VFX.dust[kind]
	if not spec then
		return
	end
	local k = math.clamp(intensity or 1, 0.25, 1.5)
	local slot = takeSlot()
	place(slot.attachment, position, direction or Vector3.yAxis)
	if slot.dustIsAsset then
		emitAsset(slot.dust, spec.particles, k)
		return
	end
	local d = slot.dust[1]
	d.Size = NumberSequence.new(spec.size * k * 0.6, spec.size * k)
	d.Speed = NumberRange.new(spec.speed[1] * k, spec.speed[2] * k)
	d.Lifetime = NumberRange.new(spec.lifetime[1], spec.lifetime[2])
	-- Dash sprays in a cone behind the fighter; jump/land fan out sideways along the floor.
	d.SpreadAngle = if kind == "Dash" then Vector2.new(25, 25) else Vector2.new(85, 10)
	d:Emit(math.max(1, math.round(spec.particles * k)))
end

return HitSpark
