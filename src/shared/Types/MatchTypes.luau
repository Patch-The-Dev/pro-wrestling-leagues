--!strict

export type MatchState = "Waiting" | "Starting" | "Active" | "Ending" | "Complete"
export type MatchEndReason = "Pin" | "Knockout" | "Forfeit" | "Vote" | "Cancelled"

export type MatchResult = {
	WinnerUserId: number?,
	LoserUserId: number?,
	Reason: MatchEndReason,
	DurationSeconds: number,
}

return {}
