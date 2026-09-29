--!strict

local CURRENT_SCHEMA_VERSION = 3

type Dictionary = { [string]: unknown }
type Migration = (data: Dictionary) -> ()

local ProfileMigrations = {}

local function asDictionary(value: unknown): Dictionary?
	if type(value) ~= "table" then
		return nil
	end
	return value :: Dictionary
end

local function ensureDictionary(parent: Dictionary, key: string): Dictionary
	local existing = asDictionary(parent[key])
	if existing ~= nil then
		return existing
	end

	local created: Dictionary = {}
	parent[key] = created
	return created
end

local function moveLegacyField(
	source: Dictionary,
	sourceKey: string,
	destination: Dictionary,
	destinationKey: string
)
	local value = source[sourceKey]
	if type(value) == "string" and value ~= "" and destination[destinationKey] == nil then
		destination[destinationKey] = value
	end
	source[sourceKey] = nil
end

local function migrateLegacyRoot(data: Dictionary)
	local currencies = asDictionary(data.Currencies)
	if currencies ~= nil then
		local progression = ensureDictionary(data, "Progression")

		local experience = currencies.Experience
		if type(experience) == "number" and progression.Experience == nil then
			progression.Experience = experience
		end
		currencies.Experience = nil

		local fame = currencies.Fame
		if type(fame) == "number" and progression.Fame == nil then
			progression.Fame = fame
		end
		currencies.Fame = nil
	end

	local wrestler = ensureDictionary(data, "Wrestler")
	local legacyName = wrestler.Name
	if type(legacyName) == "string" and wrestler.DisplayName == nil then
		wrestler.DisplayName = legacyName
	end
	wrestler.Name = nil

	local moves = ensureDictionary(wrestler, "Moves")
	moveLegacyField(data, "Attack1", moves, "Attack1")
	moveLegacyField(data, "Attack2", moves, "Attack2")
	moveLegacyField(data, "Attack3", moves, "Attack3")
	moveLegacyField(data, "RunningAttack", moves, "RunningAttack")
	moveLegacyField(data, "TurnbuckleAttack", moves, "TurnbuckleAttack")
	moveLegacyField(data, "RunningGrappleMove", moves, "RunningGrappleMove")
	moveLegacyField(data, "PerformingGrappleWInitiatorAnim", moves, "GrappleForward")
	moveLegacyField(data, "PerformingGrappleAInitiatorAnim", moves, "GrappleLeft")
	moveLegacyField(data, "PerformingGrappleSInitiatorAnim", moves, "GrappleBackward")
	moveLegacyField(data, "PerformingGrappleDInitiatorAnim", moves, "GrappleRight")
	moveLegacyField(data, "PerformingGrappleTInitiatorAnim", moves, "GrappleHeavy")
	moveLegacyField(data, "Taunting", moves, "Taunt")
end

local function migrateFinisherSlot(data: Dictionary)
	local wrestler = ensureDictionary(data, "Wrestler")
	local moves = ensureDictionary(wrestler, "Moves")
	moveLegacyField(moves, "GrappleHeavy", moves, "Finisher")
end

local MIGRATIONS: { [number]: Migration } = {
	[1] = migrateLegacyRoot,
	[2] = migrateFinisherSlot,
}

function ProfileMigrations.Apply(data: Dictionary): number
	local rawVersion = data.SchemaVersion
	local version = if type(rawVersion) == "number"
			and rawVersion == rawVersion
			and rawVersion ~= math.huge
			and rawVersion ~= -math.huge
		then math.max(1, math.floor(rawVersion))
		else 1
	if version > CURRENT_SCHEMA_VERSION then
		error(
			string.format(
				"Player data schema %d is newer than supported schema %d",
				version,
				CURRENT_SCHEMA_VERSION
			)
		)
	end

	while version < CURRENT_SCHEMA_VERSION do
		local migration = MIGRATIONS[version]
		if migration == nil then
			error(string.format("Missing player data migration from schema %d", version))
		end

		migration(data)
		version += 1
		data.SchemaVersion = version
	end

	return version
end

function ProfileMigrations.GetCurrentVersion(): number
	return CURRENT_SCHEMA_VERSION
end

return table.freeze(ProfileMigrations)
