--!strict
-- Fixture for tests/Example.spec.luau.

return {
	Name = "Child",
	Offset = Vector3.new(1, 2, 3), -- Roblox datatypes are globals in modules the runner loads
	Sibling = require("../Sibling"), -- tests/Fixtures/Sibling (Roblox: script.Parent.Parent.Sibling)
}
