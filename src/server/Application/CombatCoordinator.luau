--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Trove = require(ReplicatedStorage.Packages.Trove)
local CombatConfig = require(ReplicatedStorage.Shared.Config.CombatConfig)
local CombatTypes = require(ReplicatedStorage.Shared.Types.CombatTypes)
local MatchTypes = require(ReplicatedStorage.Shared.Types.MatchTypes)
local NetworkTypes = require(ReplicatedStorage.Shared.Types.NetworkTypes)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)

local CharacterAdapter = require(script.Parent.Parent.Adapters.CharacterAdapter)
local ActionBudgetModule = require(script.Parent.Parent.Domain.Combat.ActionBudget)
local CombatantModule = require(script.Parent.Parent.Domain.Combat.Combatant)
local CombatRules = require(script.Parent.Parent.Domain.Combat.CombatRules)
local GrappleCoordinatorModule = require(script.Parent.Parent.Domain.Combat.GrappleCoordinator)
local PinCoordinatorModule = require(script.Parent.Parent.Domain.Combat.PinCoordinator)
local RecoverySchedulerModule = require(script.Parent.Parent.Domain.Combat.RecoveryScheduler)
local StrikeResolverModule = require(script.Parent.StrikeResolver)
local Targeting = require(script.Parent.Parent.Domain.Combat.Targeting)

type ActionBudget = ActionBudgetModule.ActionBudget
type CombatAction = CombatTypes.CombatAction
type CombatState = CombatTypes.CombatState
type DamageSpec = CombatTypes.DamageSpec
type GrappleDirection = CombatTypes.GrappleDirection
type MatchEndReason = MatchTypes.MatchEndReason
type ResolvedAction = CombatTypes.ResolvedAction
type PinResolution = NetworkTypes.PinResolution
type Combatant = CombatantModule.Combatant
type GrappleCoordinator = GrappleCoordinatorModule.GrappleCoordinator
type PinCoordinator = PinCoordinatorModule.PinCoordinator
type PlayerData = PlayerDataTypes.PlayerData
type RecoveryScheduler = RecoverySchedulerModule.RecoveryScheduler
type StrikeResolver = StrikeResolverModule.StrikeResolver

type DataSource = {
	Get: (self: DataSource, player: Player) -> PlayerData?,
}

type MatchSource = {
	IsMatchActiveFor: (self: MatchSource, player: Player) -> boolean,
	GetOpponents: (self: MatchSource, player: Player) -> { Player },
	FinishForKnockout: (self: MatchSource, loser: Player) -> (),
	FinishMatch: (self: MatchSource, winner: Player?, loser: Player?, reason: MatchEndReason) -> boolean,
}

type EmitAction = (recipient: Player, event: ResolvedAction) -> ()
type EmitGrappleWindow = (recipient: Player, sessionId: string, endsAt: number) -> ()
type EmitPinPrompt = (recipient: Player, sessionId: string, targetTime: number) -> ()
type EmitPinResolved = (recipient: Player, sessionId: string, result: PinResolution) -> ()

export type Dependencies = {
	DataSource: DataSource,
	MatchSource: MatchSource,
	EmitAction: EmitAction,
	EmitGrappleWindow: EmitGrappleWindow,
	EmitPinPrompt: EmitPinPrompt,
	EmitPinResolved: EmitPinResolved,
}

local CombatCoordinator = {}
CombatCoordinator.__index = CombatCoordinator

export type CombatCoordinator = typeof(setmetatable(
	{} :: {
		_trove: typeof(Trove.new()),
		_dataSource: DataSource,
		_matchSource: MatchSource,
		_emitAction: EmitAction,
		_combatants: { [Player]: Combatant },
		_reportedDeaths: { [Player]: boolean },
		_budget: ActionBudget,
		_recovery: RecoveryScheduler,
		_grapples: GrappleCoordinator,
		_pins: PinCoordinator,
		_strikes: StrikeResolver,
	},
	{} :: typeof(CombatCoordinator)
))

