--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local MatchSession = require(ServerScriptService.Server.Domain.Match.MatchSession)

return function()
	describe("MatchSession", function()
		local first = { UserId = 1 } :: any
		local second = { UserId = 2 } :: any

		it("does not start after a countdown is cancelled", function()
			local session = MatchSession.new("match", "arena", { first, second })
			expect(session:BeginStarting()).to.equal(true)
			expect(session:Cancel()).to.equal(true)
			expect(session:Start()).to.equal(false)
			expect(session.State).to.equal("Complete")
			session:Destroy()
		end)

		it("requires both participants to vote before ending", function()
			local session = MatchSession.new("match", "arena", { first, second })
			expect(session:BeginStarting()).to.equal(true)
			expect(session:Start()).to.equal(true)
			expect(session:VoteToEnd(first)).to.equal(false)
			expect(session:VoteToEnd(first)).to.equal(false)
			expect(session:VoteToEnd(second)).to.equal(true)
			expect(session:Finish()).to.equal(true)
			expect(session:Finish()).to.equal(false)
			session:Destroy()
		end)
	end)
end
