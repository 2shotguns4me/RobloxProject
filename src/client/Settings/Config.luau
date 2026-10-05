--!strict
--[[
	Player settings: defaults, value rules and presets.
	Feel values follow docs/research/game-feel.md 1.9 ("Settings to ship").
	Input values (tapJump, shieldMode) are owned by the input layer; they only live here so
	all player settings share one store and one future save.
]]

local Config = {}

export type ShieldMode = "hold" | "toggle"

export type Values = {
	screenShake: number, -- 0-1 multiplier on camera shake
	flashIntensity: number, -- 0-1 multiplier on hit flashes / tints
	reduceFlashing: boolean, -- white flashes become outline changes; no red full-screen tint
	rumble: boolean, -- controller rumble + phone haptics
	slowMo: boolean, -- KO slow-mo and zoom punch
	tapJump: boolean, -- jump by pushing up (input team)
	shieldMode: ShieldMode, -- "hold" or "toggle" (input team)
}

Config.Defaults = {
	screenShake = 0.7,
	flashIntensity = 1,
	reduceFlashing = false,
	rumble = true,
	slowMo = true,
	tapJump = false,
	shieldMode = "hold",
} :: Values

-- Validation rules. Numbers are clamped to [min, max]; enums must be one of `values`.
Config.Rules = {
	screenShake = { kind = "number", min = 0, max = 1 },
	flashIntensity = { kind = "number", min = 0, max = 1 },
	reduceFlashing = { kind = "boolean" },
	rumble = { kind = "boolean" },
	slowMo = { kind = "boolean" },
	tapJump = { kind = "boolean" },
	shieldMode = { kind = "enum", values = { "hold", "toggle" } },
} :: { [string]: { kind: string, min: number?, max: number?, values: { string }? } }

-- Presets only set the keys they list; input settings are left alone.
Config.Presets = {
	Default = {
		screenShake = 0.7,
		flashIntensity = 1,
		reduceFlashing = false,
		slowMo = true,
	},
	Competitive = {
		screenShake = 0.25,
		flashIntensity = 0.6,
		reduceFlashing = true,
		slowMo = false,
	},
} :: { [string]: { [string]: any } }

return Config
