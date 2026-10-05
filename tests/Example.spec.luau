--!strict
--[[
	Checks the test runner itself (assertions, Roblox globals, require-by-string resolution)
	and that every character data file in src/shared/Characters has usable frame data.
	Copy this layout for new specs: tests/<System>/<Module>.spec.luau.
]]

local fs = require("@lune/fs")

local Pkg = require("./Fixtures/Pkg")

local CHARACTERS_DIR = "src/shared/Characters"

return function(t)
	t.test("eq compares tables deeply", function()
		t.eq({ a = 1, b = { 2, 3 } }, { a = 1, b = { 2, 3 } })
		t.throws(function()
			t.eq({ b = { 2 } }, { b = { 3 } })
		end)
		t.throws(function()
			t.eq({ a = 1, extra = true }, { a = 1 })
		end)
	end)

	t.test("near allows small differences in numbers and vectors", function()
		t.near(0.1 + 0.2, 0.3)
		t.near(Vector3.new(1, 2, 3), Vector3.new(1, 2, 3.05), 0.1)
		t.throws(function()
			t.near(1, 1.1)
		end)
	end)

	t.test("truthy and throws", function()
		t.truthy(0)
		local err = t.throws(function()
			error("boom")
		end)
		t.truthy(string.find(tostring(err), "boom", 1, true))
		t.throws(function()
			t.truthy(nil)
		end)
	end)

	t.test("Roblox datatypes are available as globals", function()
		local v = Vector2.new(3, 4)
		t.near(v.Magnitude, 5)
		t.eq(typeof(CFrame.new()), "CFrame")
		t.eq(Pkg.Child.Offset, Vector3.new(1, 2, 3))
	end)

	t.test("require-by-string follows the Roblox rules", function()
		-- init.luau is the folder module; @self/ reaches its children, ./ its siblings
		t.eq(Pkg.Child.Name, "Child")
		t.eq(Pkg.Sibling.Name, "Sibling")
		-- ../ goes up one more level; modules are cached, so both paths give the same table
		t.truthy(Pkg.Child.Sibling == Pkg.Sibling)
	end)

	t.test("every character data file has valid frame data", function()
		for _, fileName in fs.readDir(CHARACTERS_DIR) do
			local name = string.match(fileName, "^(.+)%.luau$")
			if not name then
				continue
			end
			local character = require(`../{CHARACTERS_DIR}/{name}`)
			t.truthy(type(character.DisplayName) == "string", `{name}: DisplayName`)
			for moveName, move in character.Moves do
				local where = `{name}.{moveName}`
				for _, field in { "Startup", "Active", "Endlag" } do
					local frames = move[field]
					t.truthy(type(frames) == "number" and frames >= 1 and frames % 1 == 0, `{where}.{field}`)
				end
				t.eq(typeof(move.Hitbox.Size), "Vector3", `{where}.Hitbox.Size`)
			end
		end
	end)
end
