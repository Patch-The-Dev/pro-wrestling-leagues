--!strict

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EntranceConfig = require(ReplicatedStorage.Shared.Config.EntranceConfig)
local Promise = require(ReplicatedStorage.Packages.Promise)
local Trove = require(ReplicatedStorage.Packages.Trove)

type LightingSnapshot = {
	Brightness: number,
	ClockTime: number,
	Ambient: Color3,
	OutdoorAmbient: Color3,
}

local LightingSystem = {}
LightingSystem.__index = LightingSystem

export type LightingSystem = typeof(setmetatable(
	{} :: {
		_trove: typeof(Trove.new()),
		_generation: number,
		_baseline: LightingSnapshot?,
	},
	LightingSystem
))

local function snapshot(): LightingSnapshot
	return {
		Brightness = Lighting.Brightness,
		ClockTime = Lighting.ClockTime,
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
	}
end

local function apply(values: LightingSnapshot)
	Lighting.Brightness = values.Brightness
	Lighting.ClockTime = values.ClockTime
	Lighting.Ambient = values.Ambient
	Lighting.OutdoorAmbient = values.OutdoorAmbient
end

function LightingSystem.new(): LightingSystem
	return setmetatable({
		_trove = Trove.new(),
		_generation = 0,
		_baseline = nil :: LightingSnapshot?,
	}, LightingSystem)
end

function LightingSystem:_restore()
	local baseline = self._baseline
	self._baseline = nil
	if baseline ~= nil then
		apply(baseline)
	end
end

function LightingSystem:PlayPreset(presetName: string, duration: number)
	local preset = EntranceConfig.LightingPresets[presetName]
	if preset == nil then
		return Promise.resolve()
	end

	if self._baseline == nil then
		self._baseline = snapshot()
	end

	self._generation += 1
	local generation = self._generation
	apply(preset)

	local promise = Promise.delay(math.max(0, duration)):andThen(function()
		if generation == self._generation then
			self:_restore()
		end
	end)
	self._trove:AddPromise(promise)
	return promise
end

function LightingSystem:Stop()
	self._generation += 1
	self:_restore()
end

function LightingSystem:Destroy()
	self:Stop()
	self._trove:Destroy()
end

return LightingSystem
