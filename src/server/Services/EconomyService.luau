--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Contracts = require(ReplicatedStorage.Shared.Network.Contracts)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local Journal = require(script.Parent.Parent.Persistence.MatchSettlementJournal)
local Knit = require(ReplicatedStorage.Packages.Knit)
local MatchConfig = require(ReplicatedStorage.Shared.Config.MatchConfig)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local RewardPolicy = require(script.Parent.Parent.Domain.Economy.RewardPolicy)
local SettlementStore = require(script.Parent.Parent.Persistence.SettlementStore)
local SettlementTypes = require(script.Parent.Parent.Persistence.SettlementTypes)

type CurrencyName = PlayerDataTypes.CurrencyName

local EconomyService = Knit.CreateService({
	Name = "EconomyService",
	Client = {
		BalanceChanged = Knit.CreateSignal(),
		PurchaseCompleted = Knit.CreateSignal(),
	},
})

local function getBalance(data: PlayerDataTypes.PlayerData, currency: CurrencyName): number
	return if currency == "Cash" then data.Currencies.Cash else data.Currencies.Tickets
end

local function setBalance(data: PlayerDataTypes.PlayerData, currency: CurrencyName, balance: number)
	if currency == "Cash" then
		data.Currencies.Cash = balance
	else
		data.Currencies.Tickets = balance
	end
end

function EconomyService:KnitStart()
	self._dataService = Knit.GetService("DataService")
	self._requestGate = Knit.GetService("RequestGateService")
	self._journal = Journal.new(
		SettlementStore.new(),
		function(userId, opponentId, sequence, matchId, didWin, reward)
			local saved = self._dataService:ApplySettlementAsync(
				userId,
				opponentId,
				sequence,
				matchId,
				didWin,
				reward
			)
			local player = Players:GetPlayerByUserId(userId)
			if saved and player ~= nil then
				local published, publishError = pcall(function()
					self:_publishBalance(player)
					return true
				end)
				if not published then
					warn(`Match balance notification failed: {tostring(publishError)}`)
				end
			end
			return saved
		end,
		function(winnerId, loserId)
			local winner = Players:GetPlayerByUserId(winnerId)
			local loser = Players:GetPlayerByUserId(loserId)
			return (winner ~= nil and self._dataService:IsLoaded(winner))
				or (loser ~= nil and self._dataService:IsLoaded(loser))
		end
	)
	self._closing = false
	game:BindToClose(function()
		self._closing = true
	end)
	task.spawn(function()
		while not self._closing do
			self._journal:ScanPage()
			task.wait(MatchConfig.SettlementScanSeconds)
		end
	end)
end

function EconomyService:RecordMatchResult(
	winner: Player,
	loser: Player,
	matchId: string,
	finishedAt: number
): boolean
	local result: SettlementTypes.Result = {
		MatchId = matchId,
		WinnerUserId = winner.UserId,
		LoserUserId = loser.UserId,
		FinishedAt = finishedAt,
		WinReward = RewardPolicy.ForMatchOutcome(true),
		LossReward = RewardPolicy.ForMatchOutcome(false),
	}
	if not self._journal:Record(result) then
		return false
	end
	task.defer(function()
		self._journal:Process(matchId)
	end)
	return true
end

function EconomyService:_publishBalance(player: Player)
	local data = self._dataService:Get(player)
	if data == nil then
		return
	end

	self.Client.BalanceChanged:Fire(player, {
		Cash = data.Currencies.Cash,
		Tickets = data.Currencies.Tickets,
		Experience = data.Progression.Experience,
		Fame = data.Progression.Fame,
	})
end

function EconomyService:Purchase(player: Player, itemId: string): (boolean, string?)
	local item = EconomyConfig.Shop[itemId]
	if item == nil then
		return false, "Unknown item"
	end

	local result = "Purchase failed"
	local succeeded = self._dataService:Update(player, function(data)
		if data.Unlocks.Moves[item.UnlockId] then
			result = "Already owned"
			return
		end

		local balance = getBalance(data, item.Currency)
		if balance < item.Price then
			result = "Insufficient funds"
			return
		end

		setBalance(data, item.Currency, balance - item.Price)
		data.Unlocks.Moves[item.UnlockId] = true
		result = "Purchased"
	end)

	if not succeeded or result ~= "Purchased" then
		return false, result
	end

	self:_publishBalance(player)
	self.Client.PurchaseCompleted:Fire(player, itemId)
	return true, nil
end

function EconomyService.Client:Purchase(player: Player, rawItemId: unknown)
	if not self.Server._requestGate:Allow(player, "Economy") then
		return false, "Too many requests"
	end
	if not Contracts.IsShopItemId(rawItemId) then
		return false, "Invalid request"
	end

	return self.Server:Purchase(player, rawItemId :: string)
end

return EconomyService
