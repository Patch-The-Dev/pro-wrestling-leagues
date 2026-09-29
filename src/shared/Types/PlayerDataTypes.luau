--!strict

export type MoveSlot =
	"Attack1"
	| "Attack2"
	| "Attack3"
	| "RunningAttack"
	| "TurnbuckleAttack"
	| "RunningGrappleMove"
	| "GrappleForward"
	| "GrappleLeft"
	| "GrappleBackward"
	| "GrappleRight"
	| "Finisher"
	| "Taunt"

export type AppearanceAssetField = "HairId" | "FaceId" | "ShirtId" | "PantsId"
export type CurrencyName = "Cash" | "Tickets"

export type MoveLoadout = {
	Attack1: string,
	Attack2: string,
	Attack3: string,
	RunningAttack: string,
	TurnbuckleAttack: string,
	RunningGrappleMove: string,
	GrappleForward: string,
	GrappleLeft: string,
	GrappleBackward: string,
	GrappleRight: string,
	Finisher: string,
	Taunt: string,
}

export type Appearance = {
	SkinTone: string,
	HairId: string?,
	FaceId: string?,
	ShirtId: string?,
	PantsId: string?,
	Accessories: { string },
}

export type Entrance = {
	MusicId: string?,
	PyroPreset: string,
	LightingPreset: string,
}

export type Unlocks = {
	Moves: { [string]: boolean },
	Cosmetics: { [string]: boolean },
	Entrances: { [string]: boolean },
}

export type PlayerData = {
	SchemaVersion: number,
	Currencies: {
		Cash: number,
		Tickets: number,
	},
	Progression: {
		Experience: number,
		Fame: number,
	},
	Statistics: {
		Wins: number,
		Losses: number,
	},
	Wrestler: {
		DisplayName: string,
		Appearance: Appearance,
		Moves: MoveLoadout,
	},
	Entrance: Entrance,
	Unlocks: Unlocks,
}

return {}
