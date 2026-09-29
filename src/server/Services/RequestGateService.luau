--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Trove = require(ReplicatedStorage.Packages.Trove)
local RequestGuardModule = require(script.Parent.Parent.Networking.RequestGuard)

local RequestGateService = Knit.CreateService({
	Name = "RequestGateService",
	Client = {},
})

function RequestGateService:KnitInit()
	self._trove = Trove.new()
	self._guard = RequestGuardModule.new()
end

function RequestGateService:KnitStart()
	self._trove:Connect(Players.PlayerRemoving, function(player)
		self._guard:Forget(player)
	end)
end

function RequestGateService:Allow(player: Player, channel: RequestGuardModule.Channel): boolean
	return self._guard:Allow(player, channel)
end

return RequestGateService
