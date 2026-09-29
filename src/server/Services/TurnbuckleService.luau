--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.Config.CombatConfig)
local Knit = require(ReplicatedStorage.Packages.Knit)
local Trove = require(ReplicatedStorage.Packages.Trove)

local TurnbuckleService = Knit.CreateService({
	Name = "TurnbuckleService",
	Client = {
		TurnbuckleChanged = Knit.CreateSignal(),
	},
})

function TurnbuckleService:KnitInit()
	self._trove = Trove.new()
end

function TurnbuckleService:KnitStart()
	self._requestGate = Knit.GetService("RequestGateService")
	self._combatService = Knit.GetService("CombatService")
	self._matchService = Knit.GetService("MatchService")
end

function TurnbuckleService:_findNearest(player: Player): BasePart?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return nil
	end

	local nearest: BasePart? = nil
	local nearestDistance = CombatConfig.Targeting.TurnbuckleRange
	for _, instance in CollectionService:GetTagged("Turnbuckle") do
		if
			instance:IsA("BasePart")
			and self._matchService:IsInstanceInPlayerArena(player, instance)
		then
			local distance = (root.Position - instance.Position).Magnitude
			if distance <= nearestDistance then
				nearest = instance
				nearestDistance = distance
			end
		end
	end
	return nearest
end

function TurnbuckleService:Toggle(player: Player): (boolean, string?)
	if not self._matchService:IsMatchActiveFor(player) then
		return false, "No active match"
	end

	local state = self._combatService:GetState(player)
	if state == "SittingOnTurnbuckle" or state == "ClimbingTurnbuckle" then
		self._combatService:LeaveTurnbuckle(player)
		self.Client.TurnbuckleChanged:Fire(player, false)
		return true, nil
	end

	local turnbuckle = self:_findNearest(player)
	if turnbuckle == nil then
		return false, "No turnbuckle in range"
	end

	if not self._combatService:EnterTurnbuckle(player, turnbuckle) then
		return false, "Cannot climb in the current state"
	end
	self.Client.TurnbuckleChanged:Fire(player, true)
	return true, nil
end

function TurnbuckleService.Client:Toggle(player: Player)
	if not self.Server._requestGate:Allow(player, "Interaction") then
		return false, "Too many requests"
	end
	return self.Server:Toggle(player)
end

return TurnbuckleService
