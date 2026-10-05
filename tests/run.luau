--!strict
-- Runs every test file listed below with the plain Luau CLI: luau tests/run.luau

local suites: { [string]: { [string]: () -> () } } = {
	Movement = require("./Movement.spec"),
}

local passed, failed = 0, 0
for suiteName, tests in suites do
	local names = {}
	for name in tests do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in names do
		local ok, err = pcall(tests[name])
		if ok then
			passed += 1
		else
			failed += 1
			print(`FAIL {suiteName}: {name}\n    {err}`)
		end
	end
end

print(`{passed} passed, {failed} failed`)
if failed > 0 then
	error("tests failed", 0)
end
