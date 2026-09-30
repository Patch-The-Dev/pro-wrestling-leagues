--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)

type SpawnPoint = {
	Index: number,
	Name: string,
	CFrame: CFrame,
}

local ArenaRegistry = {}
ArenaRegistry.__index = ArenaRegistry

export type ArenaRegistry = typeof(setmetatable(
	{} :: {
		_arenas: { [string]: Model? },
		_reservations: { [string]: string },
		_trove: typeof(Trove.new()),
		Available: typeof(Signal.new()),
	},
	{} :: typeof(ArenaRegistry)
))

local function resolveArenaId(instance: Model): string
	local configuredId = instance:GetAttribute("ArenaId")
	return if type(configuredId) == "string" and configuredId ~= ""
		then configuredId
		else instance.Name
end

local function getRequiredPlayers(arena: Model): number?
	local value = arena:GetAttribute("RequiredPlayers")
	if type(value) ~= "number" then
		return nil
	end
	return math.max(1, math.floor(value))
end

function ArenaRegistry.new(): ArenaRegistry
	local self = setmetatable({
		_arenas = {} :: { [string]: Model? },
		_reservations = {},
		_trove = Trove.new(),
		Available = Signal.new(),
	}, ArenaRegistry)
	self._trove:Add(self.Available)

	for _, instance in CollectionService:GetTagged("WrestlingArena") do
		self:Add(instance)
	end

	self._trove:Connect(
		CollectionService:GetInstanceAddedSignal("WrestlingArena"),
		function(instance)
			self:Add(instance)
		end
	)
	self._trove:Connect(
		CollectionService:GetInstanceRemovedSignal("WrestlingArena"),
		function(instance)
			self:Remove(instance)
		end
	)

	return self
end

function ArenaRegistry.Add(self: ArenaRegistry, instance: Instance)
	if not instance:IsA("Model") then
		return
	end

	local arenaId = resolveArenaId(instance)
	local existing = self._arenas[arenaId]
	if existing ~= nil and existing ~= instance then
		warn(
			string.format(
				"Duplicate WrestlingArena id %q. Keeping the first registered arena.",
				arenaId
			)
		)
		return
	end

	self._arenas[arenaId] = instance
	if existing == nil then
		self.Available:Fire()
	end
end

function ArenaRegistry.Remove(self: ArenaRegistry, instance: Instance)
	for arenaId, arena in self._arenas do
		if arena == instance then
			self._arenas[arenaId] = nil
			self._reservations[arenaId] = nil
		end
	end
end

function ArenaRegistry:Get(arenaId: string): Model?
	return self._arenas[arenaId]
end

function ArenaRegistry.Contains(self: ArenaRegistry, arenaId: string, instance: Instance): boolean
	local arena = self:Get(arenaId)
	return arena ~= nil and (instance == arena or instance:IsDescendantOf(arena))
end

function ArenaRegistry:GetSpawnCFrames(arenaId: string): { CFrame }
	local arena = self:Get(arenaId)
	if arena == nil then
		return {}
	end

	local spawnFolder = arena:FindFirstChild("Spawns")
	if spawnFolder == nil then
		return {}
	end

	local spawnPoints: { SpawnPoint } = {}
	for _, child in spawnFolder:GetChildren() do
		if child:IsA("BasePart") then
			local configuredIndex = child:GetAttribute("SpawnIndex")
			local nameIndex = tonumber(child.Name)
			local index = if type(configuredIndex) == "number"
				then configuredIndex
				elseif nameIndex ~= nil then nameIndex
				else math.huge

			table.insert(spawnPoints, {
				Index = index,
				Name = child.Name,
				CFrame = child.CFrame,
			})
		end
	end

	table.sort(spawnPoints, function(a, b)
		if a.Index ~= b.Index then
			return a.Index < b.Index
		end
		return a.Name < b.Name
	end)

	local cframes: { CFrame } = table.create(#spawnPoints)
	for _, spawnPoint in spawnPoints do
		table.insert(cframes, spawnPoint.CFrame)
	end
	return cframes
end

function ArenaRegistry:_canHost(arenaId: string, playerCount: number): boolean
	local arena = self:Get(arenaId)
	if arena == nil or self._reservations[arenaId] ~= nil then
		return false
	end

	local requiredPlayers = getRequiredPlayers(arena)
	if requiredPlayers ~= nil and requiredPlayers ~= playerCount then
		return false
	end

	return #self:GetSpawnCFrames(arenaId) >= playerCount
end

function ArenaRegistry:Reserve(
	matchId: string,
	playerCount: number,
	preferredArenaId: string?
): string?
	if preferredArenaId ~= nil and self:_canHost(preferredArenaId, playerCount) then
		self._reservations[preferredArenaId] = matchId
		return preferredArenaId
	end

	local arenaIds: { string } = {}
	for arenaId in self._arenas do
		table.insert(arenaIds, arenaId)
	end
	table.sort(arenaIds)

	for _, arenaId in arenaIds do
		if self:_canHost(arenaId, playerCount) then
			self._reservations[arenaId] = matchId
			return arenaId
		end
	end

	return nil
end

function ArenaRegistry:Release(matchId: string)
	for arenaId, reservation in self._reservations do
		if reservation == matchId then
			self._reservations[arenaId] = nil
		end
	end
end

function ArenaRegistry:Destroy()
	self._trove:Destroy()
	table.clear(self._reservations)
	table.clear(self._arenas)
end

return ArenaRegistry
