--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local Contracts = require(ReplicatedStorage.Shared.Network.Contracts)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local RewardPolicy = require(script.Parent.Parent.Domain.Economy.RewardPolicy)

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

function EconomyService:ApplyMatchReward(player: Player, didWin: boolean): boolean
	local reward = RewardPolicy.ForMatchOutcome(didWin)
	local updated = self._dataService:Update(player, function(data)
		data.Currencies.Cash += reward.Cash
		data.Currencies.Tickets += reward.Tickets
		data.Progression.Experience += reward.Experience
		data.Progression.Fame += reward.Fame

		if didWin then
			data.Statistics.Wins += 1
		else
			data.Statistics.Losses += 1
		end
	end)

	if updated then
		self:_publishBalance(player)
	end
	return updated
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
