--!strict
--[[
	Placeholder damage % label floating over a fighter. The real HUD (Smash-style % panels at
	the bottom of the screen) gets built in Studio with the rest of the UI.
]]

local Config = require("./Config")

local PercentLabel = {}

function PercentLabel.create(adornee: BasePart): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = "PercentLabel"
	gui.Size = UDim2.fromOffset(110, 40)
	gui.StudsOffset = Vector3.new(0, Config.LabelStudsAbove, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = adornee

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = "0%"
	label.Parent = gui

	gui.Parent = adornee
	return label
end

function PercentLabel.set(label: TextLabel, percent: number)
	label.Text = `{math.floor(percent)}%`
	local heat = math.clamp(percent / Config.RedAtPercent, 0, 1)
	label.TextColor3 = Color3.new(1, 1, 1):Lerp(Config.HighDamageColor, heat)
end

return PercentLabel
