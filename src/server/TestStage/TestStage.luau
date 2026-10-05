--!strict
--[[
	Builds a simple grey test stage when the place has no stage yet, so movement can be
	tried in Studio before real stages exist. Once builders add tagged stage parts (see
	src/shared/Stage/StageGeometry.luau), this does nothing.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StageGeometry = require(ReplicatedStorage.Shared.Stage.StageGeometry)

local TestStage = {}

-- Centre X, top Y and width of each piece, in studs. Matches a Battlefield-style layout.
local DEPTH = 30
local MAIN = { X = 0, Top = 100, Width = 110, Thickness = 10 }
local PLATFORMS = {
	{ X = -28, Top = 118, Width = 24 },
	{ X = 28, Top = 118, Width = 24 },
	{ X = 0, Top = 136, Width = 24 },
}
local PLATFORM_THICKNESS = 1
local SPAWN = { X = 0, Y = 110 }

local function makePart(name: string, x: number, top: number, width: number, thickness: number, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = Vector3.new(width, thickness, DEPTH)
	part.Position = Vector3.new(x, top - thickness / 2, StageGeometry.PlaneZ)
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = parent
	return part
end

function TestStage.buildIfMissing()
	if #CollectionService:GetTagged(StageGeometry.SolidTag) > 0 then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "TestStage"

	local main = makePart("Main", MAIN.X, MAIN.Top, MAIN.Width, MAIN.Thickness, folder)
	main.Color = Color3.fromRGB(110, 110, 120)
	main:AddTag(StageGeometry.SolidTag)

	for i, p in PLATFORMS do
		local platform = makePart(`Platform{i}`, p.X, p.Top, p.Width, PLATFORM_THICKNESS, folder)
		platform.Color = Color3.fromRGB(170, 170, 185)
		platform.CanCollide = false -- movement code handles it; physics would block jumping through
		platform:AddTag(StageGeometry.PlatformTag)
	end

	local spawn = Instance.new("Part")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.Transparency = 1
	spawn.Size = Vector3.one
	spawn.Position = Vector3.new(SPAWN.X, SPAWN.Y, StageGeometry.PlaneZ)
	spawn:AddTag(StageGeometry.SpawnTag)
	spawn.Parent = folder

	folder.Parent = workspace
end

return TestStage
