--!strict

local PersistenceConfig = {
	StoreName = "PWL_PlayerData_v2",
	UseMockStoreInStudio = true,
	SettlementStoreName = "ProWrestlingLeaguesSettlements_v1",
	SaveConfirmationSeconds = 12,
}

table.freeze(PersistenceConfig)

return PersistenceConfig
