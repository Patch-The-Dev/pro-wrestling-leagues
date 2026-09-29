--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)

type CurrencyName = PlayerDataTypes.CurrencyName

type ShopItem = {
	Currency: CurrencyName,
	Price: number,
	UnlockId: string,
}

local EconomyConfig = {
	MatchRewards = {
		Win = {
			Cash = 250,
			Tickets = 2,
			Experience = 125,
			Fame = 20,
		},
		Loss = {
			Cash = 100,
			Tickets = 0,
			Experience = 60,
			Fame = 5,
		},
	},

	Shop = {
		["move:spinebuster"] = { Currency = "Cash", Price = 850, UnlockId = "Spinebuster" } :: ShopItem,
		["move:piledriver"] = { Currency = "Cash", Price = 1200, UnlockId = "Piledriver" } :: ShopItem,
		["move:spear3"] = { Currency = "Tickets", Price = 10, UnlockId = "Spear 3" } :: ShopItem,
	},
}

table.freeze(EconomyConfig.MatchRewards.Win)
table.freeze(EconomyConfig.MatchRewards.Loss)
table.freeze(EconomyConfig.MatchRewards)

for _, item in EconomyConfig.Shop do
	table.freeze(item)
end

table.freeze(EconomyConfig.Shop)
table.freeze(EconomyConfig)

return EconomyConfig