function CombatCoordinator.new(dependencies: Dependencies): CombatCoordinator
	local trove = Trove.new()
	local combatants: { [Player]: Combatant } = {}
	local budget = ActionBudgetModule.new()
	local recovery = RecoverySchedulerModule.new(function(player)
		return combatants[player]
	end)
	local grapples = GrappleCoordinatorModule.new(
		function(player)
			return combatants[player]
		end,
		recovery,
		dependencies.EmitAction,
		dependencies.EmitGrappleWindow
	)
	local pins = PinCoordinatorModule.new(
		function(player)
			return combatants[player]
		end,
		recovery,
		dependencies.EmitPinPrompt,
		dependencies.EmitPinResolved,
		function(winner, loser)
			dependencies.MatchSource:FinishMatch(winner, loser, "Pin")
		end
	)
	local strikes = StrikeResolverModule.new({
		DataSource = dependencies.DataSource,
		Budget = budget,
		Recovery = recovery,
		GetCombatant = function(player)
			return combatants[player]
		end,
		FindTarget = function(player, range)
			return Targeting.FindNearestOpponent(
				player,
				dependencies.MatchSource:GetOpponents(player),
				range,
				CombatConfig.Targeting.MinimumFacingDot
			)
		end,
		EmitToParticipants = function(attacker, target, event)
			dependencies.EmitAction(attacker, event)
			if target ~= nil and target ~= attacker then
				dependencies.EmitAction(target, event)
			end
		end,
	})

	local self = setmetatable({
		_trove = trove,
		_dataSource = dependencies.DataSource,
		_matchSource = dependencies.MatchSource,
		_emitAction = dependencies.EmitAction,
		_combatants = combatants,
		_reportedDeaths = {},
		_budget = budget,
		_recovery = recovery,
		_grapples = grapples,
		_pins = pins,
		_strikes = strikes,
	}, CombatCoordinator)

	trove:Add(budget)
	trove:Add(recovery)
	trove:Add(grapples)
	trove:Add(pins)

	local function bindPlayer(player: Player)
		trove:Connect(player.CharacterAdded, function(character)
			self:_bindCharacter(player, character)
		end)
		if player.Character ~= nil then
			self:_bindCharacter(player, player.Character)
		end
	end

	trove:Connect(Players.PlayerAdded, bindPlayer)
	trove:Connect(Players.PlayerRemoving, function(player)
		self:_removePlayer(player)
	end)
	trove:Connect(RunService.Heartbeat, function(deltaTime)
		self:_step(deltaTime)
	end)

	for _, player in Players:GetPlayers() do
		bindPlayer(player)
	end

	return self
end

function CombatCoordinator:_bindCharacter(player: Player, character: Model)
	self._grapples:CancelForPlayer(player)
	self._pins:CancelForPlayer(player)
	self:_removeCombatant(player)

	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if humanoid == nil or not humanoid:IsA("Humanoid") then
		return
	end

	self._combatants[player] = CombatantModule.new(player, character)
	self._reportedDeaths[player] = false
end

function CombatCoordinator:_removeCombatant(player: Player)
	local combatant = self._combatants[player]
	if combatant ~= nil then
		self._recovery:Forget(combatant)
		combatant:Destroy()
		self._combatants[player] = nil
	end
end

function CombatCoordinator:_removePlayer(player: Player)
	self._grapples:CancelForPlayer(player)
	self._pins:CancelForPlayer(player)
	self:_removeCombatant(player)
	self._budget:Forget(player)
	self._reportedDeaths[player] = nil
end

function CombatCoordinator:_step(deltaTime: number)
	for player, combatant in self._combatants do
		combatant:Step(deltaTime)

		if combatant:GetState() == "Dead" and self._reportedDeaths[player] ~= true then
			self._reportedDeaths[player] = true
			if self._matchSource:IsMatchActiveFor(player) then
				self._matchSource:FinishForKnockout(player)
			end
		end
	end
end

function CombatCoordinator:_findTarget(player: Player, range: number): Player?
	return Targeting.FindNearestOpponent(
		player,
		self._matchSource:GetOpponents(player),
		range,
		CombatConfig.Targeting.MinimumFacingDot
	)
end

