--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)

type PlayerData = PlayerDataTypes.PlayerData

local PlayerDataSnapshot = {}

function PlayerDataSnapshot.Clone(data: PlayerData): PlayerData
	return {
		SchemaVersion = data.SchemaVersion,
		Currencies = table.clone(data.Currencies),
		Progression = table.clone(data.Progression),
		Statistics = {
			Wins = data.Statistics.Wins,
			Losses = data.Statistics.Losses,
			RecentMatchIds = table.clone(data.Statistics.RecentMatchIds),
		},
		Wrestler = {
			DisplayName = data.Wrestler.DisplayName,
			Appearance = {
				SkinTone = data.Wrestler.Appearance.SkinTone,
				HairId = data.Wrestler.Appearance.HairId,
				FaceId = data.Wrestler.Appearance.FaceId,
				ShirtId = data.Wrestler.Appearance.ShirtId,
				PantsId = data.Wrestler.Appearance.PantsId,
				Accessories = table.clone(data.Wrestler.Appearance.Accessories),
			},
			Moves = table.clone(data.Wrestler.Moves),
		},
		Entrance = table.clone(data.Entrance),
		Unlocks = {
			Moves = table.clone(data.Unlocks.Moves),
			Cosmetics = table.clone(data.Unlocks.Cosmetics),
			Entrances = table.clone(data.Unlocks.Entrances),
		},
	}
end

return table.freeze(PlayerDataSnapshot)
