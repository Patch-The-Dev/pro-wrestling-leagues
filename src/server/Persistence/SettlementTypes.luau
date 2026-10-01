--!strict

export type Reward = { Cash: number, Tickets: number, Experience: number, Fame: number }
export type Result = {
	MatchId: string,
	WinnerUserId: number,
	LoserUserId: number,
	FinishedAt: number,
	WinReward: Reward,
	LossReward: Reward,
}
export type Pending =
	{ MatchId: string, Sequence: number, WinnerSaved: boolean, LoserSaved: boolean }
export type Pair =
	{ Sequence: number, LastMatchId: string, LastClaimedAt: number, Pending: Pending? }
export type Pages = {
	IsFinished: boolean,
	GetCurrentPage: (self: Pages) -> { { KeyName: string } },
	AdvanceToNextPageAsync: (self: Pages) -> (),
}
export type Store = {
	GetAsync: (self: Store, key: string) -> unknown,
	UpdateAsync: (self: Store, key: string, transform: (unknown) -> unknown) -> unknown,
	RemoveAsync: (self: Store, key: string) -> unknown,
	ListKeysAsync: (
		self: Store,
		prefix: string,
		pageSize: number,
		cursor: string,
		excludeDeleted: boolean
	) -> Pages,
}

return {}
