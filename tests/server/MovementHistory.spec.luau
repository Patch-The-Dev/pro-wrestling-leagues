--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local MovementHistory = require(ServerScriptService.Server.Domain.Combat.MovementHistory)

return function()
	describe("MovementHistory", function()
		local player = {} :: any

		it("requires sampled travel as well as velocity for a running action", function()
			local history = MovementHistory.new()
			history:Observe(player, Vector3.zero, 10)
			expect(history:IsRunning(player, Vector3.new(20, 0, 0), 10)).to.equal(false)
			history:Observe(player, Vector3.new(4, 0, 0), 10.2)
			expect(history:IsRunning(player, Vector3.new(20, 0, 0), 10.2)).to.equal(true)
			expect(history:IsRunning(player, Vector3.new(100, 0, 0), 10.2)).to.equal(false)
			history:Destroy()
		end)

		it("blocks an implausible jump before allowing actions again", function()
			local history = MovementHistory.new()
			history:Observe(player, Vector3.zero, 10)
			history:Observe(player, Vector3.new(100, 0, 0), 10.2)
			expect(history:IsPlausible(player, 10.2)).to.equal(false)
			history:Observe(player, Vector3.new(101, 0, 0), 11.3)
			expect(history:IsPlausible(player, 11.3)).to.equal(true)
			history:Destroy()
		end)

		it("detects a jump on an action between regular samples", function()
			local history = MovementHistory.new()
			history:Observe(player, Vector3.zero, 10)
			history:Observe(player, Vector3.new(80, 0, 0), 10.01)
			expect(history:IsPlausible(player, 10.01)).to.equal(false)
			history:Destroy()
		end)
	end)
end
