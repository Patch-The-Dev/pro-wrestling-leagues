--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Promise = require(ReplicatedStorage.Packages.Promise)
local Trove = require(ReplicatedStorage.Packages.Trove)
local CombatConfig = require(ReplicatedStorage.Shared.Config.CombatConfig)

local GrappleSession = {}
GrappleSession.__index = GrappleSession

export type GrappleSession = typeof(setmetatable(
	{} :: {
		Id: string,
		Initiator: Player,
		Victim: Player,
		_trove: typeof(Trove.new()),
		_resolved: boolean,
		_reversed: boolean,
		_startedAt: number,
	},
	{} :: typeof(GrappleSession)
))

function GrappleSession.new(id: string, initiator: Player, victim: Player): GrappleSession
	return setmetatable({
		Id = id,
		Initiator = initiator,
		Victim = victim,
		_trove = Trove.new(),
		_resolved = false,
		_reversed = false,
		_startedAt = workspace:GetServerTimeNow(),
	}, GrappleSession)
end

function GrappleSession:CanReverse(player: Player): boolean
	if self._resolved or player ~= self.Victim then
		return false
	end

	return workspace:GetServerTimeNow() - self._startedAt <= CombatConfig.Reversal.WindowSeconds
end

function GrappleSession:TryReverse(player: Player): boolean
	if not self:CanReverse(player) then
		return false
	end

	self._reversed = true
	self._resolved = true
	return true
end

function GrappleSession:AwaitResolution()
	local timer = Promise.delay(CombatConfig.Reversal.WindowSeconds):andThen(function()
		if not self._resolved then
			self._resolved = true
		end

		return self._reversed
	end)

	self._trove:AddPromise(timer)
	return timer
end

function GrappleSession:IsResolved(): boolean
	return self._resolved
end

function GrappleSession:Destroy()
	self._trove:Destroy()
end

return GrappleSession
