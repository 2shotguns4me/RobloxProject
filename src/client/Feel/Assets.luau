--!strict
-- Optional asset lookup under ReplicatedStorage.Assets.<Folder>.<Name>. Never yields, never errors.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = {}

function Assets.find(folder: "VFX" | "Sounds", name: string): Instance?
	local root = ReplicatedStorage:FindFirstChild("Assets")
	local dir = root and root:FindFirstChild(folder)
	return dir and dir:FindFirstChild(name)
end

local function audioIdOf(inst: Instance): string?
	if inst:IsA("AudioPlayer") then
		local id = (inst :: AudioPlayer).Asset
		return if id ~= "" then id else nil
	elseif inst:IsA("Sound") then
		local id = (inst :: Sound).SoundId
		return if id ~= "" then id else nil
	end
	return nil
end

-- All usable audio IDs: non-empty entries of `configIds` plus any AudioPlayer/Sound named
-- `assetName` under Assets.Sounds (or inside a Folder with that name, as alternates).
function Assets.audioIds(configIds: { string }, assetName: string): { string }
	local ids = {}
	for _, id in configIds do
		if id ~= "" then
			table.insert(ids, id)
		end
	end
	local found = Assets.find("Sounds", assetName)
	if found then
		local direct = audioIdOf(found)
		if direct then
			table.insert(ids, direct)
		end
		for _, child in found:GetChildren() do
			local id = audioIdOf(child)
			if id then
				table.insert(ids, id)
			end
		end
	end
	return ids
end

return Assets
