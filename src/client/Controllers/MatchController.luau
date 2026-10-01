--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(script.Parent.Parent.KnitClient)
local NetworkTypes = require(ReplicatedStorage.Shared.Types.NetworkTypes)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Shared.Util.Cleanup)

type MatchUpdate = NetworkTypes.MatchUpdate

local MatchController = Knit.CreateController({
	Name = "MatchController",
})

function MatchController:KnitInit()
	self._trove = Trove.new()
	self._match = nil :: MatchUpdate?
	self.Changed = Signal.new()
	self._trove:Add(self.Changed)
end

function MatchController:KnitStart()
	self._matchService = Knit.GetService("MatchService")
	self._trove:Add(self._matchService.MatchChanged:Connect(function(snapshot)
		self._match = snapshot
		self.Changed:Fire(snapshot)
	end))
end

function MatchController:JoinQueue()
	return self._matchService:JoinQueue()
end

function MatchController:LeaveQueue()
	return self._matchService:LeaveQueue()
end

function MatchController:VoteToEnd()
	return self._matchService:VoteToEnd()
end

function MatchController:GetMatch(): MatchUpdate?
	return self._match
end

return MatchController
