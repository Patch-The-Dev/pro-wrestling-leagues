--!strict

return function()
	local ServerScriptService = game:GetService("ServerScriptService")
	local Journal = require(ServerScriptService.Server.Persistence.MatchSettlementJournal)
	local Store = require(ServerScriptService.Server.Persistence.SettlementStore)
	local Ledger = require(ServerScriptService.Server.Domain.Economy.MatchRewardLedger)
	local function result(id: string, time: number?)
		return {
			MatchId = id,
			WinnerUserId = 11,
			LoserUserId = 22,
			FinishedAt = time or 1000,
			WinReward = { Cash = 250, Tickets = 1, Experience = 5, Fame = 2 },
			LossReward = { Cash = 100, Tickets = 0, Experience = 2, Fame = 0 },
		}
	end
	local function profile()
		return {
			Currencies = { Cash = 0, Tickets = 0 },
			Progression = { Experience = 0, Fame = 0 },
			Statistics = { Wins = 0, Losses = 0, RecentMatchIds = {} },
		} :: any
	end
	describe("Match settlement journal", function()
		it("does not claim an offline pair and resumes when a profile becomes available", function()
			local store = Store.new()
			local available = false
			local journal = Journal.new(store, function()
				return true
			end, function()
				return available
			end)
			journal:Record(result("offline"))
			expect(journal:Process("offline")).to.equal(false)
			expect(store:GetAsync("pair/11:22")).to.equal(nil)
			expect(store:GetAsync("result/offline") ~= nil).to.equal(true)
			available = true
			expect(journal:Process("offline")).to.equal(true)
		end)
		it("advances bounded recovery pages without abandoning later results", function()
			local store = Store.new()
			local awards = 0
			local journal = Journal.new(store, function()
				awards += 1
				return true
			end)
			for index = 1, 25 do
				local value = result(`page-{index}`)
				value.WinnerUserId = index + 100
				journal:Record(value)
			end
			journal:ScanPage()
			expect(awards).to.equal(20)
			journal:ScanPage()
			expect(awards).to.equal(40)
			journal:ScanPage()
			expect(awards).to.equal(50)
			for index = 1, 25 do
				expect(store:GetAsync(`result/page-{index}`)).to.equal(nil)
			end
		end)
		it("recovers only the unpaid side after the original server disappears", function()
			local store = Store.new()
			local winner = profile()
			local loser = profile()
			local calls = { [11] = 0, [22] = 0 }
			local loserAvailable = false
			local function apply(userId, opponentId, sequence, matchId, didWin, reward)
				calls[userId] += 1
				if userId == 22 and not loserAvailable then
					return false
				end
				return Ledger.ApplySettlement(
					if userId == 11 then winner else loser,
					opponentId,
					sequence,
					matchId,
					didWin,
					reward
				)
			end
			local original = Journal.new(store, apply)
			expect(original:Record(result("partial"))).to.equal(true)
			for _ = 1, 5 do
				expect(original:Process("partial")).to.equal(false)
			end
			expect(winner.Currencies.Cash).to.equal(250)
			expect(loser.Currencies.Cash).to.equal(0)
			expect(calls[11]).to.equal(1)
			loserAvailable = true
			local replacement = Journal.new(store, apply)
			replacement:ScanPage()
			expect(store:GetAsync("result/partial")).to.equal(nil)
			expect(winner.Currencies.Cash).to.equal(250)
			expect(loser.Currencies.Cash).to.equal(100)
			expect(calls[11]).to.equal(1)
		end)
		it("retains a result through cooldown-store failure instead of denying it", function()
			local backing = Store.new()
			local fail = true
			local store = table.clone(backing)
			store.UpdateAsync = function(_, key, transform)
				if fail and string.sub(key, 1, 5) == "pair/" then
					error("store unavailable")
				end
				return backing:UpdateAsync(key, transform)
			end
			local awards = 0
			local journal = Journal.new(store, function()
				awards += 1
				return true
			end)
			expect(journal:Record(result("outage"))).to.equal(true)
			expect(journal:Process("outage")).to.equal(false)
			expect(backing:GetAsync("result/outage") ~= nil).to.equal(true)
			expect(awards).to.equal(0)
			fail = false
			expect(journal:Process("outage")).to.equal(true)
			expect(awards).to.equal(2)
		end)
		it("replays safely if the save succeeds but its acknowledgement fails", function()
			local backing = Store.new()
			local winner = profile()
			local loser = profile()
			local fail = true
			local store = table.clone(backing)
			store.UpdateAsync = function(_, key, transform)
				local updated = backing:UpdateAsync(key, transform)
				if key == "pair/11:22" and fail and winner.Currencies.Cash > 0 then
					fail = false
					error("response lost after write")
				end
				return updated
			end
			local journal = Journal.new(
				store,
				function(userId, opponentId, sequence, matchId, didWin, reward)
					return Ledger.ApplySettlement(
						if userId == 11 then winner else loser,
						opponentId,
						sequence,
						matchId,
						didWin,
						reward
					)
				end
			)
			journal:Record(result("uncertain"))
			expect(journal:Process("uncertain")).to.equal(false)
			expect(journal:Process("uncertain")).to.equal(true)
			expect(winner.Currencies.Cash).to.equal(250)
			expect(loser.Currencies.Cash).to.equal(100)
		end)
		it("shares the pair cooldown across workers and protects an unfinished sequence", function()
			local store = Store.new()
			local available = false
			local awards = 0
			local function apply()
				if not available then
					return false
				end
				awards += 1
				return true
			end
			local first = Journal.new(store, apply)
			local second = Journal.new(store, apply)
			first:Record(result("first", 1000))
			first:Process("first")
			second:Record(result("next", 1600))
			expect(second:Process("next")).to.equal(false)
			available = true
			expect(first:Process("first")).to.equal(true)
			expect(second:Process("next")).to.equal(true)
			second:Record(result("too-soon", 1601))
			expect(second:Process("too-soon")).to.equal(true)
			expect(awards).to.equal(4)
		end)
		it("keeps reward amounts from the original result on record retries", function()
			local store = Store.new()
			local paid = 0
			local journal = Journal.new(store, function(_, _, _, _, _, reward)
				paid += reward.Cash
				return true
			end)
			local original = result("fixed-amounts")
			journal:Record(original)
			original.WinReward.Cash = 999
			journal:Record(original)
			journal:Process(original.MatchId)
			expect(paid).to.equal(350)
		end)
	end)
end
