--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatTypes = require(ReplicatedStorage.Shared.Types.CombatTypes)
local Contracts = require(ReplicatedStorage.Shared.Network.Contracts)
local Knit = require(ReplicatedStorage.Packages.Knit)
local Trove = require(ReplicatedStorage.Packages.Trove)

local CombatCoordinatorModule = require(script.Parent.Parent.Application.CombatCoordinator)

type CombatAction = CombatTypes.CombatAction
type DamageSpec = CombatTypes.DamageSpec
type GrappleDirection = CombatTypes.GrappleDirection
type CombatCoordinator = CombatCoordinatorModule.CombatCoordinator

local CombatService = Knit.CreateService({
	Name = "CombatService",
	Client = {
		ActionStarted = Knit.CreateSignal(),
		ActionResolved = Knit.CreateSignal(),
		GrappleWindow = Knit.CreateSignal(),
		PinPrompt = Knit.CreateSignal(),
		PinResolved = Knit.CreateSignal(),
	},
})

function CombatService:KnitInit()
	self._trove = Trove.new()
	self._coordinator = nil :: CombatCoordinator?
end

function CombatService:KnitStart()
	self._requestGate = Knit.GetService("RequestGateService")
	local dataService = Knit.GetService("DataService")
	local matchService = Knit.GetService("MatchService")

	local coordinator = CombatCoordinatorModule.new({
		DataSource = dataService,
		MatchSource = matchService,
		EmitAction = function(recipient, event)
			self.Client.ActionResolved:Fire(recipient, event)
		end,
		EmitActionStarted = function(recipient, event)
			self.Client.ActionStarted:Fire(recipient, event)
		end,
		EmitGrappleWindow = function(recipient, sessionId, endsAt)
			self.Client.GrappleWindow:Fire(recipient, sessionId, endsAt)
		end,
		EmitPinPrompt = function(recipient, sessionId, targetTime)
			self.Client.PinPrompt:Fire(recipient, sessionId, targetTime)
		end,
		EmitPinResolved = function(recipient, sessionId, result)
			self.Client.PinResolved:Fire(recipient, sessionId, result)
		end,
	})
	self._coordinator = coordinator
	self._trove:Add(coordinator)
	self._trove:Connect(matchService.SessionClosed, function(players)
		coordinator:ResetForMatchEnd(players)
	end)
end

function CombatService:_getCoordinator(): CombatCoordinator
	local coordinator = self._coordinator
	assert(coordinator ~= nil, "CombatService has not started")
	return coordinator
end

function CombatService:GetState(player: Player): CombatTypes.CombatState?
	return self:_getCoordinator():GetState(player)
end

function CombatService:EnterTurnbuckle(player: Player, turnbuckle: BasePart): boolean
	return self:_getCoordinator():EnterTurnbuckle(player, turnbuckle)
end

function CombatService:LeaveTurnbuckle(player: Player)
	self:_getCoordinator():LeaveTurnbuckle(player)
end

function CombatService:ApplyWeaponAttack(
	player: Player,
	damage: DamageSpec,
	weaponId: string
): boolean
	return self:_getCoordinator():ApplyWeaponAttack(player, damage, weaponId)
end

function CombatService:RequestAction(player: Player, action: CombatAction): (boolean, string?)
	return self:_getCoordinator():RequestAction(player, action)
end

function CombatService:RequestGrapple(
	player: Player,
	direction: GrappleDirection,
	running: boolean
): (boolean, string?)
	return self:_getCoordinator():RequestGrapple(player, direction, running)
end

function CombatService:TryReverse(player: Player, sessionId: string): boolean
	return self:_getCoordinator():TryReverse(player, sessionId)
end

function CombatService:SubmitPinInput(player: Player, sessionId: string): boolean
	return self:_getCoordinator():SubmitPinInput(player, sessionId)
end

function CombatService.Client:RequestAction(player: Player, rawAction: unknown)
	if not self.Server._requestGate:Allow(player, "Combat") then
		return false, "Too many requests"
	end

	local action = Contracts.AsCombatAction(rawAction)
	if action == nil or action == "Grapple" or action == "RunningGrapple" then
		return false, "Invalid action"
	end
	return self.Server:RequestAction(player, action)
end

function CombatService.Client:RequestGrapple(
	player: Player,
	rawDirection: unknown,
	rawRunning: unknown
)
	if not self.Server._requestGate:Allow(player, "Combat") then
		return false, "Too many requests"
	end

	local direction = Contracts.AsGrappleDirection(rawDirection)
	if direction == nil or type(rawRunning) ~= "boolean" then
		return false, "Invalid request"
	end
	return self.Server:RequestGrapple(player, direction, rawRunning)
end

function CombatService.Client:TryReverse(player: Player, rawSessionId: unknown)
	if
		not self.Server._requestGate:Allow(player, "Combat")
		or not Contracts.IsSessionId(rawSessionId)
	then
		return false
	end
	return self.Server:TryReverse(player, rawSessionId :: string)
end

function CombatService.Client:SubmitPinInput(player: Player, rawSessionId: unknown)
	if
		not self.Server._requestGate:Allow(player, "Combat")
		or not Contracts.IsSessionId(rawSessionId)
	then
		return false
	end
	return self.Server:SubmitPinInput(player, rawSessionId :: string)
end

return CombatService
