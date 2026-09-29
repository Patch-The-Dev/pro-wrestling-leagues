--!strict

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.Config.CombatConfig)
local Contracts = require(ReplicatedStorage.Shared.Network.Contracts)
local Knit = require(ReplicatedStorage.Packages.Knit)
local NetworkTypes = require(ReplicatedStorage.Shared.Types.NetworkTypes)
local Trove = require(ReplicatedStorage.Packages.Trove)
local WeaponAttack = require(script.Parent.Parent.Domain.Combat.WeaponAttack)
local WeaponComponentModule = require(script.Parent.Parent.Components.WeaponComponent)

type WeaponAction = NetworkTypes.WeaponAction
type WeaponComponent = WeaponComponentModule.WeaponComponent

local WeaponService = Knit.CreateService({
	Name = "WeaponService",
	Client = {
		WeaponChanged = Knit.CreateSignal(),
	},
})

function WeaponService:KnitInit()
	self._trove = Trove.new()
	self._weaponsByNetworkId = {}
	self._componentsByTool = {}
end

function WeaponService:KnitStart()
	self._requestGate = Knit.GetService("RequestGateService")
	self._combatService = Knit.GetService("CombatService")
	self._matchService = Knit.GetService("MatchService")
	self._trove:Connect(self._matchService.SessionClosed, function(players)
		self:_resetForMatchEnd(players)
	end)

	for _, instance in CollectionService:GetTagged("WrestlingWeapon") do
		self:_register(instance)
	end
	self._trove:Connect(
		CollectionService:GetInstanceAddedSignal("WrestlingWeapon"),
		function(instance)
			self:_register(instance)
		end
	)
	self._trove:Connect(
		CollectionService:GetInstanceRemovedSignal("WrestlingWeapon"),
		function(instance)
			self:_unregister(instance)
		end
	)
end

function WeaponService:_register(instance: Instance)
	if not instance:IsA("Tool") or self._componentsByTool[instance] ~= nil then
		return
	end

	local networkId = HttpService:GenerateGUID(false)
	local component = WeaponComponentModule.new(instance, networkId)
	self._componentsByTool[instance] = component
	self._weaponsByNetworkId[networkId] = component
end

function WeaponService:_unregister(instance: Instance)
	if not instance:IsA("Tool") then
		return
	end

	local component = self._componentsByTool[instance]
	if component == nil then
		return
	end

	self._componentsByTool[instance] = nil
	if self._weaponsByNetworkId[component.NetworkId] == component then
		self._weaponsByNetworkId[component.NetworkId] = nil
	end
	component:Destroy()
end

function WeaponService:_belongsToPlayerArena(player: Player, component: WeaponComponent): boolean
	local worldParent = component:GetWorldParent()
	return worldParent ~= nil and self._matchService:IsInstanceInPlayerArena(player, worldParent)
end

function WeaponService:_resetForMatchEnd(players: { Player })
	for _, component in self._componentsByTool do
		local belongsToClosingArena = false
		for _, player in players do
			if component:IsOwnedBy(player) then
				component:Drop(player)
			end
			if self:_belongsToPlayerArena(player, component) then
				belongsToClosingArena = true
			end
		end

		if belongsToClosingArena then
			component:Reset()
		end
	end
end

function WeaponService:_isNearWeapon(player: Player, component: WeaponComponent): boolean
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	local handle = component.Instance:FindFirstChild("Handle")
	if root == nil or not root:IsA("BasePart") or handle == nil or not handle:IsA("BasePart") then
		return false
	end

	return (root.Position - handle.Position).Magnitude <= CombatConfig.Targeting.WeaponRange
end

function WeaponService:RequestAction(
	player: Player,
	networkId: string,
	action: WeaponAction
): (boolean, string?)
	local component = self._weaponsByNetworkId[networkId]
	if component == nil then
		return false, "Unknown weapon"
	end

	if action == "Pickup" then
		if not self._matchService:IsMatchActiveFor(player) then
			return false, "No active match"
		end
		if not self._matchService:IsInstanceInPlayerArena(player, component.Instance) then
			return false, "Weapon is outside this match arena"
		end
		if not component:IsAvailableForPickup() or not self:_isNearWeapon(player, component) then
			return false, "Weapon is not available in range"
		end
		if not component:Pickup(player) then
			return false, "Weapon cannot be picked up"
		end
	elseif action == "Drop" then
		if not component:Drop(player) then
			return false, "Weapon is not owned by this player"
		end
	else
		local accepted, message = WeaponAttack.Try(
			player,
			component,
			self._matchService,
			self._combatService,
			function(candidate, weapon)
				return self:_belongsToPlayerArena(candidate, weapon)
			end
		)
		if not accepted then
			return false, message
		end
	end

	self.Client.WeaponChanged:Fire(player, networkId, action, component.Durability)
	return true, nil
end

function WeaponService.Client:RequestAction(
	player: Player,
	rawNetworkId: unknown,
	rawAction: unknown
)
	if not self.Server._requestGate:Allow(player, "Interaction") then
		return false, "Too many requests"
	end

	local action = Contracts.AsWeaponAction(rawAction)
	if action == nil or not Contracts.IsWeaponNetworkId(rawNetworkId) then
		return false, "Invalid request"
	end

	return self.Server:RequestAction(player, rawNetworkId :: string, action)
end

return WeaponService
