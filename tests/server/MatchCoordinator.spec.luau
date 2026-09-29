--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local MatchCoordinator = require(ServerScriptService.Server.Application.MatchCoordinator)
local MatchSession = require(ServerScriptService.Server.Domain.Match.MatchSession)

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
	end)
end
