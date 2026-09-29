--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatTypes = require(ReplicatedStorage.Shared.Types.CombatTypes)
local CustomizationConfig = require(ReplicatedStorage.Shared.Config.CustomizationConfig)
local EntranceConfig = require(ReplicatedStorage.Shared.Config.EntranceConfig)
local MovesConfig = require(ReplicatedStorage.Shared.Config.MovesConfig)

local ProfileTemplate = require(script.Parent.ProfileTemplate)

type Dictionary = { [string]: unknown }
type SerializableKey = string | number
type MoveCategory = CombatTypes.MoveCategory

local ProfileSanitizer = {}

local function asDictionary(value: unknown): Dictionary?
	return if type(value) == "table" then value :: Dictionary else nil
end

local function ensureDictionary(parent: Dictionary, key: string): Dictionary
	local current = asDictionary(parent[key])
	if current ~= nil then
		return current
	end

	local created: Dictionary = {}
	parent[key] = created
	return created
end

local MAX_SAFE_INTEGER = 9_007_199_254_740_991
local MAX_RECENT_MATCH_IDS = 64

local function finiteNonNegative(value: unknown, fallback: number, integer: boolean): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return fallback
	end

	local normalized = math.clamp(value, 0, MAX_SAFE_INTEGER)
	return if integer then math.floor(normalized) else normalized
end

local function validSkinTone(value: unknown, fallback: string): string
	if type(value) ~= "string" or string.match(value, "^#?%x%x%x%x%x%x$") == nil then
		return fallback
	end
	return value
end

local function optionalAssetId(value: unknown): string?
	if value == nil or type(value) ~= "string" then
		return nil
	end

	local digits = string.match(value, "^(%d+)$") or string.match(value, "^rbxassetid://(%d+)$")
	if digits == nil or #digits > 32 then
		return nil
	end
	return digits
end

local function sanitizeBooleanMap(values: Dictionary)
	local mixedValues = (values :: unknown) :: { [SerializableKey]: unknown }
	local invalidKeys: { SerializableKey } = {}
	for key, value in mixedValues do
		if type(key) ~= "string" or type(value) ~= "boolean" then
			table.insert(invalidKeys, key)
		end
	end

	for _, key in invalidKeys do
		mixedValues[key] = nil
	end
end

local function sanitizeMove(
	moves: Dictionary,
	unlockedMoves: Dictionary,
	key: string,
	expectedCategory: MoveCategory,
	fallback: string
)
	local candidate = moves[key]
	local moveId = if type(candidate) == "string" then candidate else fallback
	local definition = MovesConfig.Get(moveId)
	if
		definition == nil
		or definition.Category ~= expectedCategory
		or unlockedMoves[moveId] ~= true
	then
		moveId = fallback
	end

	moves[key] = moveId
	-- Default loadout moves are always available, even in older profiles.
	unlockedMoves[fallback] = true
end

