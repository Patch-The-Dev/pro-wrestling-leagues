--!strict

local MatchTypes = require(script.Parent.MatchTypes)

type MatchResult = MatchTypes.MatchResult
type MatchState = MatchTypes.MatchState

export type MatchUpdate = {
	Id: string,
	State: MatchState,
	ArenaId: string?,
	StartsAt: number?,
	StartedAt: number?,
	Result: MatchResult?,
}

export type WeaponAction = "Pickup" | "Drop" | "Attack"
export type PinResolution = "Escaped" | "Pinned"

export type EntranceCue = {
	UserId: number,
	DisplayName: string,
	MusicId: string?,
	PyroPreset: string,
	LightingPreset: string,
	StartsAt: number,
	ArenaId: string?,
}

return {}
