local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StudioTestService = game:GetService("StudioTestService")
local arguments = StudioTestService:GetTestArgs()
if type(arguments) ~= "table" or arguments.suite ~= "WrestlingIntegration" then
	return
end
local ServerScriptService = game:GetService("ServerScriptService")
local errors = {}
local errorConnection = game:GetService("ScriptContext").Error:Connect(function(message, _, source)
	if
		source
		and (source:IsDescendantOf(ServerScriptService) or source:IsDescendantOf(ReplicatedStorage))
	then
		table.insert(errors, message)
	end
end)
ServerScriptService.Server.Enabled = true
local checks = 0
local function check(condition, message)
	checks += 1
	assert(condition, message)
end
local function awaitCondition(predicate, message, seconds)
	local deadline = os.clock() + (seconds or 20)
	repeat
		if predicate() then
			return
		end
		task.wait()
	until os.clock() >= deadline
	error(message)
end
local status = Instance.new("RemoteEvent")
status.Name = "RuntimeIntegrationStatus"
status.Parent = ReplicatedStorage
local replies = {}
local connection = status.OnServerEvent:Connect(function(player, phase, detail)
	replies[player] = { phase = phase, detail = detail }
end)
local floor = Instance.new("Part")
floor.Name = "IntegrationGround"
floor.Size = Vector3.new(1000, 1, 1000)
floor.Anchored = true
floor.Parent = workspace
local spawn = Instance.new("SpawnLocation")
spawn.Anchored = true
spawn.Position = Vector3.new(0, 2, 50)
spawn.Parent = workspace
local success, failure = pcall(function()
	local Knit = require(ReplicatedStorage.Packages.Knit)
	local started, startError = Knit.OnStart():await()
	check(started, tostring(startError))
	awaitCondition(function()
		return #Players:GetPlayers() == 2
	end, "Two test clients did not join", 75)
	local players = Players:GetPlayers()
	local dataService = Knit.GetService("DataService")
	awaitCondition(function()
		return dataService:IsLoaded(players[1]) and dataService:IsLoaded(players[2])
	end, "Actual player profiles did not load")
	for _, player in players do
		awaitCondition(function()
			return replies[player] and replies[player].phase == "ready"
		end, "Production client did not start", 45)
		check(replies[player].detail == true, "Client bootstrap or snapshot failed")
	end
	local function phase(player, name)
		replies[player] = nil
		status:FireClient(player, name)
		awaitCondition(function()
			return replies[player] and replies[player].phase == name
		end, "Client did not finish " .. name)
		check(replies[player].detail == true, "Client rejected " .. name)
	end
	local arena = Instance.new("Model")
	arena.Name = "IntegrationRing"
	arena:SetAttribute("ArenaId", "IntegrationRing")
	arena:SetAttribute("RequiredPlayers", 2)
	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	spawns.Parent = arena
	for index = 1, 2 do
		local point = Instance.new("Part")
		point.Name = tostring(index)
		point.Anchored = true
		point.CanCollide = false
		point.Transparency = 1
		point.CFrame = CFrame.new(index * 12, 4, 0)
		point.Parent = spawns
	end
	arena.Parent = workspace
	CollectionService:AddTag(arena, "WrestlingArena")
	local matchService = Knit.GetService("MatchService")
	local first, second = dataService:Get(players[1]), dataService:Get(players[2])
	local firstCash, secondCash = first.Currencies.Cash, second.Currencies.Cash
	phase(players[1], "invalid")
	phase(players[1], "queue")
	phase(players[2], "queue")
	awaitCondition(function()
		return matchService:IsMatchActiveFor(players[1])
			and matchService:IsMatchActiveFor(players[2])
	end, "Match did not become active", 45)
	check(#matchService:GetOpponents(players[1]) == 1, "Opponent assignment is invalid")
	local session = matchService._coordinator._matchesByPlayer[players[1]]
	local matchId = session.Id
	-- Use the real reward-duration gate; do not patch the clock or match internals.
	local config = require(ReplicatedStorage.Shared.Config.MatchConfig)
	task.wait(config.MinimumRewardDurationSeconds + 0.1)
	check(
		matchService:FinishMatch(players[1], players[2], "Knockout"),
		"Server did not finish the active match"
	)
	awaitCondition(function()
		return dataService._repository._profiles[players[1]].LastSavedData.MatchRewardSequences[tostring(
			players[2].UserId
		)] == 1 and dataService._repository._profiles[players[2]].LastSavedData.MatchRewardSequences[tostring(
			players[1].UserId
		)] == 1
	end, "Both payouts were not confirmed by ProfileStore", 25)
	local rewards = require(ReplicatedStorage.Shared.Config.EconomyConfig).MatchRewards
	check(first.Currencies.Cash == firstCash + rewards.Win.Cash, "Winner reward is incorrect")
	check(second.Currencies.Cash == secondCash + rewards.Loss.Cash, "Loser reward is incorrect")
	local economy = Knit.GetService("EconomyService")
	check(economy._journal:Process(matchId), "Confirmed settlement did not clear")
	check(economy._journal:Process(matchId), "Completed settlement replay failed")
	check(
		first.Currencies.Cash == firstCash + rewards.Win.Cash
			and second.Currencies.Cash == secondCash + rewards.Loss.Cash,
		"Settlement replay paid twice"
	)
	check(not matchService:IsMatchInProgressFor(players[1]), "Finished match remained active")
	CollectionService:RemoveTag(arena, "WrestlingArena")
	arena:Destroy()
	for _, player in players do
		phase(player, "health")
	end
	check(#errors == 0, "Unhandled server error: " .. tostring(errors[1]))
end)
errorConnection:Disconnect()
connection:Disconnect()
status:Destroy()
spawn:Destroy()
floor:Destroy()
if success then
	print(`PRO_WRESTLING_LEAGUES_RESULT:{arguments.runId}:PASS:{checks}`)
else
	warn(`PRO_WRESTLING_LEAGUES_RESULT:{arguments.runId}:FAIL:{failure}`)
end
StudioTestService:EndTest({ passed = checks, error = if success then nil else tostring(failure) })