function ProfileSanitizer.Apply(data: Dictionary)
	data.SchemaVersion = ProfileTemplate.SchemaVersion

	local currencies = ensureDictionary(data, "Currencies")
	currencies.Cash = finiteNonNegative(currencies.Cash, ProfileTemplate.Currencies.Cash, true)
	currencies.Tickets =
		finiteNonNegative(currencies.Tickets, ProfileTemplate.Currencies.Tickets, true)

	local progression = ensureDictionary(data, "Progression")
	progression.Experience =
		finiteNonNegative(progression.Experience, ProfileTemplate.Progression.Experience, true)
	progression.Fame = finiteNonNegative(progression.Fame, ProfileTemplate.Progression.Fame, true)

	local statistics = ensureDictionary(data, "Statistics")
	statistics.Wins = finiteNonNegative(statistics.Wins, ProfileTemplate.Statistics.Wins, true)
	statistics.Losses =
		finiteNonNegative(statistics.Losses, ProfileTemplate.Statistics.Losses, true)
	local recentMatchIds: { string } = {}
	local seenMatchIds: { [string]: boolean } = {}
	if type(statistics.RecentMatchIds) == "table" then
		local stored = statistics.RecentMatchIds :: { unknown }
		for index = #stored, 1, -1 do
			local id = stored[index]
			if
				type(id) == "string"
				and #id == 36
				and string.match(id, "^[%x%-]+$") ~= nil
				and not seenMatchIds[id]
			then
				table.insert(recentMatchIds, 1, id)
				seenMatchIds[id] = true
				if #recentMatchIds >= MAX_RECENT_MATCH_IDS then
					break
				end
			end
		end
	end
	statistics.RecentMatchIds = recentMatchIds

	local wrestler = ensureDictionary(data, "Wrestler")
	wrestler.DisplayName = if type(wrestler.DisplayName) == "string"
			and #wrestler.DisplayName <= 50
		then wrestler.DisplayName
		else ProfileTemplate.Wrestler.DisplayName

	local appearance = ensureDictionary(wrestler, "Appearance")
	appearance.SkinTone =
		validSkinTone(appearance.SkinTone, ProfileTemplate.Wrestler.Appearance.SkinTone)
	appearance.HairId = optionalAssetId(appearance.HairId)
	appearance.FaceId = optionalAssetId(appearance.FaceId)
	appearance.ShirtId = optionalAssetId(appearance.ShirtId)
	appearance.PantsId = optionalAssetId(appearance.PantsId)

	local accessories = appearance.Accessories
	local sanitizedAccessories: { string } = {}
	if type(accessories) == "table" then
		for _, value in accessories :: { unknown } do
			local assetId = optionalAssetId(value)
			if assetId ~= nil and #sanitizedAccessories < 20 then
				table.insert(sanitizedAccessories, assetId)
			end
		end
	end
	appearance.Accessories = sanitizedAccessories

	local unlocks = ensureDictionary(data, "Unlocks")
	local unlockedMoves = ensureDictionary(unlocks, "Moves")
	local unlockedCosmetics = ensureDictionary(unlocks, "Cosmetics")
	local unlockedEntrances = ensureDictionary(unlocks, "Entrances")
	sanitizeBooleanMap(unlockedMoves)
	sanitizeBooleanMap(unlockedCosmetics)
	sanitizeBooleanMap(unlockedEntrances)

	local moves = ensureDictionary(wrestler, "Moves")
	local defaults = CustomizationConfig.DefaultMoves
	sanitizeMove(moves, unlockedMoves, "Attack1", "Attack", defaults.Attack1)
	sanitizeMove(moves, unlockedMoves, "Attack2", "Attack", defaults.Attack2)
	sanitizeMove(moves, unlockedMoves, "Attack3", "Attack", defaults.Attack3)
	sanitizeMove(moves, unlockedMoves, "RunningAttack", "RunningAttack", defaults.RunningAttack)
	sanitizeMove(
		moves,
		unlockedMoves,
		"TurnbuckleAttack",
		"TurnbuckleAttack",
		defaults.TurnbuckleAttack
	)
	sanitizeMove(
		moves,
		unlockedMoves,
		"RunningGrappleMove",
		"RunningGrapple",
		defaults.RunningGrappleMove
	)
	sanitizeMove(moves, unlockedMoves, "GrappleForward", "Grapple", defaults.GrappleForward)
	sanitizeMove(moves, unlockedMoves, "GrappleLeft", "Grapple", defaults.GrappleLeft)
	sanitizeMove(moves, unlockedMoves, "GrappleBackward", "Grapple", defaults.GrappleBackward)
	sanitizeMove(moves, unlockedMoves, "GrappleRight", "Grapple", defaults.GrappleRight)
	sanitizeMove(moves, unlockedMoves, "Finisher", "Grapple", defaults.Finisher)
	sanitizeMove(moves, unlockedMoves, "Taunt", "Taunt", defaults.Taunt)

	local entrance = ensureDictionary(data, "Entrance")
	entrance.MusicId = optionalAssetId(entrance.MusicId)
	local pyroPreset = entrance.PyroPreset
	entrance.PyroPreset = if type(pyroPreset) == "string"
			and EntranceConfig.PyroPresets[pyroPreset] ~= nil
		then pyroPreset
		else ProfileTemplate.Entrance.PyroPreset
	local lightingPreset = entrance.LightingPreset
	entrance.LightingPreset = if type(lightingPreset) == "string"
			and EntranceConfig.LightingPresets[lightingPreset] ~= nil
		then lightingPreset
		else ProfileTemplate.Entrance.LightingPreset
end

return table.freeze(ProfileSanitizer)
