--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local MatchCoordinator = require(ServerScriptService.Server.Application.MatchCoordinator)
local MatchSession = require(ServerScriptService.Server.Domain.Match.MatchSession)
local PlayerDeparture = require(ServerScriptService.Server.Persistence.PlayerDeparture)
local Promise = require(ReplicatedStorage.Packages.Promise)

return function()
	describe("MatchCoordinator rewards", function()
		local first = { UserId = 11 } :: any
		local second = { UserId = 22 } :: any

		local function createCoordinator()
			local awards = {}
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
				EmitMatchChanged = function() end,
				OnSessionClosed = function() end,
			})
			return coordinator, awards
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
			expect(#awards).to.equal(2)
			expect(awards[1][2]).to.equal(true)
			expect(awards[2][2]).to.equal(false)

			local rematch = activeSession("rematch", 31)
			coordinator._sessions[rematch.Id] = rematch
			expect(coordinator:_finishSession(rematch, second, first, "Pin")).to.equal(true)
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
			local coordinator, awards = createCoordinator()
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
	end)
end
