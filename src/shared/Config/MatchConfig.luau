--!strict

local EntranceConfig = require(script.Parent.EntranceConfig)
local maximumPlayers = 2

local MatchConfig = {
	MinimumPlayers = 2,
	MaximumPlayers = maximumPlayers,
	StartCountdownSeconds = EntranceConfig.LeadInSeconds
		+ (maximumPlayers - 1) * EntranceConfig.EntrantSpacingSeconds
		+ math.max(EntranceConfig.CameraFocusSeconds, EntranceConfig.LightingHoldSeconds)
		+ 0.5,
	PostMatchSeconds = 6,
	SettlementWaitSeconds = 25,
	SettlementPageSize = 10,
	SettlementScanSeconds = 15,
	VoteToEndFraction = 1,
	DefaultArenaId = "TrainingRing",
	MinimumRewardDurationSeconds = 30,
	RepeatOpponentRewardCooldownSeconds = 600,
}

table.freeze(MatchConfig)

return MatchConfig
