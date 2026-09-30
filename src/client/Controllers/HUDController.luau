--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(script.Parent.Parent.KnitClient)
local Trove = require(ReplicatedStorage.Packages.Trove)
local UIResolver = require(script.Parent.Parent.UI.UIResolver)

local HUDController = Knit.CreateController({
	Name = "HUDController",
})

function HUDController:KnitInit()
	self._trove = Trove.new()
	self._characterTrove = Trove.new()
	self._trove:Add(self._characterTrove)
end

local function numericAttribute(instance: Instance, name: string): number
	local value = instance:GetAttribute(name)
	return if type(value) == "number" then value else 0
end

local function stringAttribute(instance: Instance, name: string, fallback: string): string
	local value = instance:GetAttribute(name)
	return if type(value) == "string" then value else fallback
end

function HUDController:_renderCharacter(character: Model)
	local health = numericAttribute(character, "CombatHealth")
	local stamina = numericAttribute(character, "CombatStamina")
	local finisher = numericAttribute(character, "CombatFinisher")
	local state = stringAttribute(character, "CombatState", "Roaming")

	UIResolver.SetText({ "HUD", "Health" }, string.format("Health %d", math.round(health)))
	UIResolver.SetText({ "HUD", "Stamina" }, string.format("Stamina %d", math.round(stamina)))
	UIResolver.SetText({ "HUD", "Finisher" }, string.format("Finisher %d", math.round(finisher)))
	UIResolver.SetText({ "HUD", "State" }, state)
end

function HUDController:_bindCharacter(character: Model)
	self._characterTrove:Clean()
	for _, attribute in { "CombatHealth", "CombatStamina", "CombatFinisher", "CombatState" } do
		self._characterTrove:Connect(character:GetAttributeChangedSignal(attribute), function()
			self:_renderCharacter(character)
		end)
	end
	self:_renderCharacter(character)
end

function HUDController:KnitStart()
	local player = Players.LocalPlayer
	self._trove:Connect(player.CharacterAdded, function(character)
		self:_bindCharacter(character)
	end)
	if player.Character ~= nil then
		self:_bindCharacter(player.Character)
	end
end

return HUDController
