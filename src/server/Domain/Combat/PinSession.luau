--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.Config.CombatConfig)
local Promise = require(ReplicatedStorage.Packages.Promise)
local Trove = require(ReplicatedStorage.Packages.Trove)

local PinSession = {}
PinSession.__index = PinSession

export type PinSession = typeof(setmetatable(
	{} :: {
		Id: string,
		Pinner: Player,
		Victim: Player,
		_trove: typeof(Trove.new()),
		_promptIndex: number,
		_targetTime: number?,
		_latencyAllowanceSeconds: number,
		_misses: number,
		_finished: boolean,
		_escaped: boolean,
	},
	{} :: typeof(PinSession)
))

function PinSession.new(
	id: string,
	pinner: Player,
	victim: Player,
	latencyAllowanceSeconds: number?
): PinSession
	return setmetatable({
		Id = id,
		Pinner = pinner,
		Victim = victim,
		_trove = Trove.new(),
		_promptIndex = 0,
		_targetTime = nil,
		_latencyAllowanceSeconds = math.clamp(
			latencyAllowanceSeconds or 0,
			0,
			CombatConfig.Pin.MaximumOneWayLatencyCompensationSeconds
		),
		_misses = 0,
		_finished = false,
		_escaped = false,
	}, PinSession)
end

function PinSession:NextPrompt(): number?
	if self._finished then
		return nil
	end

	self._promptIndex += 1
	local delays = {
		CombatConfig.Pin.FirstPromptDelay,
		CombatConfig.Pin.SecondPromptDelay,
		CombatConfig.Pin.ThirdPromptDelay,
	}

	local delaySeconds = delays[self._promptIndex]
	if delaySeconds == nil then
		self._finished = true
		return nil
	end

	self._targetTime = workspace:GetServerTimeNow() + delaySeconds
	return self._targetTime
end

function PinSession:SubmitInput(player: Player): boolean
	if self._finished or player ~= self.Victim or self._targetTime == nil then
		return false
	end

	local arrivalOffset = workspace:GetServerTimeNow() - self._targetTime
	if
		arrivalOffset < -CombatConfig.Pin.InputWindowSeconds
		or arrivalOffset > CombatConfig.Pin.InputWindowSeconds + self._latencyAllowanceSeconds
	then
		return false
	end

	self._escaped = true
	self._finished = true
	self._targetTime = nil
	return true
end

function PinSession:ExpirePrompt()
	if self._finished or self._targetTime == nil then
		return
	end

	self._targetTime = nil
	self._misses += 1
	if self._misses >= CombatConfig.Pin.MaximumMisses then
		self._finished = true
	end
end

function PinSession:AwaitPromptExpiry()
	if self._targetTime == nil then
		return Promise.reject("Pin prompt has not been scheduled")
	end

	local delaySeconds = math.max(
		0,
		self._targetTime
			- workspace:GetServerTimeNow()
			+ CombatConfig.Pin.InputWindowSeconds
			+ self._latencyAllowanceSeconds
	)
	local timer = Promise.delay(delaySeconds)
	self._trove:AddPromise(timer)
	return timer
end

function PinSession:IsFinished(): boolean
	return self._finished
end

function PinSession:DidEscape(): boolean
	return self._escaped
end

function PinSession:GetMisses(): number
	return self._misses
end

function PinSession:Destroy()
	self._trove:Destroy()
end

return PinSession
