--!strict

local CombatTypes = require(script.Parent.Parent.Types.CombatTypes)

type DamageSpec = CombatTypes.DamageSpec
type MoveCategory = CombatTypes.MoveCategory

type MoveDefinition = {
	Id: string,
	DisplayName: string,
	Category: MoveCategory,
	Duration: number,
	ImpactSeconds: number?,
	Damage: DamageSpec,
}

local STANDARD_GRAPPLE: DamageSpec = {
	HealthDamage = 10,
	PoiseDamage = 18,
	AttackerFinisher = 10,
	VictimFinisher = 5,
	StunSeconds = 1.1,
}

local definitions: { [string]: MoveDefinition } = {}

local function register(
	id: string,
	category: MoveCategory,
	duration: number,
	damage: DamageSpec,
	impactSeconds: number?
)
	definitions[id] = {
		Id = id,
		DisplayName = id,
		Category = category,
		Duration = duration,
		ImpactSeconds = impactSeconds,
		Damage = damage,
	}
end

register("Left Punch", "Attack", 0.45, {
	HealthDamage = 3,
	PoiseDamage = 5,
	AttackerFinisher = 2,
	VictimFinisher = 1,
	StunSeconds = 0.3,
}, 0.18)
register("Right Punch", "Attack", 0.45, {
	HealthDamage = 3,
	PoiseDamage = 5,
	AttackerFinisher = 2,
	VictimFinisher = 1,
	StunSeconds = 0.3,
}, 0.18)
register("Clothesline", "RunningAttack", 0.8, {
	HealthDamage = 6,
	PoiseDamage = 10,
	AttackerFinisher = 5,
	VictimFinisher = 2,
	StunSeconds = 0.85,
}, 0.34)
register("Dive", "TurnbuckleAttack", 1.1, {
	HealthDamage = 12,
	PoiseDamage = 25,
	AttackerFinisher = 10,
	VictimFinisher = 3,
	StunSeconds = 1.25,
}, 0.48)
register("Raise Hands", "Taunt", 1.25, {
	HealthDamage = 0,
	PoiseDamage = 0,
	AttackerFinisher = 20,
	VictimFinisher = 0,
	StunSeconds = 0,
})

for _, id in
	{
		"Chokeslam",
		"DDT",
		"Bodyslam",
		"Drop Kick",
		"Head Thrust",
		"Suplex",
		"Spinebuster",
		"Piledriver",
		"Swinging Backbreaker",
		"Neckbreaker",
		"German Suplex",
		"Inverted DDT",
		"Full Nelson Slam",
		"Throne Buster",
		"Powerbomb",
		"Front Powerslam",
		"Viper KO",
		"Tornado Slam",
		"Spear 1",
		"Spear 2",
	}
do
	register(id, "Grapple", 1.6, table.clone(STANDARD_GRAPPLE))
end

for _, id in
	{
		"Shoulder Tackle",
		"Cross Body",
		"Leg Lariat",
		"Running Bulldog",
		"Running Clothesline",
		"Running Knee",
		"Running Neckbreaker",
		"Somersault Neckbreaker",
		"Thesz Press",
		"Running Viper KO",
		"Spear 3",
	}
do
	register(id, "RunningGrapple", 1.45, table.clone(STANDARD_GRAPPLE))
end

for _, definition in definitions do
	table.freeze(definition.Damage)
	table.freeze(definition)
end

table.freeze(definitions)

local MovesConfig = {}

function MovesConfig.Get(moveId: string): MoveDefinition?
	return definitions[moveId]
end

function MovesConfig.Exists(moveId: string): boolean
	return definitions[moveId] ~= nil
end

function MovesConfig.GetAll(): { [string]: MoveDefinition }
	return table.clone(definitions)
end

return table.freeze(MovesConfig)
