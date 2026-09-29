--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Knit = require(ReplicatedStorage.Packages.Knit)
Knit.AddServices(ServerScriptService.Server.Services)

local started, result = Knit.Start():await()
assert(
	started,
	string.format("Pro Wrestling Leagues server bootstrap failed: %s", tostring(result))
)
assert(Knit.GetService("MatchService") ~= nil, "MatchService was not loaded")
assert(Knit.GetService("CombatService") ~= nil, "CombatService was not loaded")
print("PRO_WRESTLING_LEAGUES_SERVER_BOOTSTRAP_PASS")
