--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local Ledger = require(ServerScriptService.Server.Domain.Economy.MatchRewardLedger)
local reward = { Cash = 250, Tickets = 1, Experience = 5, Fame = 2 }

return function()
	local function data()
		return {
			Currencies = { Cash = 0, Tickets = 0 },
			Progression = { Experience = 0, Fame = 0 },
			Statistics = { Wins = 0, Losses = 0, RecentMatchIds = {} },
		} :: any
	end
	describe("Durable reward sequence", function()
		it("rejects balance overflow before applying any reward or watermark", function()
			local profile = data()
			profile.Currencies.Cash = 9_007_199_254_740_991
			expect(function()
				Ledger.ApplySettlement(profile, 22, 1, "overflow", true, reward)
			end).to.throw()
			expect(profile.Currencies.Tickets).to.equal(0)
			expect(profile.Statistics.Wins).to.equal(0)
			expect(profile.MatchRewardSequences).to.equal(nil)
		end)
		it("applies a sequence once and accepts an already saved replay", function()
			local profile = data()
			expect(Ledger.ApplySettlement(profile, 22, 1, "first", true, reward)).to.equal(true)
			expect(Ledger.ApplySettlement(profile, 22, 1, "first", true, reward)).to.equal(true)
			expect(profile.Statistics.Wins).to.equal(1)
			expect(profile.Currencies.Cash).to.equal(250)
		end)
		it("rejects a later sequence until the missing one has been applied", function()
			local profile = data()
			expect(Ledger.ApplySettlement(profile, 22, 2, "second", true, reward)).to.equal(false)
			expect(profile.Currencies.Cash).to.equal(0)
			expect(Ledger.ApplySettlement(profile, 22, 1, "first", true, reward)).to.equal(true)
			expect(Ledger.ApplySettlement(profile, 22, 2, "second", true, reward)).to.equal(true)
		end)
		it("rejects duplicate payouts after recent match IDs have been pruned", function()
			local profile = data()
			for sequence = 1, 100 do
				Ledger.ApplySettlement(profile, 22, sequence, tostring(sequence), false, reward)
			end
			expect(#profile.Statistics.RecentMatchIds).to.equal(64)
			Ledger.ApplySettlement(profile, 22, 1, "1", false, reward)
			expect(profile.Statistics.Losses).to.equal(100)
			expect(profile.Currencies.Cash).to.equal(25000)
		end)
	end)
end
