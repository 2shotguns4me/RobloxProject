--!strict
--[[
	Test runner. From the repo root:

		lune run tests/run            -- every spec
		lune run tests/run Buffer     -- only spec files whose path contains "Buffer"

	Finds every `tests/**/*.spec.luau`. Each spec returns `function(t)` and registers tests with
	`t.test(name, fn)`. Assertions: `t.eq` (deep), `t.near`, `t.truthy`, `t.throws`.

	Modules (specs and everything they require) are loaded by this runner, not by Lune's own
	`require`, so they can see Roblox globals. Lune's global table is read-only, so the datatypes from
	`@lune/roblox` (Vector2, Vector3, CFrame, Color3, Instance, Enum, ...) plus `task` are injected
	into each module's environment instead. `require` follows the same require-by-string rules as
	Roblox and Lune:
		"./X"      sibling of this module (Roblox: script.Parent.X)
		"../X"     one level further up (Roblox: script.Parent.Parent.X)
		"@self/X"  child of this module (Roblox: script.X); use it inside init.luau
	A folder with an `init.luau` is the module itself, exactly like a Rojo-synced ModuleScript
	with children. "@lune/..." libraries are passed through.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local luneTask = require("@lune/task")

local TESTS_DIR = "tests"
local SPEC_SUFFIX = ".spec.luau"

local LUNE_LIBS: { [string]: () -> any } = {
	["@lune/fs"] = function()
		return fs
	end,
	["@lune/process"] = function()
		return process
	end,
	["@lune/roblox"] = function()
		return roblox
	end,
	["@lune/task"] = function()
		return luneTask
	end,
}

-- Roblox-style globals available to every loaded module.
local robloxGlobals: { [string]: any } = { task = luneTask }
for name, value in roblox :: any do
	if type(name) == "string" and string.match(name, "^%u") then
		robloxGlobals[name] = value
	end
end

---------------------------------------------------------------------------------------------------
-- Module loading
---------------------------------------------------------------------------------------------------

type ModulePath = { string }

local LOADING = {}
local moduleCache: { [string]: any } = {}

local function splitPath(path: string): ModulePath
	local parts = {}
	for part in string.gmatch(path, "[^/]+") do
		table.insert(parts, part)
	end
	return parts
end

-- "a/b/init.luau" -> { "a", "b" }; "a/b.luau" -> { "a", "b" }
local function modulePathOf(filePath: string): ModulePath
	local parts = splitPath(filePath)
	local last = parts[#parts]
	if last == "init.luau" or last == "init.lua" then
		table.remove(parts)
	else
		local stem = string.gsub(last, "%.luau?$", "")
		parts[#parts] = stem
	end
	return parts
end

local function findModuleFile(parts: ModulePath): string?
	local base = table.concat(parts, "/")
	for _, candidate in { base .. ".luau", base .. ".lua", base .. "/init.luau", base .. "/init.lua" } do
		if fs.isFile(candidate) then
			return candidate
		end
	end
	return nil
end

local loadFile: (filePath: string) -> any

local function requireFrom(requirer: ModulePath, request: string): any
	local lib = LUNE_LIBS[request]
	if lib then
		return lib()
	end

	local segments = splitPath(request)
	local first = segments[1]
	local target = table.clone(requirer)
	if first == "." or first == ".." then
		table.remove(target)
		if first == ".." then
			table.remove(target)
		end
	elseif first ~= "@self" then
		error(`require("{request}"): paths must start with "./", "../" or "@self/"`, 3)
	end

	for i = 2, #segments do
		local segment = segments[i]
		if segment == ".." then
			if #target == 0 then
				error(`require("{request}"): path goes above the repo root`, 3)
			end
			table.remove(target)
		elseif segment ~= "." then
			table.insert(target, segment)
		end
	end

	local filePath = findModuleFile(target)
	if not filePath then
		local from = table.concat(requirer, "/")
		error(`require("{request}") from {from}: no module at {table.concat(target, "/")}`, 3)
	end
	return loadFile(filePath)
end

loadFile = function(filePath: string): any
	local cached = moduleCache[filePath]
	if cached == LOADING then
		error(`cyclic require of {filePath}`, 0)
	elseif cached ~= nil then
		return cached
	end

	local modulePath = modulePathOf(filePath)
	local env = table.clone(robloxGlobals)
	env.require = function(request: string): any
		return requireFrom(modulePath, request)
	end

	local chunk = luau.load(fs.readFile(filePath), {
		debugName = "@" .. filePath,
		environment = env,
	})

	moduleCache[filePath] = LOADING
	local ok, result = pcall(chunk)
	if not ok then
		moduleCache[filePath] = nil
		error(result, 0)
	end
	if result == nil then
		moduleCache[filePath] = nil
		error(`{filePath} did not return a value`, 0)
	end
	moduleCache[filePath] = result
	return result
end

---------------------------------------------------------------------------------------------------
-- Assertions
---------------------------------------------------------------------------------------------------

local function show(value: any, depth: number?): string
	local level = depth or 0
	if type(value) == "string" then
		return string.format("%q", value)
	elseif type(value) ~= "table" then
		return tostring(value)
	elseif level >= 2 then
		return "{...}"
	end

	local keys = {}
	for key in value do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)

	local items = {}
	for i, key in keys do
		if i > 8 then
			table.insert(items, "...")
			break
		end
		table.insert(items, `{tostring(key)} = {show(value[key], level + 1)}`)
	end
	return "{ " .. table.concat(items, ", ") .. " }"
end

local function keyLabel(key: any): string
	if type(key) == "string" and string.match(key, "^[%a_][%w_]*$") then
		return "." .. key
	end
	return "[" .. show(key) .. "]"
end

-- Returns nil if equal, otherwise the path to and values of the first difference.
local function findDifference(actual: any, expected: any, path: string): (string?, any, any)
	if actual == expected then
		return nil, nil, nil
	end
	if type(actual) ~= "table" or type(expected) ~= "table" then
		return path, actual, expected
	end
	for key, value in expected do
		local where, a, e = findDifference(actual[key], value, path .. keyLabel(key))
		if where then
			return where, a, e
		end
	end
	for key, value in actual do
		if expected[key] == nil then
			return path .. keyLabel(key), value, nil
		end
	end
	return nil, nil, nil
end

local function fail(message: string, custom: string?)
	-- Level 3 points the error at the spec line that called the assertion.
	error(if custom then `{custom}: {message}` else message, 3)
end

local VECTOR_AXES: { [string]: { string } } = {
	Vector2 = { "X", "Y" },
	Vector3 = { "X", "Y", "Z" },
}

local function isNear(actual: any, expected: any, epsilon: number): boolean
	if type(actual) == "number" and type(expected) == "number" then
		return math.abs(actual - expected) <= epsilon
	end
	local axes = VECTOR_AXES[typeof(actual)]
	if axes and typeof(actual) == typeof(expected) then
		for _, axis in axes do
			if math.abs(actual[axis] - expected[axis]) > epsilon then
				return false
			end
		end
		return true
	end
	error(`t.near compares numbers, Vector2s or Vector3s, got {typeof(actual)} and {typeof(expected)}`, 3)
end

type Test = { name: string, fn: () -> () }

local function makeTestKit(tests: { Test })
	local t = {}

	function t.test(name: string, fn: () -> ())
		table.insert(tests, { name = name, fn = fn })
	end

	function t.eq(actual: any, expected: any, msg: string?)
		local where, a, e = findDifference(actual, expected, "value")
		if where then
			fail(`expected {show(e)}, got {show(a)} (at {where})`, msg)
		end
	end

	function t.near(actual: any, expected: any, epsilon: number?, msg: string?)
		local eps = epsilon or 1e-6
		if not isNear(actual, expected, eps) then
			fail(`expected {show(expected)} within {eps}, got {show(actual)}`, msg)
		end
	end

	function t.truthy(value: any, msg: string?)
		if not value then
			fail(`expected a truthy value, got {show(value)}`, msg)
		end
	end

	function t.throws(fn: () -> (), msg: string?): any
		local ok, err = pcall(fn)
		if ok then
			fail("expected the function to throw, but it returned", msg)
		end
		return err
	end

	return t
end

---------------------------------------------------------------------------------------------------
-- Discovery and running
---------------------------------------------------------------------------------------------------

local function findSpecs(dir: string, found: { string })
	local names = fs.readDir(dir)
	table.sort(names)
	for _, name in names do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			findSpecs(path, found)
		elseif string.sub(name, -#SPEC_SUFFIX) == SPEC_SUFFIX then
			table.insert(found, path)
		end
	end
end

if not fs.isDir(TESTS_DIR) or not fs.isFile("default.project.json") then
	print("Run this from the repo root: lune run tests/run")
	process.exit(1)
end

local filter = process.args[1]
local specFiles = {}
findSpecs(TESTS_DIR, specFiles)

local passed, failed = 0, 0
for _, specFile in specFiles do
	if filter and not string.find(specFile, filter, 1, true) then
		continue
	end

	print(specFile)
	local tests: { Test } = {}
	local ok, err = pcall(function()
		local spec = loadFile(specFile)
		if type(spec) ~= "function" then
			error("spec must return function(t)", 0)
		end
		spec(makeTestKit(tests))
	end)
	if not ok then
		failed += 1
		print(`  FAIL (loading spec)\n       {err}`)
		continue
	end

	for _, test in tests do
		local testOk, testErr = pcall(test.fn)
		if testOk then
			passed += 1
			print(`  pass  {test.name}`)
		else
			failed += 1
			print(`  FAIL  {test.name}\n        {testErr}`)
		end
	end
end

print(`\n{passed} passed, {failed} failed`)
if passed + failed == 0 then
	print("No tests ran.")
	process.exit(1)
end
process.exit(if failed > 0 then 1 else 0)
