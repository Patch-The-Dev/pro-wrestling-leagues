--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local PendingProfileLoads = require(ServerScriptService.Server.Persistence.PendingProfileLoads)

return function()
	describe("PendingProfileLoads", function()
		it("tracks a profile load until it completes", function()
			local loads = PendingProfileLoads.new()
			local player = {} :: any
			expect(loads:Start(player)).to.equal(true)
			expect(loads:Start(player)).to.equal(false)
			expect(loads:HasPending()).to.equal(true)
			loads:Finish(player)
			expect(loads:HasPending()).to.equal(false)
		end)
	end)
end
