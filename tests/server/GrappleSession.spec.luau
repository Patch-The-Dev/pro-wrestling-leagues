--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local GrappleSession = require(ServerScriptService.Server.Domain.Combat.GrappleSession)

return function()
	describe("GrappleSession", function()
		local attacker = {} :: any
		local victim = {} :: any

		it("accepts only one reversal from the victim", function()
			local session = GrappleSession.new("grapple", attacker, victim)
			expect(session:TryReverse(attacker)).to.equal(false)
			expect(session:TryReverse(victim)).to.equal(true)
			expect(session:TryReverse(victim)).to.equal(false)
			session:Destroy()
		end)
	end)
end
