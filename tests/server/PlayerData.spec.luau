--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataSnapshot = require(ReplicatedStorage.Shared.Util.PlayerDataSnapshot)
local ProfileMigrations = require(ServerScriptService.Server.Persistence.ProfileMigrations)
local ProfileSanitizer = require(ServerScriptService.Server.Persistence.ProfileSanitizer)

return function()
	describe("Player data boundary", function()
		it("migrates legacy currency and move fields before sanitizing", function()
			local data = {
				Currencies = { Cash = 10, Tickets = 2, Experience = 25, Fame = 5 },
				Wrestler = { Name = "Legacy Wrestler" },
				Attack1 = "Left Punch",
			} :: any
			expect(ProfileMigrations.Apply(data)).to.equal(3)
			ProfileSanitizer.Apply(data)
			expect(data.SchemaVersion).to.equal(3)
			expect(data.Progression.Experience).to.equal(25)
			expect(data.Progression.Fame).to.equal(5)
			expect(data.Wrestler.DisplayName).to.equal("Legacy Wrestler")
			expect(data.Wrestler.Moves.Attack1).to.equal("Left Punch")
			expect(data.Attack1).to.equal(nil)
		end)

		it("repairs invalid stored values before exposing player data", function()
			local data = {
				Currencies = { Cash = math.huge, Tickets = -10 },
				Progression = { Experience = 2.5, Fame = 0 / 0 },
				Wrestler = {
					DisplayName = string.rep("X", 51),
					Appearance = { SkinTone = "invalid", Accessories = { "123", "bad" } },
					Moves = { Attack1 = "not a move" },
				},
			} :: any
			ProfileSanitizer.Apply(data)
			expect(data.Currencies.Cash).to.equal(0)
			expect(data.Currencies.Tickets).to.equal(0)
			expect(data.Progression.Experience).to.equal(2)
			expect(data.Progression.Fame).to.equal(0)
			expect(data.Wrestler.DisplayName).to.equal("")
			expect(#data.Wrestler.Appearance.Accessories).to.equal(1)
			expect(data.Wrestler.Appearance.Accessories[1]).to.equal("123")
			expect(data.Wrestler.Moves.Attack1).to.equal("Left Punch")
		end)

		it("returns a detached snapshot, including nested player data", function()
			local source = {
				SchemaVersion = 3,
				Currencies = { Cash = 10, Tickets = 2 },
				Progression = { Experience = 1, Fame = 0 },
				Statistics = { Wins = 0, Losses = 0 },
				Wrestler = {
					DisplayName = "Wrestler",
					Appearance = {
						SkinTone = "#C68642",
						Accessories = { "123" },
					},
					Moves = { Attack1 = "Left Punch" },
				},
				Entrance = { PyroPreset = "None", LightingPreset = "Default" },
				Unlocks = { Moves = { ["Left Punch"] = true }, Cosmetics = {}, Entrances = {} },
			} :: any
			local snapshot = PlayerDataSnapshot.Clone(source)
			snapshot.Wrestler.Appearance.Accessories[1] = "456"
			snapshot.Unlocks.Moves["Left Punch"] = false
			snapshot.Currencies.Cash = 99
			expect(source.Wrestler.Appearance.Accessories[1]).to.equal("123")
			expect(source.Unlocks.Moves["Left Punch"]).to.equal(true)
			expect(source.Currencies.Cash).to.equal(10)
		end)
	end)
end