function CombatCoordinator:_validateBase(player: Player, action: CombatAction): (Combatant?, string?)
	if not self._matchSource:IsMatchActiveFor(player) then
		return nil, "No active match"
	end

	local combatant = self._combatants[player]
	if combatant == nil then
		return nil, "Character is unavailable"
	end

	local allowed, reason = self._budget:Validate(player, combatant, action)
	if not allowed then
		return nil, reason
	end

	return combatant, nil
end

function CombatCoordinator:_isCharacterRunning(player: Player): boolean
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return false
	end

	local velocity = root.AssemblyLinearVelocity
	local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	return horizontalSpeed >= CombatConfig.Movement.RunningSpeedThreshold
end

function CombatCoordinator:GetState(player: Player): CombatState?
	local combatant = self._combatants[player]
	return if combatant ~= nil then combatant:GetState() else nil
end

function CombatCoordinator:EnterTurnbuckle(player: Player, turnbuckle: BasePart): boolean
	if not self._matchSource:IsMatchActiveFor(player) then
		return false
	end

	local combatant = self._combatants[player]
	if combatant == nil or combatant:GetState() ~= "Roaming" or not combatant:CanSetState("ClimbingTurnbuckle") then
		return false
	end

	combatant:SetState("ClimbingTurnbuckle")
	CharacterAdapter.SetMovementEnabled(combatant.Character, false)
	local target = turnbuckle.CFrame * CFrame.new(0, turnbuckle.Size.Y * 0.5 + 2.5, 0)
	CharacterAdapter.PlaceAt(combatant.Character, target)
	self._recovery:ScheduleState(combatant, "ClimbingTurnbuckle", "SittingOnTurnbuckle", 0.55)
	return true
end

function CombatCoordinator:LeaveTurnbuckle(player: Player)
	local combatant = self._combatants[player]
	if combatant == nil then
		return
	end

	local state = combatant:GetState()
	if state == "ClimbingTurnbuckle" or state == "SittingOnTurnbuckle" then
		combatant:SetState("Roaming")
	end
	CharacterAdapter.SetMovementEnabled(combatant.Character, true)
end

function CombatCoordinator:_requestStrike(player: Player, action: CombatAction): (boolean, string?)
	if action == "RunningAttack" and not self:_isCharacterRunning(player) then
		return false, "Running attack requires server-observed movement"
	end

	local combatant, reason = self:_validateBase(player, action)
	if combatant == nil then
		return false, reason
	end

	return self._strikes:Request(player, action, combatant)
end

function CombatCoordinator:RequestGrapple(player: Player, direction: GrappleDirection, running: boolean): (boolean, string?)
	local action: CombatAction = if running then "RunningGrapple" else "Grapple"
	if running and not self:_isCharacterRunning(player) then
		return false, "Running grapple requires server-observed movement"
	end

	local attacker, reason = self:_validateBase(player, action)
	if attacker == nil then
		return false, reason
	end

	local data = self._dataSource:Get(player)
	if data == nil then
		return false, "Player data is unavailable"
	end

	local isFinisher = not running and direction == "Finisher"
	if isFinisher and not attacker:CanSpendFinisher(CombatConfig.Finisher.RequiredCharge) then
		return false, "Finisher is not charged"
	end

	local targetPlayer = self:_findTarget(player, CombatConfig.Targeting.GrappleRange)
	local victim = if targetPlayer ~= nil then self._combatants[targetPlayer] else nil
	if targetPlayer == nil or victim == nil then
		return false, "No valid grapple target"
	end
	if victim:GetState() == "Dead" or victim:GetState() == "Pinned" then
		return false, "Target cannot be grappled"
	end

	local moveId = CombatRules.ResolveMoveId(data, action, nil, direction)
	local damage = if moveId ~= nil then CombatRules.GetDamage(moveId) else nil
	local duration = if moveId ~= nil then CombatRules.GetMoveDuration(moveId) else nil
	if moveId == nil or damage == nil or duration == nil then
		return false, "Grapple move configuration is missing"
	end
	if not attacker:CanSetState("Grappling") or not victim:CanSetState("Stunned") then
		return false, "Grapple state transition rejected"
	end

	if not self._budget:Commit(player, attacker, action) then
		return false, "Action resources changed before commit"
	end
	if isFinisher and not attacker:SpendFinisher(CombatConfig.Finisher.RequiredCharge) then
		self._budget:Rollback(player, attacker, action)
		return false, "Finisher charge changed before commit"
	end

	attacker:SetState("Grappling")
	victim:SetState("Stunned")

	if not self._grapples:Start(player, targetPlayer, action, moveId, damage, duration, isFinisher) then
		attacker:SetState("Roaming")
		victim:SetState("Roaming")
		self._budget:Rollback(player, attacker, action)
		if isFinisher then
			attacker:RestoreFinisher(CombatConfig.Finisher.RequiredCharge)
		end
		return false, "Unable to start grapple"
	end

	return true, nil
