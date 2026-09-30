--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(script.Parent.Parent.KnitClient)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)

type AppearanceAssetField = PlayerDataTypes.AppearanceAssetField
type MoveSlot = PlayerDataTypes.MoveSlot

local CustomizationController = Knit.CreateController({
	Name = "CustomizationController",
})

function CustomizationController:KnitStart()
	self._service = Knit.GetService("CustomizationService")
	self._dataController = Knit.GetController("DataController")
end

function CustomizationController:EquipMove(slot: MoveSlot, moveId: string)
	return self._service:EquipMove(slot, moveId):andThen(function(success, reason)
		if success then
			self._dataController:Refresh()
		end
		return success, reason
	end)
end

function CustomizationController:SetAppearanceAsset(field: AppearanceAssetField, assetId: string?)
	return self._service:SetAppearanceAsset(field, assetId):andThen(function(success, reason)
		if success then
			self._dataController:Refresh()
		end
		return success, reason
	end)
end

return CustomizationController
