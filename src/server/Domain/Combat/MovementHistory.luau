--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.Config.CombatConfig)

type Sample = {
	Position: Vector3,
	Time: number,
	HorizontalSpeed: number,
	BlockedUntil: number,
}

local MovementHistory = {}
MovementHistory.__index = MovementHistory

local function isImplausibleTravel(offset: Vector3, elapsed: number): boolean
	local horizontalDistance = Vector3.new(offset.X, 0, offset.Z).Magnitude
	if
		horizontalDistance
		> CombatConfig.Movement.MaximumPlausibleSpeed * elapsed
			+ CombatConfig.Movement.PositionSlackStuds
	then
		return true
	end

	local verticalSpeed = if offset.Y >= 0
		then CombatConfig.Movement.MaximumPlausibleAscentSpeed
		else CombatConfig.Movement.MaximumPlausibleDescentSpeed
	return math.abs(offset.Y)
		> verticalSpeed * elapsed + CombatConfig.Movement.VerticalPositionSlackStuds
end

export type MovementHistory = typeof(setmetatable(
	{} :: {
		_samples: { [Player]: Sample },
	},
	{} :: typeof(MovementHistory)
))

function MovementHistory.new(): MovementHistory
	return setmetatable({ _samples = {} }, MovementHistory)
end

function MovementHistory:Observe(player: Player, position: Vector3, now: number)
	local sample = self._samples[player]
	if sample == nil then
		self._samples[player] = {
			Position = position,
			Time = now,
			HorizontalSpeed = 0,
			BlockedUntil = 0,
		}
		return
	end

	local elapsed = now - sample.Time
	if elapsed <= 0 then
		return
	end
	if elapsed < CombatConfig.Movement.SampleIntervalSeconds then
		if isImplausibleTravel(position - sample.Position, elapsed) then
			sample.BlockedUntil = now + CombatConfig.Movement.SuspiciousMovementLockSeconds
		end
		return
	end

	local offset = position - sample.Position
	local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
	if isImplausibleTravel(offset, elapsed) then
		sample.BlockedUntil = now + CombatConfig.Movement.SuspiciousMovementLockSeconds
	end

	sample.HorizontalSpeed = distance / elapsed
	sample.Position = position
	sample.Time = now
end

function MovementHistory:IsPlausible(player: Player, now: number): boolean
	local sample = self._samples[player]
	return sample ~= nil and now >= sample.BlockedUntil and now - sample.Time <= 0.5
end

function MovementHistory:IsRunning(player: Player, velocity: Vector3, now: number): boolean
	if not self:IsPlausible(player, now) then
		return false
	end
	local sample = self._samples[player]
	if sample == nil then
		return false
	end
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	return speed >= CombatConfig.Movement.RunningSpeedThreshold
		and speed <= CombatConfig.Movement.MaximumPlausibleSpeed
		and sample.HorizontalSpeed >= CombatConfig.Movement.RunningSpeedThreshold * 0.5
		and sample.HorizontalSpeed <= CombatConfig.Movement.MaximumPlausibleSpeed
end

function MovementHistory:Forget(player: Player)
	self._samples[player] = nil
end

function MovementHistory:Destroy()
	table.clear(self._samples)
end

return MovementHistory
