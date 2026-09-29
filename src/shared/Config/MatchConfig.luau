--!strict

local MatchConfig = {
	MinimumPlayers = 2,
	MaximumPlayers = 2,
	StartCountdownSeconds = 4,
	PostMatchSeconds = 6,
	VoteToEndFraction = 1,
	DefaultArenaId = "TrainingRing",
}

table.freeze(MatchConfig)

return MatchConfig
