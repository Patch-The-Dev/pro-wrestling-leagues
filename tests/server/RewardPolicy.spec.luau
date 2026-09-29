--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MatchConfig = require(ReplicatedStorage.Shared.Config.MatchConfig)
local RewardPolicy = require(ServerScriptService.Server.Domain.Economy.RewardPolicy)

return function()
	describe("RewardPolicy", function()
		it("does not pay an immediate forfeit", function()
			expect(RewardPolicy.IsEligible("Forfeit", 1, nil, 100)).to.equal(false)
			expect(
				RewardPolicy.IsEligible(
					"Forfeit",
					MatchConfig.MinimumRewardDurationSeconds,
					nil,
					100
				)
			).to.equal(true)
		end)

		it("limits rewards against the same opponent", function()
			local duration = MatchConfig.MinimumRewardDurationSeconds
			local cooldown = MatchConfig.RepeatOpponentRewardCooldownSeconds
			expect(RewardPolicy.IsEligible("Pin", duration, 100, 100 + cooldown - 1)).to.equal(
				false
			)
			expect(RewardPolicy.IsEligible("Pin", duration, 100, 100 + cooldown)).to.equal(true)
		end)

		it("never rewards a cancelled match or vote", function()
			expect(RewardPolicy.IsEligible("Cancelled", 100, nil, 100)).to.equal(false)
			expect(RewardPolicy.IsEligible("Vote", 100, nil, 100)).to.equal(false)
		end)
	end)
end
