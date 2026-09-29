--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local PlayerDataSnapshot = require(ReplicatedStorage.Shared.Util.PlayerDataSnapshot)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local PlayerDeparture = require(script.Parent.Parent.Persistence.PlayerDeparture)
local PlayerRepository = require(script.Parent.Parent.Persistence.PlayerRepository)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)

type PlayerData = PlayerDataTypes.PlayerData

local DataService = Knit.CreateService({
	Name = "DataService",
	Client = {
		ProfileLoaded = Knit.CreateSignal(),
	},
})

function DataService:KnitInit()
	self._trove = Trove.new()
	self._repository = PlayerRepository.new()
	self._departure = PlayerDeparture.new(self._repository)
	self._trove:Add(self._departure)
	self._closing = false
	self._loading = {}
	self.Loaded = Signal.new()
	self._trove:Add(self.Loaded)
end

function DataService:_loadPlayer(player: Player)
	if self._closing or self._loading[player] ~= nil or self._repository:IsLoaded(player) then
		return
	end

	local promise = self._repository:LoadAsync(player)
	self._loading[player] = promise

	promise
		:andThen(function()
			self._loading[player] = nil
			if self._closing then
				self._departure:Release(player)
			elseif player.Parent == Players then
				self.Loaded:Fire(player)
				self.Client.ProfileLoaded:Fire(player)
			end
		end)
		:catch(function(err)
			self._loading[player] = nil
			warn(`Failed to load player data for {player.UserId}: {tostring(err)}`)
			if player.Parent == Players then
				player:Kick("Your player data could not be loaded. Please reconnect.")
			end
		end)
end

function DataService:KnitStart()
	self._requestGate = Knit.GetService("RequestGateService")
	self._trove:Connect(Players.PlayerAdded, function(player)
		self:_loadPlayer(player)
	end)

	self._trove:Connect(Players.PlayerRemoving, function(player)
		self._loading[player] = nil
		self._departure:Release(player)
	end)

	for _, player in Players:GetPlayers() do
		self:_loadPlayer(player)
	end

	game:BindToClose(function()
		self._closing = true
		self._departure:ReleaseAll()
	end)
end

function DataService:SetBeforeRelease(callback: (Player) -> ())
	self._departure:SetBeforeRelease(callback)
end

function DataService:Get(player: Player): PlayerData?
	return self._repository:Get(player)
end

function DataService:IsLoaded(player: Player): boolean
	return self._repository:IsLoaded(player)
end

function DataService:Update(player: Player, mutator: (data: PlayerData) -> ()): boolean
	return self._repository:Update(player, mutator)
end

function DataService:GetSnapshot(player: Player): PlayerData?
	local data = self:Get(player)
	return if data ~= nil then PlayerDataSnapshot.Clone(data) else nil
end

function DataService.Client:GetSnapshot(player: Player)
	if not self.Server._requestGate:Allow(player, "Data") then
		return nil
	end
	return self.Server:GetSnapshot(player)
end

return DataService
