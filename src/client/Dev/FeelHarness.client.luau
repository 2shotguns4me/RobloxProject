--!strict
--[[
	Studio-only game-feel preview. NOT gameplay: two grey placeholder blocks on a grey floor.

	Keys:  1 light  2 medium  3 heavy  4 KO (final)  |  5 dash dust  6 jump dust  7 land dust
	       8 toggle Default / Competitive settings preset  |  9 blast-zone exit burst
	Hits alternate direction (A hits B, then B hits A). You are treated as the attacker, so the
	attacker rumble plays; hold Shift to be the victim instead.

	Off by default, since Play now spawns you as a moving fighter. Turn it on by adding a
	boolean Workspace attribute "FeelHarness" = true in Studio; it then owns the camera.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

if not RunService:IsStudio() or Workspace:GetAttribute("FeelHarness") ~= true then
	return
end

local Feel = require("../Feel/Feel")
local FightCamera = require("../Camera/FightCamera")
local Settings = require("../Settings/Settings")

local FLOOR_Y = 0
local DUMMY_SIZE = Vector3.new(3, 5, 2)

local root = Instance.new("Folder")
root.Name = "FeelHarness (placeholders)"

local floor = Instance.new("Part")
floor.Name = "TestFloor"
floor.Anchored = true
floor.Size = Vector3.new(120, 2, 24)
floor.Position = Vector3.new(0, FLOOR_Y - 1, 0)
floor.Color = Color3.fromRGB(110, 110, 110)
floor.Material = Enum.Material.SmoothPlastic
floor.Parent = root

local function makeDummy(name: string, x: number): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.Size = DUMMY_SIZE
	p.Color = Color3.fromRGB(160, 160, 160)
	p.Material = Enum.Material.SmoothPlastic
	p.Position = Vector3.new(x, FLOOR_Y + DUMMY_SIZE.Y / 2, 0)

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(140, 30)
	gui.StudsOffset = Vector3.new(0, DUMMY_SIZE.Y / 2 + 1, 0)
	gui.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = `{name} (placeholder)`
	label.Parent = gui
	gui.Parent = p

	p.Parent = root
	return p
end

local dummyA = makeDummy("DummyA", -6)
local dummyB = makeDummy("DummyB", 6)
local basePositions = { [dummyA] = dummyA.Position, [dummyB] = dummyB.Position }
root.Parent = Workspace

-- Help overlay.
local player = Players.LocalPlayer
local screen = Instance.new("ScreenGui")
screen.Name = "FeelHarnessHelp"
screen.ResetOnSpawn = false
local help = Instance.new("TextLabel")
help.AnchorPoint = Vector2.new(0, 1)
help.Position = UDim2.new(0, 12, 1, -12)
help.Size = UDim2.fromOffset(460, 92)
help.BackgroundColor3 = Color3.new(0, 0, 0)
help.BackgroundTransparency = 0.4
help.TextColor3 = Color3.new(1, 1, 1)
help.Font = Enum.Font.Code
help.TextSize = 14
help.TextXAlignment = Enum.TextXAlignment.Left
help.TextYAlignment = Enum.TextYAlignment.Top
help.Parent = screen
screen.Parent = player:WaitForChild("PlayerGui")

local lastLine = "ready"
local function refreshHelp()
	help.Text = table.concat({
		" FEEL HARNESS (Studio only, placeholders)",
		" 1-4 light/medium/heavy/KO   5-7 dash/jump/land dust",
		" 8 preset ("
			.. (if Settings.Get("slowMo") then "Default" else "Competitive")
			.. ")   9 blast exit   Shift = be victim",
		" " .. lastLine,
	}, "\n")
end
refreshHelp()
Settings.Changed:Connect(refreshHelp)

FightCamera.SetBounds({ minX = -60, maxX = 60, minY = -6, maxY = 40 })
FightCamera.Start()

local attackerIsA = true
local DAMAGE = { [Enum.KeyCode.One] = 4, [Enum.KeyCode.Two] = 10, [Enum.KeyCode.Three] = 16, [Enum.KeyCode.Four] = 18 }

local function playHit(key: Enum.KeyCode)
	local attacker = if attackerIsA then dummyA else dummyB
	local victim = if attackerIsA then dummyB else dummyA
	attackerIsA = not attackerIsA
	local dirX = if victim.Position.X > attacker.Position.X then 1 else -1
	local beVictim = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
	local isKO = key == Enum.KeyCode.Four
	local contact = victim.Position - Vector3.new(dirX * DUMMY_SIZE.X / 2, 0, 0)
	local frames, result = Feel.PlayHit({
		position = contact,
		victim = victim,
		damage = DAMAGE[key],
		isKO = isKO,
		isFinalKO = isKO,
		direction = Vector3.new(dirX, if isKO then 0.6 else 0.25, 0).Unit,
		attackerIsLocal = not beVictim,
		victimIsLocal = beVictim,
	})
	lastLine = string.format(
		"%s: hitstop %d f (%.3f s), timeScale %.2f",
		result.tier,
		frames,
		result.victimSeconds,
		Feel.GetTimeScale()
	)
	refreshHelp()
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local key = input.KeyCode
	if DAMAGE[key] then
		playHit(key)
	elseif key == Enum.KeyCode.Five then
		Feel.PlayMovement(
			"Dash",
			dummyA.Position - Vector3.new(0, DUMMY_SIZE.Y / 2, 0),
			{ direction = Vector3.new(-1, 0.2, 0) }
		)
	elseif key == Enum.KeyCode.Six then
		Feel.PlayMovement("Jump", dummyA.Position - Vector3.new(0, DUMMY_SIZE.Y / 2, 0))
	elseif key == Enum.KeyCode.Seven then
		Feel.PlayMovement("Land", dummyA.Position - Vector3.new(0, DUMMY_SIZE.Y / 2, 0), { intensity = 1.2 })
	elseif key == Enum.KeyCode.Eight then
		Settings.ApplyPreset(if Settings.Get("slowMo") then "Competitive" else "Default")
	elseif key == Enum.KeyCode.Nine then
		Feel.PlayBlastZoneExit(Vector3.new(55, 20, 0), Vector3.new(1, 0.3, 0), true)
	end
end)

-- Placeholder "renderer": dummies stay put; only the cosmetic hitstop shake moves them.
RunService.RenderStepped:Connect(function()
	for part, base in basePositions do
		part.Position = base + Feel.GetVisualOffset(part)
	end
	FightCamera.SetTargets({ basePositions[dummyA], basePositions[dummyB] })
end)
