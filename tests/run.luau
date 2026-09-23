--!nocheck
-- Test runner: `lune run tests/run` (from the repository root).
-- Optional filter: `lune run tests/run -- economy` runs only spec files whose name contains "economy".

local fs = require("@lune/fs")
local process = require("@lune/process")
local luau = require("@lune/luau")

local Harness = require("./harness")

local filter = process.args[1]

---------------------------------------------------------------------------------------------------
-- expect()
---------------------------------------------------------------------------------------------------

local function deepEqual(a, b)
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for k, v in a do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local function show(value)
	if type(value) == "string" then
		return string.format("%q", value)
	end
	return tostring(value)
end

local function expect(actual)
	local e = {}
	local function fail(message)
		error(message, 3)
	end
	function e.toBe(expected)
		if actual ~= expected then
			fail(string.format("expected %s to be %s", show(actual), show(expected)))
		end
	end
	function e.never(expected)
		if actual == expected then
			fail(string.format("expected value not to be %s", show(expected)))
		end
	end
	function e.toEqual(expected)
		if not deepEqual(actual, expected) then
			fail(string.format("expected deep equality (%s vs %s)", show(actual), show(expected)))
		end
	end
	function e.toBeCloseTo(expected, epsilon)
		epsilon = epsilon or 1e-6
		if type(actual) ~= "number" or math.abs(actual - expected) > epsilon then
			fail(string.format("expected %s to be close to %s", show(actual), show(expected)))
		end
	end
	function e.toBeTruthy()
		if not actual then
			fail(string.format("expected %s to be truthy", show(actual)))
		end
	end
	function e.toBeFalsy()
		if actual then
			fail(string.format("expected %s to be falsy", show(actual)))
		end
	end
	function e.toBeNil()
		if actual ~= nil then
			fail(string.format("expected nil, got %s", show(actual)))
		end
	end
	function e.toBeGreaterThan(value)
		if not (actual > value) then
			fail(string.format("expected %s > %s", show(actual), show(value)))
		end
	end
	function e.toBeGreaterOrEqual(value)
		if not (actual >= value) then
			fail(string.format("expected %s >= %s", show(actual), show(value)))
		end
	end
	function e.toBeLessThan(value)
		if not (actual < value) then
			fail(string.format("expected %s < %s", show(actual), show(value)))
		end
	end
	function e.toBeLessOrEqual(value)
		if not (actual <= value) then
			fail(string.format("expected %s <= %s", show(actual), show(value)))
		end
	end
	function e.toContain(value)
		if type(actual) == "string" then
			if not string.find(actual, value, 1, true) then
				fail(string.format("expected %s to contain %s", show(actual), show(value)))
			end
		elseif not table.find(actual, value) then
			fail(string.format("expected table to contain %s", show(value)))
		end
	end
	function e.toThrow(pattern)
		local ok, err = pcall(actual)
		if ok then
			fail("expected function to throw")
		end
		if pattern and not string.find(tostring(err), pattern, 1, true) then
			fail(string.format("expected error containing %s, got %s", show(pattern), show(err)))
		end
	end
	return e
end

---------------------------------------------------------------------------------------------------
-- describe / it
---------------------------------------------------------------------------------------------------

local results = { passed = 0, failed = 0, failures = {} }

local function runSpec(fileName)
	local source = fs.readFile("tests/specs/" .. fileName)
	local stack = {}
	local tests = {}
	local ctx = {}
	function ctx.describe(name, body)
		table.insert(stack, name)
		body()
		table.remove(stack)
	end
	function ctx.it(name, body)
		table.insert(tests, { name = table.concat(stack, " > ") .. " > " .. name, body = body })
	end
	ctx.expect = expect
	ctx.Harness = Harness

	Harness.reset()
	local chunk = luau.load(source, { debugName = fileName })
	local ok, specFn = pcall(chunk)
	if not ok then
		results.failed += 1
		table.insert(results.failures, { name = fileName .. " (load)", err = specFn })
		return
	end
	local okDefine, defineErr = pcall(specFn, ctx)
	if not okDefine then
		results.failed += 1
		table.insert(results.failures, { name = fileName .. " (define)", err = defineErr })
		return
	end
	for _, test in tests do
		local passed, err = pcall(test.body)
		if passed then
			results.passed += 1
		else
			results.failed += 1
			table.insert(results.failures, { name = fileName .. ": " .. test.name, err = err })
		end
	end
end

local files = fs.readDir("tests/specs")
table.sort(files)
for _, fileName in files do
	if string.match(fileName, "%.spec%.luau$") and (not filter or string.find(fileName, filter, 1, true)) then
		runSpec(fileName)
	end
end

for _, failure in results.failures do
	print("\27[31mFAIL\27[0m " .. failure.name)
	print("     " .. tostring(failure.err))
end
print(string.format("\n%d passed, %d failed", results.passed, results.failed))
if results.failed > 0 then
	process.exit(1)
end
