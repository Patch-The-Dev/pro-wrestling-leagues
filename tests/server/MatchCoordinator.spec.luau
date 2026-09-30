--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local MatchCoordinator = require(ServerScriptService.Server.Application.MatchCoordinator)
local MatchPlacement = require(ServerScriptService.Server.Domain.Match.MatchPlacement)
local MatchSession = require(ServerScriptService.Server.Domain.Match.MatchSession)
local PlayerDeparture = require(ServerScriptService.Server.Persistence.PlayerDeparture)
local Promise = require(ReplicatedStorage.Packages.Promise)

return function()
	describe("MatchCoordinator rewards", function()
		local first = { UserId = 11 } :: any
		local second = { UserId = 22 } :: any
		local function waitUntil(predicate: () -> boolean)
			local deadline = os.clock() + 3
			while not predicate() and os.clock() < deadline do
				task.wait(0.02)
			end
			expect(predicate()).to.equal(true)
		end

		local function createCoordinator()
			local awards = {}
			local updates = {}
			local coordinator = MatchCoordinator.new({
				DataSource = {
					IsLoaded = function()
						return true
					end,
				},
				EconomySource = {
					ApplyMatchReward = function(_, player, didWin)
						table.insert(awards, { player.UserId, didWin })
						return true
					end,
				},
				EntranceSource = {
					PlayForPlayers = function() end,
				},
				EmitQueueChanged = function() end,
				EmitMatchChanged = function(player, update)
					table.insert(updates, { player, update })
				end,
				OnSessionClosed = function() end,
			})
			return coordinator, awards, updates
		end

		local function activeSession(id: string, duration: number)
			local session = MatchSession.new(id, "arena", { first, second })
			session:BeginStarting()
			session:Start()
			session.StartedAt = workspace:GetServerTimeNow() - duration
			return session
		end

		it("does not award a fast forfeit", function()
			local coordinator, awards = createCoordinator()
			local session = activeSession("early", 1)
			coordinator._sessions[session.Id] = session
			expect(coordinator:_finishSession(session, first, second, "Forfeit")).to.equal(true)
			expect(#awards).to.equal(0)
			coordinator:Destroy()
		end)

		it("awards an eligible match once per opponent cooldown", function()
			local coordinator, awards = createCoordinator()
			local firstMatch = activeSession("first", 31)
			coordinator._sessions[firstMatch.Id] = firstMatch
			expect(coordinator:_finishSession(firstMatch, first, second, "Pin")).to.equal(true)
			waitUntil(function()
				return #awards == 2
			end)
			expect(#awards).to.equal(2)
			expect(awards[1][2]).to.equal(true)
			expect(awards[2][2]).to.equal(false)

			local rematch = activeSession("rematch", 31)
			coordinator._sessions[rematch.Id] = rematch
			expect(coordinator:_finishSession(rematch, second, first, "Pin")).to.equal(true)
			waitUntil(function()
				local settlement = coordinator._settlementsByPlayer[first]
				return settlement ~= nil and settlement.Complete
			end)
			expect(#awards).to.equal(2)
			coordinator:Destroy()
		end)

		it("retries queued players after an arena is released", function()
			local coordinator = createCoordinator()
			local attempts = 0
			local arenaAvailable = false
			(coordinator :: any)._isQueueReady = function()
				return true
			end
			(coordinator :: any)._createMatch = function()
				attempts += 1
				return arenaAvailable
			end
			table.insert(coordinator._queue, first)
			table.insert(coordinator._queue, second)
			coordinator:_matchmake()
			expect(attempts).to.equal(1)
			expect(#coordinator._queue).to.equal(2)
			arenaAvailable = true
			local completed = activeSession("completed", 31)
			completed:Finish()
			coordinator._sessions[completed.Id] = completed
			coordinator:_cleanupSession(completed)
			expect(attempts).to.equal(2)
			expect(#coordinator._queue).to.equal(0)
			coordinator:Destroy()
		end)

		it("moves match characters out before releasing their arena", function()
			local coordinator = createCoordinator()
			local character = Instance.new("Model")
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Parent = character
			character:PivotTo(CFrame.new(10, 5, 0))
			local player = { Character = character } :: any
			local secondCharacter = Instance.new("Model")
			local secondRoot = Instance.new("Part")
			secondRoot.Name = "HumanoidRootPart"
			secondRoot.Parent = secondCharacter
			secondCharacter:PivotTo(CFrame.new(20, 5, 0))
			local secondPlayer = { Character = secondCharacter } :: any
			local session = MatchSession.new("return-test", "arena", { player, secondPlayer })
			session:BeginStarting()
			local spawns = { CFrame.new(100, 5, 0), CFrame.new(110, 5, 0) }
			local placement = MatchPlacement.new({ player, secondPlayer }, spawns)
			assert(placement ~= nil, "Expected valid match placement")
			expect(placement:Place()).to.equal(true)
			coordinator._sessions[session.Id] = session
			coordinator._placements[session.Id] = placement
			local originalRelease = coordinator._arenaRegistry.Release
			local positionAtRelease: number? = nil
			(coordinator._arenaRegistry :: any).Release = function(_, matchId)
				positionAtRelease = character:GetPivot().Position.X
				originalRelease(coordinator._arenaRegistry, matchId)
			end
			coordinator:_cleanupSession(session)
			expect(positionAtRelease).to.equal(10)
			coordinator:Destroy()
			character:Destroy()
			secondCharacter:Destroy()
		end)

		for _, failingStep in { "queue", "match", "entrance" } do
			it(`rolls back reserved arenas when {failingStep} startup fails`, function()
				local function makePlayer(userId: number, x: number)
					local character = Instance.new("Model")
					local humanoid = Instance.new("Humanoid")
					humanoid.Parent = character
					local root = Instance.new("Part")
					root.Name = "HumanoidRootPart"
					root.Parent = character
					character:PivotTo(CFrame.new(x, 5, 0))
					return { UserId = userId, Character = character } :: any, character
				end

				local firstPlayer, firstCharacter = makePlayer(101, 10)
				local secondPlayer, secondCharacter = makePlayer(102, 20)
				local arena = Instance.new("Model")
				arena:SetAttribute("ArenaId", "TrainingRing")
				arena:SetAttribute("RequiredPlayers", 2)
				local spawns = Instance.new("Folder")
				spawns.Name = "Spawns"
				spawns.Parent = arena
				for index = 1, 2 do
					local spawn = Instance.new("Part")
					spawn.Name = tostring(index)
					spawn.CFrame = CFrame.new(100 + 10 * index, 5, 0)
					spawn.Parent = spawns
				end

				local firstPositionAtStarting: number? = nil
				local coordinator = MatchCoordinator.new({
					DataSource = {
						IsLoaded = function()
							return true
						end,
					},
					EconomySource = {
						ApplyMatchReward = function()
							return true
						end,
					},
					EntranceSource = {
						PlayForPlayers = function()
							if failingStep == "entrance" then
								error("entrance failure")
							end
						end,
					},
					EmitQueueChanged = function()
						if failingStep == "queue" then
							error("queue failure")
						end
					end,
					EmitMatchChanged = function(player, update)
						if update.State == "Starting" and player == firstPlayer then
							firstPositionAtStarting = firstCharacter:GetPivot().Position.X
						end
						if failingStep == "match" then
							error("match notification failure")
						end
					end,
					OnSessionClosed = function() end,
				})
				coordinator._arenaRegistry:Add(arena)
				expect(coordinator:_createMatch({ firstPlayer, secondPlayer })).to.equal(false)
				expect(coordinator._matchesByPlayer[firstPlayer]).to.equal(nil)
				expect(coordinator._matchesByPlayer[secondPlayer]).to.equal(nil)
				expect(firstCharacter:GetPivot().Position.X).to.equal(10)
				expect(secondCharacter:GetPivot().Position.X).to.equal(20)
				if failingStep ~= "queue" then
					expect(firstPositionAtStarting).to.equal(110)
				end
				expect(coordinator._arenaRegistry:Reserve("probe", 2, "TrainingRing")).to.equal(
					"TrainingRing"
				)
				coordinator._arenaRegistry:Release("probe")
				coordinator:Destroy()
				firstCharacter:Destroy()
				secondCharacter:Destroy()
				arena:Destroy()
			end)
		end

		it("retries queued players when an arena is registered", function()
			local coordinator = createCoordinator()
			local attempts = 0
			(coordinator :: any)._isQueueReady = function()
				return true
			end
			(coordinator :: any)._createMatch = function()
				attempts += 1
				return true
			end
			table.insert(coordinator._queue, first)
			table.insert(coordinator._queue, second)
			local arena = Instance.new("Model")
			arena.Name = "NewRing"
			coordinator._arenaRegistry:Add(arena)
			expect(attempts).to.equal(1)
			expect(#coordinator._queue).to.equal(0)
			coordinator:Destroy()
			arena:Destroy()
		end)

		it("keeps both departing profiles until a yielding reward claim settles", function()
			local coordinator, awards, updates = createCoordinator()
			local session = activeSession("disconnect", 31)
			coordinator._sessions[session.Id] = session
			coordinator._matchesByPlayer[first] = session
			coordinator._matchesByPlayer[second] = session
			local claimStarted = Instance.new("BindableEvent")
			local resumeClaim: (() -> ())? = nil
			local claimGate = Promise.new(function(resolve)
				resumeClaim = resolve
			end)
			local finished = Instance.new("BindableEvent")
			local secondDeparted = Instance.new("BindableEvent")
			local firstDepartureFinished = false
			local secondReleased = false
			local released = {}
			local departures = PlayerDeparture.new({
				Release = function(_, player)
					released[player] = true
				end,
				ReleaseAll = function() end,
			} :: any)
			departures:SetBeforeRelease(function(player)
				coordinator:HandlePlayerRemoving(player)
			end)
			local mutableCoordinator = coordinator :: any
			mutableCoordinator.GetOpponents = function()
				return { first }
			end
			mutableCoordinator._rewardCooldown = {
				TryClaim = function()
					claimStarted:Fire()
					claimGate:await()
					return true
				end,
			}
			task.defer(function()
				departures:Release(second)
				firstDepartureFinished = true
				finished:Fire()
			end)
			claimStarted.Event:Wait()
			expect(updates[1][2].State).to.equal("Complete")
			task.defer(function()
				departures:Release(first)
				secondReleased = true
				secondDeparted:Fire()
			end)
			RunService.Heartbeat:Wait()
			expect(secondReleased).to.equal(false)
			expect(released[first]).to.equal(nil)
			expect(released[second]).to.equal(nil)
			assert(resumeClaim ~= nil, "Reward claim gate was not created")
			resumeClaim()
			if not firstDepartureFinished then
				finished.Event:Wait()
			end
			if not secondReleased then
				secondDeparted.Event:Wait()
			end
			expect(#awards).to.equal(2)
			expect(secondReleased).to.equal(true)
			expect(released[first]).to.equal(true)
			expect(released[second]).to.equal(true)
			departures:Destroy()
			coordinator:Destroy()
			claimStarted:Destroy()
			finished:Destroy()
			secondDeparted:Destroy()
		end)

		it("completes the match UI before a slow claim and holds requeue after cleanup", function()
			local coordinator, awards, updates = createCoordinator()
			local session = activeSession("slow-claim", 31)
			coordinator._sessions[session.Id] = session
			coordinator._matchesByPlayer[first] = session
			coordinator._matchesByPlayer[second] = session
			local claimStarted = false
			local resumeClaim: (() -> ())? = nil
			local claimGate = Promise.new(function(resolve)
				resumeClaim = resolve
			end)
			local mutableCoordinator = coordinator :: any
			mutableCoordinator._rewardCooldown = {
				TryClaim = function()
					claimStarted = true
					claimGate:await()
					return true
				end,
			}
			expect(coordinator:_finishSession(session, first, second, "Pin")).to.equal(true)
			expect(updates[1][2].State).to.equal("Complete")
			waitUntil(function()
				return claimStarted
			end)
			coordinator:_cleanupSession(session)
			local joined, reason = coordinator:JoinQueue(first)
			expect(joined).to.equal(false)
			expect(reason).to.equal("Previous match reward is still settling")
			expect(#awards).to.equal(0)
			local departed = false
			task.defer(function()
				coordinator:HandlePlayerRemoving(first)
				departed = true
			end)
			RunService.Heartbeat:Wait()
			expect(departed).to.equal(false)
			assert(resumeClaim ~= nil, "Reward claim gate was not created")
			resumeClaim()
			waitUntil(function()
				return #awards == 2
			end)
			waitUntil(function()
				return coordinator._settlementsByPlayer[first] == nil
			end)
			waitUntil(function()
				return departed
			end)
			coordinator:Destroy()
		end)
	end)
end
