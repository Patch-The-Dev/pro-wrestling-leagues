--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.Config.CombatConfig)
local CombatTypes = require(ReplicatedStorage.Shared.Types.CombatTypes)
local CombatantModule = require(script.Parent.Combatant)
local Promise = require(ReplicatedStorage.Packages.Promise)
local Trove = require(ReplicatedStorage.Packages.Trove)

type CombatState = CombatTypes.CombatState
type Combatant = CombatantModule.Combatant

type GetCombatant = (player: Player) -> Combatant?

local RecoveryScheduler = {}
RecoveryScheduler.__index = RecoveryScheduler

export type RecoveryScheduler = typeof(setmetatable(
	{} :: {
		_trove: typeof(Trove.new()),
		_getCombatant: GetCombatant,
		_generations: { [Combatant]: number },
	},
	{} :: typeof(RecoveryScheduler)
))

function RecoveryScheduler.new(getCombatant: GetCombatant): RecoveryScheduler
	return setmetatable({
		_trove = Trove.new(),
		_getCombatant = getCombatant,
		_generations = {},
	}, RecoveryScheduler)
end

function RecoveryScheduler:_nextGeneration(combatant: Combatant): number
	local generation = (self._generations[combatant] or 0) + 1
	self._generations[combatant] = generation
	return generation
end

function RecoveryScheduler:_isCurrent(combatant: Combatant, generation: number): boolean
	return self._generations[combatant] == generation
		and self._getCombatant(combatant.Player) == combatant
end

function RecoveryScheduler:ScheduleState(
	combatant: Combatant,
	expectedState: CombatState,
	nextState: CombatState,
	delaySeconds: number
)
	local generation = self:_nextGeneration(combatant)
	local promise = Promise.delay(math.max(0, delaySeconds)):andThen(function()
		if not self:_isCurrent(combatant, generation) then
			return
		end
		if combatant:GetState() == expectedState then
			combatant:SetState(nextState)
		end
	end)
	self._trove:AddPromise(promise)
	return promise
end

function RecoveryScheduler:ScheduleVictim(combatant: Combatant, stunSeconds: number)
	local state = combatant:GetState()
	if state == "Stunned" then
		self:ScheduleState(combatant, "Stunned", "Roaming", math.max(0.1, stunSeconds))
	elseif state == "Grounded" then
		local generation = self:_nextGeneration(combatant)
		local promise = Promise.delay(CombatConfig.GroundedSeconds):andThen(function()
			if not self:_isCurrent(combatant, generation) or combatant:GetState() ~= "Grounded" then
				return
			end
			if combatant:SetState("StandingUp") then
				self:ScheduleState(combatant, "StandingUp", "Roaming", 0.65)
			end
		end)
		self._trove:AddPromise(promise)
	end
end

function RecoveryScheduler:Invalidate(combatant: Combatant)
	self:_nextGeneration(combatant)
end

function RecoveryScheduler:Forget(combatant: Combatant)
	-- Removed combatants are never reused, so clearing the generation is safe once
	-- the owning coordinator has detached the object. Persistent combatants should
	-- use Invalidate so stale timers can never collide with a later generation.
	self._generations[combatant] = nil
end

function RecoveryScheduler:Destroy()
	table.clear(self._generations)
	self._trove:Destroy()
end

return RecoveryScheduler
