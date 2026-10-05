--!strict
--[[
	Draws defense for any fighter: a shield bubble that shrinks and reddens as the shield wears
	down, and a see-through look while a dodge is intangible.

		DefenseView.update(key, model, fighterState, ctx)  -- every render frame per fighter
		DefenseView.remove(key)                            -- when that fighter goes away

	`key` is any stable id for the fighter; `model` is what to make see-through (a character or
	the training dummy).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Fighter = require(Shared:WaitForChild("Combat"):WaitForChild("Fighter"))
local StageGeometry = require(Shared:WaitForChild("Stage"):WaitForChild("StageGeometry"))
local Config = require("./Config")

local DefenseView = {}

type Entry = { Bubble: Part?, Model: Instance?, SeeThrough: boolean }

local entries: { [any]: Entry } = {}

local function makeBubble(): Part
	local bubble = Instance.new("Part")
	bubble.Name = "ShieldBubble"
	bubble.Shape = Enum.PartType.Ball
	bubble.Material = Enum.Material.Neon
	bubble.Anchored = true
	bubble.CanCollide = false
	bubble.CanQuery = false
	bubble.CanTouch = false
	bubble.CastShadow = false
	bubble.Transparency = Config.ShieldTransparency
	return bubble
end

local function setSeeThrough(model: Instance, on: boolean)
	local value = if on then Config.DodgeTransparency else 0
	if model:IsA("BasePart") then
		model.LocalTransparencyModifier = value
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.LocalTransparencyModifier = value
		end
	end
end

function DefenseView.update(key: any, model: Instance?, f: Fighter.State, ctx: Fighter.Context)
	local entry = entries[key]
	if not entry then
		entry = { Bubble = nil, Model = model, SeeThrough = false }
		entries[key] = entry
	end

	-- Shield bubble.
	local bubble = entry.Bubble
	if Fighter.isShielding(f) then
		if not bubble then
			bubble = makeBubble()
			entry.Bubble = bubble
		end
		local fraction = math.clamp(f.Shield / ctx.Combat.Defense.ShieldMax, 0, 1)
		local radius = Config.ShieldRadiusEmpty + (Config.ShieldRadiusFull - Config.ShieldRadiusEmpty) * fraction
		local b = bubble :: Part
		b.Size = Vector3.one * radius * 2
		b.CFrame = CFrame.new(f.Body.X, f.Body.Y + ctx.Movement.BodyHeight / 2, StageGeometry.PlaneZ)
		b.Color = Config.ShieldEmptyColor:Lerp(Config.ShieldFullColor, fraction)
		b.Parent = Workspace
	elseif bubble then
		bubble.Parent = nil
	end

	-- See-through while dodging. Only touch the parts when it changes (or the model does).
	local seeThrough = Fighter.isIntangible(f, ctx)
	if model and (seeThrough ~= entry.SeeThrough or model ~= entry.Model) then
		setSeeThrough(model, seeThrough)
	end
	entry.SeeThrough = seeThrough
	entry.Model = model
end

function DefenseView.remove(key: any)
	local entry = entries[key]
	if not entry then
		return
	end
	if entry.Bubble then
		entry.Bubble:Destroy()
	end
	if entry.Model and entry.SeeThrough then
		setSeeThrough(entry.Model, false)
	end
	entries[key] = nil
end

-- Removes every entry whose key isn't in `keep`.
function DefenseView.keepOnly(keep: { [any]: boolean })
	for key in entries do
		if not keep[key] then
			DefenseView.remove(key)
		end
	end
end

return DefenseView
