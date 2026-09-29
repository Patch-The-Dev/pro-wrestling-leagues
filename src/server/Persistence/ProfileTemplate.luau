--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CustomizationConfig = require(ReplicatedStorage.Shared.Config.CustomizationConfig)

local ProfileTemplate = {
	SchemaVersion = 3,
	Currencies = {
		Cash = 0,
		Tickets = 0,
	},
	Progression = {
		Experience = 0,
		Fame = 0,
	},
	Statistics = {
		Wins = 0,
		Losses = 0,
	},
	Wrestler = {
		DisplayName = "",
		Appearance = {
			SkinTone = "#C68642",
			HairId = nil,
			FaceId = nil,
			ShirtId = nil,
			PantsId = nil,
			Accessories = {},
		},
		Moves = table.clone(CustomizationConfig.DefaultMoves),
	},
	Entrance = {
		MusicId = nil,
		PyroPreset = "None",
		LightingPreset = "Default",
	},
	Unlocks = {
		Moves = {
			["Left Punch"] = true,
			["Right Punch"] = true,
			["Clothesline"] = true,
			["Dive"] = true,
			["Shoulder Tackle"] = true,
			["Bodyslam"] = true,
			["Drop Kick"] = true,
			["Head Thrust"] = true,
			["DDT"] = true,
			["Suplex"] = true,
			["Raise Hands"] = true,
		},
		Cosmetics = {},
		Entrances = {},
	},
}

return ProfileTemplate
