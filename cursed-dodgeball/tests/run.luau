-- Headless test runner for the pure modules. Usage: luau tests/run.luau (from cursed-dodgeball/).
local TESTS = {
	"./Config.test",
	"./Balls.test",
	"./ShowState.test",
}

local passed, failed = 0, 0
local function makeT(name)
	local t = {}
	local function fail(msg)
		failed += 1
		print(("  FAIL [%s] %s"):format(name, msg))
	end
	function t.ok(cond, msg)
		if cond then passed += 1 else fail(msg or "expected truthy") end
	end
	function t.eq(a, b, msg)
		if a == b then passed += 1 else fail(("%s: expected %s, got %s"):format(msg or "eq", tostring(b), tostring(a))) end
	end
	return t
end

for _, path in TESTS do
	local ok, mod = pcall(require, path)
	if not ok then
		failed += 1
		print(("  FAIL [%s] could not load: %s"):format(path, tostring(mod)))
	else
		local ok2, err = pcall(mod, makeT(path))
		if not ok2 then
			failed += 1
			print(("  FAIL [%s] errored: %s"):format(path, tostring(err)))
		end
	end
end
print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then error("tests failed") end
