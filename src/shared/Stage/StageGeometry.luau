--!strict
--[[
	Turns the stage parts in the Workspace into the 2D rects that Movement collides with.

	Builders tag stage parts in Studio (Tag Editor / Properties > Tags):
	- "StageSolid": solid on every side (main stage, walls).
	- "StagePlatform": pass-through; fighters land on top, jump up through it, and drop
	  through by pressing down.
	- "StageSpawn": where fighters appear (its position; it should be invisible and non-colliding).

	Every stage is played on the plane Z = PlaneZ. Parts are read by their world bounding
	box, so keep them unrotated or rotated in 90-degree steps (slopes aren't supported yet).
]]

local CollectionService = game:GetService("CollectionService")

local Movement = require(script.Parent.Parent.Movement.Movement)

local StageGeometry = {}

StageGeometry.PlaneZ = 0
StageGeometry.SolidTag = "StageSolid"
StageGeometry.PlatformTag = "StagePlatform"
StageGeometry.SpawnTag = "StageSpawn"

-- The part's world-space bounding box, so rotated parts come out the right way round.
local function toRect(part: BasePart): Movement.Rect
	local cf = part.CFrame
	local size = part.Size / 2
	local half = Vector3.new(
		math.abs(cf.XVector.X) * size.X + math.abs(cf.YVector.X) * size.Y + math.abs(cf.ZVector.X) * size.Z,
		math.abs(cf.XVector.Y) * size.X + math.abs(cf.YVector.Y) * size.Y + math.abs(cf.ZVector.Y) * size.Z,
		0
	)
	local p = cf.Position
	return { MinX = p.X - half.X, MaxX = p.X + half.X, MinY = p.Y - half.Y, MaxY = p.Y + half.Y }
end

local function taggedParts(tag: string): { BasePart }
	local parts = {}
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsA("BasePart") and instance:IsDescendantOf(workspace) then
			table.insert(parts, instance)
		end
	end
	return parts
end

function StageGeometry.read(): Movement.Stage
	local stage: Movement.Stage = { Solids = {}, Platforms = {} }
	for _, part in taggedParts(StageGeometry.SolidTag) do
		table.insert(stage.Solids, toRect(part))
	end
	for _, part in taggedParts(StageGeometry.PlatformTag) do
		table.insert(stage.Platforms, toRect(part))
	end
	return stage
end

-- The spawn point's (X, Y), or nil if the stage has none (or it hasn't streamed in yet).
function StageGeometry.spawnPoint(): (number?, number?)
	local spawn = taggedParts(StageGeometry.SpawnTag)[1]
	if spawn then
		return spawn.Position.X, spawn.Position.Y
	end
	return nil, nil
end

-- Fires whenever stage parts are added or removed, so callers can read the stage again.
function StageGeometry.onChanged(callback: () -> ()): { RBXScriptConnection }
	local connections = {}
	for _, tag in { StageGeometry.SolidTag, StageGeometry.PlatformTag, StageGeometry.SpawnTag } do
		table.insert(connections, CollectionService:GetInstanceAddedSignal(tag):Connect(callback))
		table.insert(connections, CollectionService:GetInstanceRemovedSignal(tag):Connect(callback))
	end
	return connections
end

return StageGeometry
