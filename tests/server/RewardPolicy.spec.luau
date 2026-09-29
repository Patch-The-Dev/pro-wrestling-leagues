--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MatchConfig = require(ReplicatedStorage.Shared.Config.MatchConfig)
local RewardCooldown = require(ServerScriptService.Server.Domain.Economy.RewardCooldown)
local RewardPolicy = require(ServerScriptService.Server.Domain.Economy.RewardPolicy)

return function()
	describe("RewardPolicy", function()
		it("does not pay an immediate forfeit", function()
			expect(RewardPolicy.IsEligible("Forfeit", 1)).to.equal(false)
			expect(RewardPolicy.IsEligible("Forfeit", MatchConfig.MinimumRewardDurationSeconds)).to.equal(
				true
			)
		end)

		it("claims a pair only once across servers until the shared cooldown expires", function()
			local values = {}
			local map = {
				UpdateAsync = function(_, key, transform)
					local updated = transform(values[key])
					if updated ~= nil then
						values[key] = updated
					end
					return updated
				end,
			} :: any
			local first = RewardCooldown.new(map)
			local second = RewardCooldown.new(map)
			local cooldown = MatchConfig.RepeatOpponentRewardCooldownSeconds
			expect(first:TryClaim(11, 22, 100)).to.equal(true)
			expect(second:TryClaim(22, 11, 100 + cooldown - 1)).to.equal(false)
			expect(second:TryClaim(22, 11, 100 + cooldown)).to.equal(true)
			first:Destroy()
			second:Destroy()
		end)

		it("withholds rewards when the shared claim fails", function()
			local map = {
				UpdateAsync = function()
					error("shared store unavailable")
				end,
			} :: any
			local cooldown = RewardCooldown.new(map)
			expect(cooldown:TryClaim(11, 22, 100)).to.equal(false)
			cooldown:Destroy()
		end)

		it("never rewards a cancelled match or vote", function()
			expect(RewardPolicy.IsEligible("Cancelled", 100)).to.equal(false)
			expect(RewardPolicy.IsEligible("Vote", 100)).to.equal(false)
		end)
	end)
end
