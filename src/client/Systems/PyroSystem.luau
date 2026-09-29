--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EntranceConfig = require(ReplicatedStorage.Shared.Config.EntranceConfig)
local Promise = require(ReplicatedStorage.Packages.Promise)
local Trove = require(ReplicatedStorage.Packages.Trove)

local PyroSystem = {}
PyroSystem.__index = PyroSystem

export type PyroSystem = typeof(setmetatable(
	{} :: {
		_trove: typeof(Trove.new()),
		_generation: number,
		_activeEmitters: { ParticleEmitter },
	},
	PyroSystem
))

local function resolveArena(arenaId: string): Model?
	for _, instance in CollectionService:GetTagged("WrestlingArena") do
		if instance:IsA("Model") then
			local configuredId = instance:GetAttribute("ArenaId")
			local resolvedId = if type(configuredId) == "string" and configuredId ~= ""
				then configuredId
				else instance.Name
			if resolvedId == arenaId then
				return instance
			end
		end
	end
	return nil
end

local function collectEmitters(arena: Model): { ParticleEmitter }
	local emitters: { ParticleEmitter } = {}
	for _, root in CollectionService:GetTagged("EntrancePyro") do
		if not root:IsDescendantOf(arena) then
			continue
		end

		if root:IsA("ParticleEmitter") then
			table.insert(emitters, root)
		else
			for _, descendant in root:GetDescendants() do
				if descendant:IsA("ParticleEmitter") then
					table.insert(emitters, descendant)
				end
			end
		end
	end
	return emitters
end

function PyroSystem.new(): PyroSystem
	return setmetatable({
		_trove = Trove.new(),
		_generation = 0,
		_activeEmitters = {},
	}, PyroSystem)
end

function PyroSystem:_disableActive()
	for _, emitter in self._activeEmitters do
		if emitter.Parent ~= nil then
			emitter.Enabled = false
		end
	end
	table.clear(self._activeEmitters)
end

function PyroSystem:Play(presetName: string, arenaId: string?)
	self._generation += 1
	self:_disableActive()

	local preset = EntranceConfig.PyroPresets[presetName]
	if
		preset == nil
		or arenaId == nil
		or (preset.BurstCount <= 0 and preset.ContinuousSeconds <= 0)
	then
		return
	end

	local arena = resolveArena(arenaId)
	if arena == nil then
		return
	end

	local generation = self._generation
	local emitters = collectEmitters(arena)

	for _, emitter in emitters do
		if preset.BurstCount > 0 then
			emitter:Emit(preset.BurstCount)
		end
		if preset.ContinuousSeconds > 0 then
			emitter.Enabled = true
			table.insert(self._activeEmitters, emitter)
		end
	end

	if preset.ContinuousSeconds > 0 then
		local promise = Promise.delay(preset.ContinuousSeconds):andThen(function()
			if generation == self._generation then
				self:_disableActive()
			end
		end)
		self._trove:AddPromise(promise)
	end
end

function PyroSystem:Stop()
	self._generation += 1
	self:_disableActive()
end

function PyroSystem:Destroy()
	self:Stop()
	self._trove:Destroy()
end

return PyroSystem
