--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)

type Appearance = PlayerDataTypes.Appearance

local CustomizationAdapter = {}

local function numericAssetId(value: string?): number?
	if value == nil then
		return nil
	end

	local digits = string.match(value, "%d+")
	return if digits ~= nil then tonumber(digits) else nil
end

local function normalizeAccessoryIds(values: { string }): string
	local ids = {}
	for _, value in values do
		local assetId = numericAssetId(value)
		if assetId ~= nil then
			table.insert(ids, tostring(assetId))
		end
	end
	return table.concat(ids, ",")
end

local function parseSkinTone(value: string): Color3?
	local hex = string.match(value, "^#?(%x%x%x%x%x%x)$")
	if hex == nil then
		return nil
	end

	local ok, color = pcall(Color3.fromHex, hex)
	return if ok then color else nil
end

function CustomizationAdapter.Apply(character: Model, appearance: Appearance)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
		or character:WaitForChild("Humanoid", 5)
	if humanoid == nil or not humanoid:IsA("Humanoid") then
		warn(`Could not apply appearance to {character.Name}: Humanoid is unavailable`)
		return
	end

	local ok, description = pcall(function()
		return humanoid:GetAppliedDescription()
	end)
	if not ok then
		warn(`Could not read appearance for {character.Name}: {tostring(description)}`)
		return
	end

	local faceId = numericAssetId(appearance.FaceId)
	local shirtId = numericAssetId(appearance.ShirtId)
	local pantsId = numericAssetId(appearance.PantsId)
	local hairId = numericAssetId(appearance.HairId)

	description.Face = faceId or 0
	description.Shirt = shirtId or 0
	description.Pants = pantsId or 0
	description.HairAccessory = if hairId ~= nil then tostring(hairId) else ""
	description.HatAccessory = normalizeAccessoryIds(appearance.Accessories)

	local skinTone = parseSkinTone(appearance.SkinTone)
	if skinTone ~= nil then
		description.HeadColor = skinTone
		description.LeftArmColor = skinTone
		description.RightArmColor = skinTone
		description.LeftLegColor = skinTone
		description.RightLegColor = skinTone
		description.TorsoColor = skinTone
	end

	local applied, applyError = pcall(function()
		humanoid:ApplyDescriptionAsync(description)
	end)
	if not applied then
		warn(`Could not apply appearance to {character.Name}: {tostring(applyError)}`)
	end
end

return table.freeze(CustomizationAdapter)
