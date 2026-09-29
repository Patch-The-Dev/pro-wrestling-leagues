--!strict

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local MatchCoordinatorModule = require(script.Parent.Parent.Application.MatchCoordinator)
local MatchTypes = require(ReplicatedStorage.Shared.Types.MatchTypes)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)

type MatchCoordinator = MatchCoordinatorModule.MatchCoordinator
type MatchEndReason = MatchTypes.MatchEndReason
type MatchResult = MatchTypes.MatchResult

local function recordMatchOutcome(players: { Player }, result: MatchResult)
	if RunService:IsStudio() then
		return
	end

	for _, player in players do
		if player.Parent ~= Players then
			continue
		end

		local outcome = if result.WinnerUserId == player.UserId
			then "Win"
			elseif result.LoserUserId == player.UserId then "Loss"
			else "Draw"
		local success, message = pcall(function()
			AnalyticsService:LogCustomEvent(
				player,
				"ProWrestlingLeaguesMatchOutcome",
				math.max(0, result.DurationSeconds),
				{
					Outcome = outcome,
					Reason = result.Reason,
				}
			)
		end)
		if not success then
			warn(`Match outcome analytics failed for user {player.UserId}: {tostring(message)}`)
		end
	end
end

local MatchService = Knit.CreateService({
	Name = "MatchService",
	Client = {
		QueueChanged = Knit.CreateSignal(),
		MatchChanged = Knit.CreateSignal(),
	},
})

function MatchService:KnitInit()
	self._trove = Trove.new()
	self._coordinator = nil :: MatchCoordinator?
	self.SessionClosed = Signal.new()
	self._trove:Add(self.SessionClosed)
end

function MatchService:KnitStart()
	self._requestGate = Knit.GetService("RequestGateService")
	local dataService = Knit.GetService("DataService")
	local economyService = Knit.GetService("EconomyService")
	local entranceService = Knit.GetService("EntranceService")

	local coordinator = MatchCoordinatorModule.new({
		DataSource = dataService,
		EconomySource = economyService,
		EntranceSource = entranceService,
		EmitQueueChanged = function(player, queued)
			self.Client.QueueChanged:Fire(player, queued)
		end,
		EmitMatchChanged = function(player, update)
			self.Client.MatchChanged:Fire(player, update)
		end,
		OnSessionClosed = function(players, result)
			self.SessionClosed:Fire(players, result)
			task.defer(recordMatchOutcome, players, result)
		end,
	})
	self._coordinator = coordinator
	self._trove:Add(coordinator)
	dataService:SetBeforeRelease(function(player)
		coordinator:HandlePlayerRemoving(player)
	end)
end

function MatchService:_getCoordinator(): MatchCoordinator
	local coordinator = self._coordinator
	assert(coordinator ~= nil, "MatchService has not started")
	return coordinator
end

function MatchService:JoinQueue(player: Player): (boolean, string?)
	return self:_getCoordinator():JoinQueue(player)
end

function MatchService:LeaveQueue(player: Player)
	self:_getCoordinator():LeaveQueue(player)
end

function MatchService:GetOpponents(player: Player): { Player }
	return self:_getCoordinator():GetOpponents(player)
end

function MatchService:IsMatchActiveFor(player: Player): boolean
	return self:_getCoordinator():IsMatchActiveFor(player)
end

function MatchService:IsInstanceInPlayerArena(player: Player, instance: Instance): boolean
	return self:_getCoordinator():IsInstanceInPlayerArena(player, instance)
end

function MatchService:FinishForKnockout(loser: Player)
	self:_getCoordinator():FinishForKnockout(loser)
end

function MatchService:FinishMatch(winner: Player?, loser: Player?, reason: MatchEndReason): boolean
	return self:_getCoordinator():FinishMatch(winner, loser, reason)
end

function MatchService:VoteToEnd(player: Player): boolean
	return self:_getCoordinator():VoteToEnd(player)
end

function MatchService.Client:JoinQueue(player: Player)
	if not self.Server._requestGate:Allow(player, "Interaction") then
		return false, "Too many requests"
	end
	return self.Server:JoinQueue(player)
end

function MatchService.Client:LeaveQueue(player: Player)
	if not self.Server._requestGate:Allow(player, "Interaction") then
		return false
	end
	self.Server:LeaveQueue(player)
	return true
end

function MatchService.Client:VoteToEnd(player: Player)
	if not self.Server._requestGate:Allow(player, "Interaction") then
		return false
	end
	return self.Server:VoteToEnd(player)
end

return MatchService
