--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)

type PlayerData = PlayerDataTypes.PlayerData

local DataController = Knit.CreateController({
	Name = "DataController",
})

function DataController:KnitInit()
	self._trove = Trove.new()
	self._snapshot = nil :: PlayerData?
	self.Changed = Signal.new()
	self._trove:Add(self.Changed)
end

function DataController:_refresh()
	return self._dataService:GetSnapshot():andThen(function(snapshot: PlayerData?)
		self._snapshot = snapshot
		self.Changed:Fire(snapshot)
		return snapshot
	end)
end

function DataController:KnitStart()
	self._dataService = Knit.GetService("DataService")
	self._trove:Connect(self._dataService.ProfileLoaded, function()
		self:_refresh()
	end)
	self:_refresh():catch(function()
		-- ProfileLoaded will retry once the server session is ready.
	end)
end

function DataController:GetSnapshot(): PlayerData?
	return self._snapshot
end

function DataController:Refresh()
	return self:_refresh()
end

return DataController
