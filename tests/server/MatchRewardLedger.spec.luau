--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local MatchRewardLedger = require(ServerScriptService.Server.Domain.Economy.MatchRewardLedger)

return function()
	describe("MatchRewardLedger", function()
		it("applies each match result to a profile only once", function()
			local data = {
				Currencies = { Cash = 0, Tickets = 0 },
				Progression = { Experience = 0, Fame = 0 },
				Statistics = { Wins = 0, Losses = 0, RecentMatchIds = {} },
			} :: any
			local matchId = "00000000-0000-0000-0000-000000000001"
			expect(MatchRewardLedger.Apply(data, matchId, true)).to.equal(true)
			expect(MatchRewardLedger.Apply(data, matchId, true)).to.equal(false)
			expect(data.Statistics.Wins).to.equal(1)
			expect(data.Currencies.Cash).to.equal(250)
			expect(#data.Statistics.RecentMatchIds).to.equal(1)
		end)

		it("bounds the stored settlement history", function()
			local data = {
				Currencies = { Cash = 0, Tickets = 0 },
				Progression = { Experience = 0, Fame = 0 },
				Statistics = { Wins = 0, Losses = 0, RecentMatchIds = {} },
			} :: any
			for index = 1, 65 do
				local id = string.format("00000000-0000-0000-0000-%012d", index)
				MatchRewardLedger.Apply(data, id, false)
			end
			expect(#data.Statistics.RecentMatchIds).to.equal(64)
			expect(data.Statistics.Losses).to.equal(65)
			expect(data.Statistics.RecentMatchIds[1]).to.equal(
				"00000000-0000-0000-0000-000000000002"
			)
		end)
	end)
end
