--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local TestEZ = require(ReplicatedStorage.DevPackages.TestEZ)
local specs = ServerScriptService.Tests.server:GetChildren()
table.sort(specs, function(left, right)
	return left.Name < right.Name
end)

local passed = 0
local failed = 0
local skipped = 0
for _, spec in specs do
	if not spec:IsA("ModuleScript") or not spec.Name:match("%.spec$") then
		continue
	end
	print(`Running {spec.Name}`)
	local results = TestEZ.TestBootstrap:run({ spec })
	passed += results.successCount
	failed += results.failureCount
	skipped += results.skippedCount
end

print(`{passed} passed, {failed} failed, {skipped} skipped`)

assert(failed == 0, string.format("%d Pro Wrestling Leagues tests failed", failed))
print("PRO_WRESTLING_LEAGUES_TESTS_PASS")
