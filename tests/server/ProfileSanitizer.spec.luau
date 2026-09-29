--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CustomizationConfig = require(ReplicatedStorage.Shared.Config.CustomizationConfig)
local ProfileSanitizer = require(ServerScriptService.Server.Persistence.ProfileSanitizer)

return function()
	describe("ProfileSanitizer move ownership", function()
		it("does not grant an equipped paid move absent from unlocks", function()
			local data = {
				Wrestler = { Moves = { GrappleForward = "Piledriver" } },
				Unlocks = { Moves = {} },
			} :: any
			ProfileSanitizer.Apply(data)
			expect(data.Wrestler.Moves.GrappleForward).to.equal(
				CustomizationConfig.DefaultMoves.GrappleForward
			)
			expect(data.Unlocks.Moves.Piledriver).to.equal(nil)
		end)

		it("preserves an equipped move that is actually owned", function()
			local data = {
				Wrestler = { Moves = { GrappleForward = "Piledriver" } },
				Unlocks = { Moves = { Piledriver = true } },
			} :: any
			ProfileSanitizer.Apply(data)
			expect(data.Wrestler.Moves.GrappleForward).to.equal("Piledriver")
		end)
	end)
end
