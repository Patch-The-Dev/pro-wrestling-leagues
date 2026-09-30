--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatConfig = require(ReplicatedStorage.Shared.Config.CombatConfig)
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
		_spawnCFrame: CFrame?,
		_lastUsedAt: number,
		_useRevision: number,
	},
	WeaponComponent
))

local function boundedNumber(
	value: unknown,
	fallback: number,
	minimum: number,
	maximum: number
): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return fallback
	end
	return math.clamp(value, minimum, maximum)
end

function WeaponComponent.new(tool: Tool, networkId: string): WeaponComponent
	local maxDurability = tool:GetAttribute("MaxDurability")
	local initialDurability = tool:GetAttribute("Durability")
	local damage = tool:GetAttribute("Damage")
	local poiseDamage = tool:GetAttribute("PoiseDamage")
	local useCooldown = tool:GetAttribute("UseCooldown")
	local definitionId = tool:GetAttribute("WeaponId")
	local handle = tool:FindFirstChild("Handle")
	local spawnCFrame = if handle ~= nil and handle:IsA("BasePart") then handle.CFrame else nil

	local resolvedMaxDurability = math.floor(boundedNumber(maxDurability, 5, 1, 1000))
	local resolvedDurability = math.floor(
		boundedNumber(initialDurability, resolvedMaxDurability, 0, resolvedMaxDurability)
	)

	local self = setmetatable({
		Instance = tool,
		NetworkId = networkId,
		DefinitionId = if type(definitionId) == "string" and definitionId ~= ""
			then definitionId
			else tool.Name,
		MaxDurability = resolvedMaxDurability,
		Durability = resolvedDurability,
		Damage = boundedNumber(damage, 8, 0, CombatConfig.MaxHealth),
		PoiseDamage = boundedNumber(poiseDamage, 15, 0, CombatConfig.MaxPoise),
		UseCooldown = boundedNumber(useCooldown, 0.65, 0.1, 10),
		_worldParent = tool.Parent,
		_spawnCFrame = spawnCFrame,
		_lastUsedAt = -math.huge,
		_useRevision = 0,
	}, WeaponComponent)
	tool.CanBeDropped = false
	if handle ~= nil and handle:IsA("BasePart") then
		handle.CanTouch = false
	end

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

function WeaponComponent.IsOwnedBy(self: WeaponComponent, player: Player): boolean
	local parent = self.Instance.Parent
	local character = player.Character
	if character ~= nil and parent == (character :: Instance) then
		return true
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	return backpack ~= nil and parent == (backpack :: Instance)
end

function WeaponComponent.IsEquippedBy(self: WeaponComponent, player: Player): boolean
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

function WeaponComponent.ConsumeUse(self: WeaponComponent): (boolean, number?, number?)
	if not self:CanUse() then
		return false, nil, nil
	end

	local previousUsedAt = self._lastUsedAt
	self._useRevision += 1
	self._lastUsedAt = os.clock()
	self.Durability -= 1
	self:_replicate()

	if self.Durability <= 0 then
		self.Instance.Enabled = false
	end

	return true, previousUsedAt, self._useRevision
end

function WeaponComponent.RollbackUse(
	self: WeaponComponent,
	previousUsedAt: number,
	revision: number
): boolean
	if revision ~= self._useRevision or self.Durability >= self.MaxDurability then
		return false
	end
	self._useRevision += 1
	self._lastUsedAt = previousUsedAt
	self.Durability += 1
	self.Instance.Enabled = true
	self:_replicate()
	return true
end

function WeaponComponent.Reset(self: WeaponComponent)
	self._useRevision += 1
	self.Durability = self.MaxDurability
	self._lastUsedAt = -math.huge
	local worldParent = self._worldParent
	if
		worldParent ~= nil and (worldParent == workspace or worldParent:IsDescendantOf(workspace))
	then
		self.Instance.Parent = worldParent
	end
	local handle = self.Instance:FindFirstChild("Handle")
	if handle ~= nil and handle:IsA("BasePart") and self._spawnCFrame ~= nil then
		handle.CFrame = self._spawnCFrame
	end
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
