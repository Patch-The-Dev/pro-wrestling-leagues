--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)

type StateChangedSignal = typeof(Signal.new())

local StateMachine = {}
StateMachine.__index = StateMachine

export type StateMachine = typeof(setmetatable(
	{} :: {
		_state: string,
		_allowed: { [string]: { [string]: boolean } },
		Changed: StateChangedSignal,
	},
	StateMachine
))

function StateMachine.new(
	initialState: string,
	allowedTransitions: { [string]: { [string]: boolean } }
): StateMachine
	return setmetatable({
		_state = initialState,
		_allowed = allowedTransitions,
		Changed = Signal.new(),
	}, StateMachine)
end

function StateMachine.Get(self: StateMachine): string
	return self._state
end

function StateMachine.CanTransition(self: StateMachine, nextState: string): boolean
	if nextState == self._state then
		return true
	end

	local fromState = self._allowed[self._state]
	return fromState ~= nil and fromState[nextState] == true
end

function StateMachine.Transition(self: StateMachine, nextState: string): boolean
	if not self:CanTransition(nextState) then
		return false
	end
	if nextState == self._state then
		return true
	end

	local previousState = self._state
	self._state = nextState
	self.Changed:Fire(nextState, previousState)
	return true
end

function StateMachine.Destroy(self: StateMachine)
	self.Changed:Destroy()
end

return StateMachine
