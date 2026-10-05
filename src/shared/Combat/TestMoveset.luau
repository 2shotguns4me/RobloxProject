--!strict
--[[
	PLACEHOLDER moveset for testing the hit pipeline. Not a fighter design: the team designs
	real movesets in docs/characters/, and this goes away once the first fighter exists.

	Same move fields as src/shared/Characters/_Template.luau. Hitbox.Offset is relative to the
	fighter's centre (X = forward, Y = up); Attachment isn't used yet. Numbers follow the
	"baseline example" column in docs/research/mechanics-design-prompt.md.
]]

return {
	Jab = {
		Animation = "",
		Damage = 3,
		BaseKnockback = 10,
		KnockbackGrowth = 40,
		Angle = 30,
		Startup = 3,
		Active = 2,
		Endlag = 9,
		Hitbox = { Attachment = "", Offset = Vector3.new(2, 0.5, 0), Size = Vector3.new(2.5, 2, 2) },
	},

	SideTilt = {
		Animation = "",
		Damage = 8,
		BaseKnockback = 20,
		KnockbackGrowth = 80,
		Angle = 35,
		Startup = 7,
		Active = 3,
		Endlag = 16,
		Hitbox = { Attachment = "", Offset = Vector3.new(2.75, 0, 0), Size = Vector3.new(3.5, 2.5, 2) },
	},

	SideSmash = {
		Animation = "",
		Damage = 17,
		BaseKnockback = 30,
		KnockbackGrowth = 95,
		Angle = 40,
		Startup = 16,
		Active = 3,
		Endlag = 30,
		Hitbox = { Attachment = "", Offset = Vector3.new(3, 0.5, 0), Size = Vector3.new(4, 3, 2) },
	},

	NeutralAir = {
		Animation = "",
		Damage = 9,
		BaseKnockback = 20,
		KnockbackGrowth = 70,
		Angle = 45,
		Startup = 7,
		Active = 8,
		Endlag = 14,
		LandingLag = 10,
		Hitbox = { Attachment = "", Offset = Vector3.new(0, 0, 0), Size = Vector3.new(6, 6, 2) },
	},
}
