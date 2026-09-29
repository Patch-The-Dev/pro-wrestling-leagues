--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatTypes = require(ReplicatedStorage.Shared.Types.CombatTypes)

type DamageSpec = CombatTypes.DamageSpec

local WeaponComponent = {}
WeaponComponent.__index = WeaponComponent

export type WeaponComponent = typeof(setmetatable(
	{} :: {
		Instance: Tool,
		NetworkId: string,
		DefinitionId: string,
		MaxDurability: number,
		Durability: number,
		Damage: number,
		PoiseDamage: number,
		UseCooldown: number,
		_worldParent: Instance?,
		_lastUsedAt: number,
	},
	WeaponComponent
))

function WeaponComponent.new(tool: Tool, networkId: string): WeaponComponent
	local maxDurability = tool:GetAttribute("MaxDurability")
	local initialDurability = tool:GetAttribute("Durability")
	local damage = tool:GetAttribute("Damage")
	local poiseDamage = tool:GetAttribute("PoiseDamage")
	local useCooldown = tool:GetAttribute("UseCooldown")
	local definitionId = tool:GetAttribute("WeaponId")

	local resolvedMaxDurability = if type(maxDurability) == "number"
		then math.max(1, math.floor(maxDurability))
		else 5
	local resolvedDurability = if type(initialDurability) == "number"
		then math.clamp(math.floor(initialDurability), 0, resolvedMaxDurability)
		else resolvedMaxDurability

	local self = setmetatable({
		Instance = tool,
		NetworkId = networkId,
		DefinitionId = if type(definitionId) == "string" and definitionId ~= ""
			then definitionId
			else tool.Name,
		MaxDurability = resolvedMaxDurability,
		Durability = resolvedDurability,
		Damage = if type(damage) == "number" then math.max(0, damage) else 8,
		PoiseDamage = if type(poiseDamage) == "number" then math.max(0, poiseDamage) else 15,
		UseCooldown = if type(useCooldown) == "number" then math.max(0.1, useCooldown) else 0.65,
		_worldParent = tool.Parent,
		_lastUsedAt = -math.huge,
	}, WeaponComponent)

	if self.Durability <= 0 then
		tool.Enabled = false
	end
	self:_replicate()
	return self
end

function WeaponComponent:_replicate()
	self.Instance:SetAttribute("WeaponId", self.DefinitionId)
	self.Instance:SetAttribute("WeaponNetworkId", self.NetworkId)
	self.Instance:SetAttribute("Durability", self.Durability)
	self.Instance:SetAttribute("MaxDurability", self.MaxDurability)
	self.Instance:SetAttribute("UseCooldown", self.UseCooldown)
end

function WeaponComponent:IsOwnedBy(player: Player): boolean
	local parent = self.Instance.Parent
	if parent == player.Character then
		return true
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	return backpack ~= nil and parent == backpack
end

function WeaponComponent:IsEquippedBy(player: Player): boolean
	return player.Character ~= nil and self.Instance.Parent == player.Character
end

function WeaponComponent:GetOwner(): Player?
	for _, player in Players:GetPlayers() do
		if self:IsOwnedBy(player) then
			return player
		end
	end
	return nil
end

function WeaponComponent:GetWorldParent(): Instance?
	return self._worldParent
end

function WeaponComponent:IsAvailableForPickup(): boolean
	return self.Durability > 0
		and self.Instance:IsDescendantOf(workspace)
		and self:GetOwner() == nil
end

function WeaponComponent:CanUse(): boolean
	return self.Durability > 0 and os.clock() - self._lastUsedAt >= self.UseCooldown
end

function WeaponComponent:Pickup(player: Player): boolean
	if not self:IsAvailableForPickup() then
		return false
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack == nil then
		return false
	end

	self.Instance.Parent = backpack
	return true
end

function WeaponComponent:Drop(player: Player): boolean
	if not self:IsOwnedBy(player) then
		return false
	end

	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	local worldParent = self._worldParent
	if
		worldParent == nil
		or (worldParent ~= workspace and not worldParent:IsDescendantOf(workspace))
	then
		worldParent = workspace
	end
	self.Instance.Parent = worldParent

	local handle = self.Instance:FindFirstChild("Handle")
	if root and root:IsA("BasePart") and handle and handle:IsA("BasePart") then
		handle.CFrame = root.CFrame * CFrame.new(0, 0, -3)
	end

	return true
end

function WeaponComponent:ConsumeUse(): boolean
	if not self:CanUse() then
		return false
	end

	self._lastUsedAt = os.clock()
	self.Durability -= 1
	self:_replicate()

	if self.Durability <= 0 then
		self.Instance.Enabled = false
	end

	return true
end

function WeaponComponent:Reset()
	self.Durability = self.MaxDurability
	self._lastUsedAt = -math.huge
	self.Instance.Enabled = true
	self:_replicate()
end

function WeaponComponent:GetDamageSpec(): DamageSpec
	return {
		HealthDamage = self.Damage,
		PoiseDamage = self.PoiseDamage,
		AttackerFinisher = 4,
		VictimFinisher = 2,
		StunSeconds = 0.8,
	}
end

function WeaponComponent:Destroy()
	-- The Tool owns its Instances. The registry owns only this component object.
end

return WeaponComponent
