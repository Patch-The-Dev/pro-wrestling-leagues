--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CustomizationConfig = require(ReplicatedStorage.Shared.Config.CustomizationConfig)
local ProfileSanitizer = require(ServerScriptService.Server.Persistence.ProfileSanitizer)

return function()
	describe("ProfileSanitizer move ownership", function()
		it("preserves valid reward watermarks and removes malformed keys and sequences", function()
			local data = {
				MatchRewardSequences = {
					[42] = 5,
					["11"] = 3,
					["-1"] = 2,
					["0"] = 4,
					invalid = 1,
					["22"] = 0 / 0,
					["33"] = -1,
				},
			} :: any
			ProfileSanitizer.Apply(data)
			expect(data.MatchRewardSequences["11"]).to.equal(3)
			expect(data.MatchRewardSequences["-1"]).to.equal(2)
			expect(data.MatchRewardSequences[42]).to.equal(nil)
			expect(data.MatchRewardSequences["0"]).to.equal(nil)
			expect(data.MatchRewardSequences.invalid).to.equal(nil)
			expect(data.MatchRewardSequences["22"]).to.equal(nil)
			expect(data.MatchRewardSequences["33"]).to.equal(nil)
		end)
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
