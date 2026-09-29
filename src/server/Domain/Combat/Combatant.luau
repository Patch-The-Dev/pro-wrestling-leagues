--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.Config.CombatConfig)
local CombatMovementModule = require(script.Parent.CombatMovement)
local CombatTypes = require(ReplicatedStorage.Shared.Types.CombatTypes)
local StateMachine = require(ReplicatedStorage.Shared.State.StateMachine)
local Trove = require(ReplicatedStorage.Packages.Trove)

type CombatState = CombatTypes.CombatState
type CombatSnapshot = CombatTypes.CombatSnapshot
type DamageSpec = CombatTypes.DamageSpec
type CombatMovement = CombatMovementModule.CombatMovement

local Combatant = {}
Combatant.__index = Combatant

export type Combatant = typeof(setmetatable(
	{} :: {
		Player: Player,
		Character: Model,
		Humanoid: Humanoid,
		_trove: typeof(Trove.new()),
		_stateMachine: StateMachine.StateMachine,
		_movement: CombatMovement,
		_health: number,
		_stamina: number,
		_poise: number,
		_finisher: number,
		_lastStaminaSpend: number,
		_replicationElapsed: number,
	},
	{} :: typeof(Combatant)
))

local ALLOWED_TRANSITIONS: { [string]: { [string]: boolean } } = {
	Roaming = {
		Running = true,
		Attacking = true,
		Grappling = true,
		PerformingMove = true,
		Taunting = true,
		ClimbingTurnbuckle = true,
		Pinning = true,
		Stunned = true,
		Grounded = true,
		Dead = true,
	},
	Running = {
		Roaming = true,
		Attacking = true,
		Grappling = true,
		PerformingMove = true,
		Stunned = true,
		Grounded = true,
		Dead = true,
	},
	Stunned = { Roaming = true, Grounded = true, PerformingMove = true, Dead = true },
	Grounded = { StandingUp = true, Pinned = true, Dead = true },
	Falling = { Grounded = true, Stunned = true, Roaming = true, Dead = true },
	ClimbingTurnbuckle = {
		SittingOnTurnbuckle = true,
		Falling = true,
		Roaming = true,
		Stunned = true,
		Grounded = true,
		Dead = true,
	},
	SittingOnTurnbuckle = {
		PerformingMove = true,
		Falling = true,
		Roaming = true,
		Stunned = true,
		Grounded = true,
		Dead = true,
	},
	Attacking = { Roaming = true, Stunned = true, Grounded = true, Dead = true },
	Grappling = {
		PerformingMove = true,
		Roaming = true,
		Stunned = true,
		Grounded = true,
		Dead = true,
	},
	PerformingMove = { Roaming = true, Grounded = true, Stunned = true, Dead = true },
	Taunting = { Roaming = true, Stunned = true, Grounded = true, Dead = true },
	StandingUp = { Roaming = true, Stunned = true, Grounded = true, Dead = true },
	Pinning = { Roaming = true, Stunned = true, Grounded = true, Dead = true },
	Pinned = { Grounded = true, StandingUp = true, Dead = true },
	Dead = {},
}

local function setAttributeIfChanged(character: Model, name: string, value: string | number)
	if character:GetAttribute(name) ~= value then
		character:SetAttribute(name, value)
	end
end

function Combatant.new(player: Player, character: Model): Combatant
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	assert(humanoid ~= nil, "Combatant character requires a Humanoid")

	local trove = Trove.new()
	local stateMachine = StateMachine.new("Roaming", ALLOWED_TRANSITIONS)
	local movement = CombatMovementModule.new(character, humanoid)

	local self = setmetatable({
		Player = player,
		Character = character,
		Humanoid = humanoid,
		_trove = trove,
		_stateMachine = stateMachine,
		_movement = movement,
		_health = CombatConfig.MaxHealth,
		_stamina = CombatConfig.MaxStamina,
		_poise = 0,
		_finisher = 0,
		_lastStaminaSpend = -math.huge,
		_replicationElapsed = 0,
	}, Combatant)

	humanoid.MaxHealth = CombatConfig.MaxHealth
	humanoid.Health = CombatConfig.MaxHealth

	trove:Add(stateMachine)
	trove:Add(movement)
	trove:Connect(stateMachine.Changed, function()
		self._movement:ApplyState(self:GetState())
		self:_replicateSnapshot()
	end)
	trove:Connect(humanoid.Died, function()
		self._health = 0
		self._stateMachine:Transition("Dead")
		self:_replicateSnapshot()
	end)

	self:_replicateSnapshot()
	return self
end

