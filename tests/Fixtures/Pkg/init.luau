--!strict
-- Fixture for tests/Example.spec.luau. A folder module, like a Rojo ModuleScript with children.

return {
	Child = require("@self/Child"), -- inside this folder (Roblox: script.Child)
	Sibling = require("./Sibling"), -- next to this folder (Roblox: script.Parent.Sibling)
}
