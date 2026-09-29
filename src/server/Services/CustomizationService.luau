--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Contracts = require(ReplicatedStorage.Shared.Network.Contracts)
local CustomizationAdapter = require(script.Parent.Parent.Adapters.CustomizationAdapter)
local CustomizationConfig = require(ReplicatedStorage.Shared.Config.CustomizationConfig)
local Knit = require(ReplicatedStorage.Packages.Knit)
local MovesConfig = require(ReplicatedStorage.Shared.Config.MovesConfig)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local Trove = require(ReplicatedStorage.Packages.Trove)

type AppearanceAssetField = PlayerDataTypes.AppearanceAssetField
type MoveLoadout = PlayerDataTypes.MoveLoadout
type MoveSlot = PlayerDataTypes.MoveSlot

local CustomizationService = Knit.CreateService({
	Name = "CustomizationService",
	Client = {
		LoadoutChanged = Knit.CreateSignal(),
		AppearanceChanged = Knit.CreateSignal(),
	},
})

local function setMove(loadout: MoveLoadout, slot: MoveSlot, moveId: string)
	if slot == "Attack1" then
		loadout.Attack1 = moveId
	elseif slot == "Attack2" then
		loadout.Attack2 = moveId
	elseif slot == "Attack3" then
		loadout.Attack3 = moveId
	elseif slot == "RunningAttack" then
		loadout.RunningAttack = moveId
	elseif slot == "TurnbuckleAttack" then
		loadout.TurnbuckleAttack = moveId
	elseif slot == "RunningGrappleMove" then
		loadout.RunningGrappleMove = moveId
	elseif slot == "GrappleForward" then
		loadout.GrappleForward = moveId
	elseif slot == "GrappleLeft" then
		loadout.GrappleLeft = moveId
	elseif slot == "GrappleBackward" then
		loadout.GrappleBackward = moveId
	elseif slot == "GrappleRight" then
		loadout.GrappleRight = moveId
	elseif slot == "Finisher" then
		loadout.Finisher = moveId
	else
		loadout.Taunt = moveId
	end
end

local function setAppearanceAsset(
	appearance: PlayerDataTypes.Appearance,
	field: AppearanceAssetField,
	assetId: string?
)
	if field == "HairId" then
		appearance.HairId = assetId
	elseif field == "FaceId" then
		appearance.FaceId = assetId
	elseif field == "ShirtId" then
		appearance.ShirtId = assetId
	else
		appearance.PantsId = assetId
	end
end

function CustomizationService:KnitInit()
	self._trove = Trove.new()
end

function CustomizationService:KnitStart()
	self._requestGate = Knit.GetService("RequestGateService")
	self._dataService = Knit.GetService("DataService")
	self._trove:Connect(self._dataService.Loaded, function(player)
		if player.Character ~= nil then
			self:_applyAppearance(player, player.Character)
		end
	end)

	local function bindPlayer(player: Player)
		self._trove:Connect(player.CharacterAdded, function(character)
			task.defer(function()
				self:_applyAppearance(player, character)
			end)
		end)

		if player.Character ~= nil then
			task.defer(function()
				self:_applyAppearance(player, player.Character :: Model)
			end)
		end
	end

	self._trove:Connect(Players.PlayerAdded, bindPlayer)
	for _, player in Players:GetPlayers() do
		bindPlayer(player)
	end
end

function CustomizationService:_applyAppearance(player: Player, character: Model)
	local data = self._dataService:Get(player)
	if data == nil then
		return
	end

	CustomizationAdapter.Apply(character, data.Wrestler.Appearance)
end

function CustomizationService:EquipMove(
	player: Player,
	slot: MoveSlot,
	moveId: string
): (boolean, string?)
	local expectedCategory = CustomizationConfig.MoveSlots[slot]
	local move = MovesConfig.Get(moveId)
	if expectedCategory == nil or move == nil or move.Category ~= expectedCategory then
		return false, "Move is not valid for this slot"
	end

	local reason = "Player data unavailable"
	local changed = self._dataService:Update(player, function(data)
		if not data.Unlocks.Moves[moveId] then
			reason = "Move is not unlocked"
			return
		end

		setMove(data.Wrestler.Moves, slot, moveId)
		reason = "Changed"
	end)

	if not changed or reason ~= "Changed" then
		return false, reason
	end

	self.Client.LoadoutChanged:Fire(player, slot, moveId)
	return true, nil
end

function CustomizationService:SetAppearanceAsset(
	player: Player,
	field: AppearanceAssetField,
	assetId: string?
): (boolean, string?)
	if not Contracts.IsOptionalAssetId(assetId) then
		return false, "Invalid asset id"
	end

	local result = "Player data unavailable"
	local changed = self._dataService:Update(player, function(data)
		if assetId ~= nil and not data.Unlocks.Cosmetics[assetId] then
			result = "Appearance asset is not unlocked"
			return
		end

		setAppearanceAsset(data.Wrestler.Appearance, field, assetId)
		result = "Changed"
	end)
	if not changed or result ~= "Changed" then
		return false, result
	end

	if player.Character ~= nil then
		self:_applyAppearance(player, player.Character)
	end
	self.Client.AppearanceChanged:Fire(player, field, assetId)
	return true, nil
end

function CustomizationService.Client:EquipMove(player: Player, rawSlot: unknown, rawMoveId: unknown)
	if not self.Server._requestGate:Allow(player, "Customization") then
		return false, "Too many requests"
	end

	local slot = Contracts.AsMoveSlot(rawSlot)
	if slot == nil or not Contracts.IsMoveId(rawMoveId) then
		return false, "Invalid request"
	end

	return self.Server:EquipMove(player, slot, rawMoveId :: string)
end

function CustomizationService.Client:SetAppearanceAsset(
	player: Player,
	rawField: unknown,
	rawAssetId: unknown
)
	if not self.Server._requestGate:Allow(player, "Customization") then
		return false, "Too many requests"
	end

	local field = Contracts.AsAppearanceAssetField(rawField)
	if field == nil or not Contracts.IsOptionalAssetId(rawAssetId) then
		return false, "Invalid request"
	end

	return self.Server:SetAppearanceAsset(player, field, rawAssetId :: string?)
end

return CustomizationService