end

function CombatCoordinator:RequestPin(player: Player): (boolean, string?)
	local pinner, reason = self:_validateBase(player, "Pin")
	if pinner == nil then
		return false, reason
	end

	local targetPlayer = self:_findTarget(player, CombatConfig.Targeting.PinRange)
	local victim = if targetPlayer ~= nil then self._combatants[targetPlayer] else nil
	if targetPlayer == nil or victim == nil then
		return false, "No valid pin target"
	end
	if victim:GetState() ~= "Grounded" then
		return false, "Target is not grounded"
	end
	if not pinner:CanSetState("Pinning") or not victim:CanSetState("Pinned") then
		return false, "Pin state transition rejected"
	end

	if not self._budget:Commit(player, pinner, "Pin") then
		return false, "Action resources changed before commit"
	end
	pinner:SetState("Pinning")
	victim:SetState("Pinned")
	self._pins:Start(player, targetPlayer)
	return true, nil
end

function CombatCoordinator:RequestAction(player: Player, action: CombatAction): (boolean, string?)
	if action == "Grapple" or action == "RunningGrapple" then
		return false, "Grapples require a direction"
	elseif action == "Pin" then
		return self:RequestPin(player)
	elseif action == "Dash" then
		local combatant, reason = self:_validateBase(player, action)
		if combatant == nil then
			return false, reason
		end
		if not combatant:CanSetState("Running") then
			return false, "State transition rejected"
		end
		if not self._budget:Commit(player, combatant, action) then
			return false, "Action resources changed before commit"
		end
		combatant:SetState("Running")
		CharacterAdapter.ApplyBackwardVelocity(combatant.Character, CombatConfig.Movement.DashBackwardSpeed)
		self._emitAction(player, {
			Action = "Dash",
			AttackerUserId = player.UserId,
		})
		self._recovery:ScheduleState(combatant, "Running", "Roaming", 0.25)
		return true, nil
	end

	return self:_requestStrike(player, action)
end

function CombatCoordinator:TryReverse(player: Player, sessionId: string): boolean
	return self._grapples:TryReverse(player, sessionId)
end

function CombatCoordinator:SubmitPinInput(player: Player, sessionId: string): boolean
	return self._pins:SubmitInput(player, sessionId)
end

function CombatCoordinator:ApplyWeaponAttack(player: Player, damage: DamageSpec, weaponId: string): boolean
	if not self._matchSource:IsMatchActiveFor(player) then
		return false
	end

	local attacker = self._combatants[player]
	if attacker == nil then
		return false
	end
	local attackerState = attacker:GetState()
	if attackerState ~= "Roaming" and attackerState ~= "Running" then
		return false
	end

	return self._strikes:ApplyWeaponAttack(player, attacker, damage, weaponId)
end

function CombatCoordinator:ResetForMatchEnd(players: { Player })
	for _, player in players do
		self._grapples:CancelForPlayer(player)
		self._pins:CancelForPlayer(player)
		self._budget:Forget(player)

		local combatant = self._combatants[player]
		if combatant ~= nil then
			self._recovery:Invalidate(combatant)
			combatant:ResetForMatchEnd()
			CharacterAdapter.SetMovementEnabled(combatant.Character, true)
		end
		self._reportedDeaths[player] = false
	end
end

function CombatCoordinator:Destroy()
	for player in self._combatants do
		self:_removeCombatant(player)
	end
	table.clear(self._reportedDeaths)
	self._trove:Destroy()
end

return CombatCoordinator
