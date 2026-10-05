--[[
	Character data template.

	To add a character: copy this file to `src/shared/Characters/<Name>.luau`
	and fill it in. One file per character, so balance changes to different
	characters never conflict. Files starting with "_" are skipped by loaders.

	The model lives in Studio at `ReplicatedStorage.Assets.Characters.<Name>`
	and must have a HumanoidRootPart plus hitbox attachments named
	`Hitbox_<Part>` (e.g. `Hitbox_RightHand`).

	Units: frames assume 60 fps. Angles are degrees (0 = forward, 90 = up).
	Positions/sizes are studs, relative to the HumanoidRootPart.
]]

return {
	DisplayName = "Template",
	Model = "Template", -- name under ReplicatedStorage.Assets.Characters

	Stats = {
		Weight = 100, -- higher = less knockback taken
		WalkSpeed = 16,
		RunSpeed = 24,
		JumpPower = 50,
		AirJumps = 1,
		FallSpeed = 1.0, -- gravity multiplier
	},

	-- Asset IDs from Studio's Animation Editor ("rbxassetid://<id>").
	-- Leave "" until the animation is published.
	Animations = {
		Idle = "",
		Run = "",
		Jump = "",
		Hurt = "",
	},

	Moves = {
		Jab = {
			Animation = "",
			Damage = 3, -- percent added to the target
			BaseKnockback = 10,
			KnockbackGrowth = 20, -- how much knockback scales with target's percent
			Angle = 30,
			Startup = 3, -- frames before the hitbox is active
			Active = 2, -- frames the hitbox is active
			Endlag = 8, -- frames of recovery after
			Hitbox = {
				Attachment = "Hitbox_RightHand",
				Offset = Vector3.new(0, 0, 0),
				Size = Vector3.new(2, 2, 2),
			},
		},
	},
}
