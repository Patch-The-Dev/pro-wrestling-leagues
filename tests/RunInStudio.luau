--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local TestEZ = require(ReplicatedStorage.DevPackages.TestEZ)
local results = TestEZ.TestBootstrap:run({ ServerScriptService.Tests.server })

assert(
	results.failureCount == 0,
	string.format("%d Pro Wrestling Leagues tests failed", results.failureCount)
)
print("PRO_WRESTLING_LEAGUES_TESTS_PASS")