function Combatant:_replicateSnapshot()
	local snapshot = self:GetSnapshot()
	setAttributeIfChanged(self.Character, "CombatState", snapshot.State)
	setAttributeIfChanged(self.Character, "CombatHealth", snapshot.Health)
	setAttributeIfChanged(self.Character, "CombatStamina", snapshot.Stamina)
	setAttributeIfChanged(self.Character, "CombatPoise", snapshot.Poise)
	setAttributeIfChanged(self.Character, "CombatFinisher", snapshot.Finisher)
end

function Combatant:GetState(): CombatState
	return (self._stateMachine:Get() :: unknown) :: CombatState
end

function Combatant:CanSetState(nextState: CombatState): boolean
	return self._stateMachine:CanTransition(nextState)
end

function Combatant:SetState(nextState: CombatState): boolean
	return self._stateMachine:Transition(nextState)
end

function Combatant:GetSnapshot(): CombatSnapshot
	return {
		State = self:GetState(),
		Health = self._health,
		MaxHealth = CombatConfig.MaxHealth,
		Stamina = self._stamina,
		MaxStamina = CombatConfig.MaxStamina,
		Poise = self._poise,
		MaxPoise = CombatConfig.MaxPoise,
		Finisher = self._finisher,
		MaxFinisher = CombatConfig.MaxFinisher,
	}
end

function Combatant:CanSpendStamina(amount: number): boolean
	return amount >= 0 and self._stamina >= amount
end

function Combatant:SpendStamina(amount: number): boolean
	if not self:CanSpendStamina(amount) then
		return false
	end

	self._stamina -= amount
	self._lastStaminaSpend = os.clock()
	self:_replicateSnapshot()
	return true
end

function Combatant:RestoreStamina(amount: number)
	if amount <= 0 then
		return
	end

	self._stamina = math.clamp(self._stamina + amount, 0, CombatConfig.MaxStamina)
	self:_replicateSnapshot()
end

function Combatant:CanSpendFinisher(amount: number): boolean
	return amount >= 0 and self._finisher >= amount
end

function Combatant:SpendFinisher(amount: number): boolean
	if not self:CanSpendFinisher(amount) then
		return false
	end

	self._finisher -= amount
	self:_replicateSnapshot()
	return true
end

function Combatant:RestoreFinisher(amount: number)
	if amount <= 0 then
		return
	end

	self._finisher = math.clamp(self._finisher + amount, 0, CombatConfig.MaxFinisher)
	self:_replicateSnapshot()
end

function Combatant:AddFinisher(amount: number)
	self:RestoreFinisher(amount)
end

function Combatant:ApplyDamage(spec: DamageSpec)
	if self:GetState() == "Dead" then
		return
	end

	self._health = math.max(0, self._health - spec.HealthDamage)
	self._poise = math.clamp(self._poise + spec.PoiseDamage, 0, CombatConfig.MaxPoise)
	self._finisher = math.clamp(self._finisher + spec.VictimFinisher, 0, CombatConfig.MaxFinisher)

	self.Humanoid.Health = self._health

	if self._health <= 0 then
		self:SetState("Dead")
	elseif self._poise >= CombatConfig.MaxPoise and self:SetState("Grounded") then
		self._poise = 0
	elseif
		spec.StunSeconds > 0
		and self:GetState() ~= "Grounded"
		and self:GetState() ~= "Pinned"
	then
		self:SetState("Stunned")
	end

	self:_replicateSnapshot()
end

function Combatant:Step(deltaTime: number)
	local state = self:GetState()
	if state == "Dead" then
		return
	end

	if os.clock() - self._lastStaminaSpend >= CombatConfig.StaminaRegenerationDelay then
		self._stamina = math.min(
			CombatConfig.MaxStamina,
			self._stamina + CombatConfig.StaminaRegenerationPerSecond * deltaTime
		)
	end

	if state == "Roaming" or state == "Running" then
		self._poise = math.max(0, self._poise - CombatConfig.PoiseRecoveryPerSecond * deltaTime)
	end

	self._replicationElapsed += deltaTime
	if self._replicationElapsed >= 0.1 then
		self._replicationElapsed = 0
		self:_replicateSnapshot()
	end
end

function Combatant:ResetForMatchEnd()
	if self:GetState() == "Dead" then
		return
	end

	self._health = CombatConfig.MaxHealth
	self._stamina = CombatConfig.MaxStamina
	self._poise = 0
	self._finisher = 0
	self._lastStaminaSpend = -math.huge

	local state = self:GetState()
	if state == "Pinned" or state == "Grounded" then
		if self:SetState("StandingUp") then
			self:SetState("Roaming")
		end
	elseif state ~= "Roaming" and self:CanSetState("Roaming") then
		self:SetState("Roaming")
	end

	self.Humanoid.Health = CombatConfig.MaxHealth
	self:_replicateSnapshot()
end

function Combatant:Destroy()
	self._trove:Destroy()
end

return Combatant
