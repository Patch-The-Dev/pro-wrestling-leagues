--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)
local Promise = require(ReplicatedStorage.Packages.Promise)

local MatchRewardLedger = require(script.Parent.Parent.Domain.Economy.MatchRewardLedger)
local PersistenceConfig = require(script.Parent.Parent.Config.PersistenceConfig)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local ProfileMigrations = require(script.Parent.ProfileMigrations)
local ProfileSanitizer = require(script.Parent.ProfileSanitizer)
local ProfileTemplate = require(script.Parent.ProfileTemplate)
local SettlementTypes = require(script.Parent.SettlementTypes)

type Dictionary = { [string]: unknown }
type PlayerData = PlayerDataTypes.PlayerData
type Connection = { Disconnect: (self: Connection) -> () }

type SessionEndSignal = {
	Connect: (self: SessionEndSignal, callback: () -> ()) -> Connection,
}

type Profile = {
	Data: Dictionary,
	LastSavedData: Dictionary,
	AddUserId: (self: Profile, userId: number) -> (),
	Reconcile: (self: Profile) -> (),
	IsActive: (self: Profile) -> boolean,
	EndSession: (self: Profile) -> (),
	OnSessionEnd: SessionEndSignal,
	OnAfterSave: { Connect: (self: unknown, callback: (Dictionary) -> ()) -> Connection },
	Save: (self: Profile) -> (),
}

type SessionOptions = {
	Cancel: () -> boolean,
}

export type ProfileStoreHandle = {
	Mock: ProfileStoreHandle,
	StartSessionAsync: (self: ProfileStoreHandle, key: string, options: SessionOptions) -> Profile?,
}

local PlayerRepository = {}
PlayerRepository.__index = PlayerRepository

export type PlayerRepository = typeof(setmetatable(
	{} :: {
		_store: ProfileStoreHandle,
		_profiles: { [Player]: Profile },
		_closing: boolean,
	},
	PlayerRepository
))

function PlayerRepository.new(injectedStore: ProfileStoreHandle?): PlayerRepository
	local store = injectedStore
		or (
			ProfileStore.New(PersistenceConfig.StoreName, ProfileTemplate) :: unknown
		) :: ProfileStoreHandle
	if
		injectedStore == nil
		and RunService:IsStudio()
		and PersistenceConfig.UseMockStoreInStudio
	then
		store = store.Mock
	end

	return setmetatable({
		_store = store,
		_profiles = {},
		_closing = false,
	}, PlayerRepository)
end

function PlayerRepository.LoadAsync(self: PlayerRepository, player: Player)
	if self._closing or self._profiles[player] ~= nil then
		return Promise.reject("Profile loading is unavailable")
	end
	return Promise.try(function()
		local profile = self._store:StartSessionAsync(`Player_{player.UserId}`, {
			Cancel = function()
				return self._closing or player.Parent ~= Players
			end,
		})

		if profile == nil then
			error(`Profile session could not be started for {player.UserId}`)
		end

		local initialized, initializationError = pcall(function()
			profile:AddUserId(player.UserId)
			ProfileMigrations.Apply(profile.Data)
			profile:Reconcile()
			ProfileSanitizer.Apply(profile.Data)
			if self._closing or player.Parent ~= Players or not profile:IsActive() then
				error("Player left while profile was loading")
			end
			profile.OnSessionEnd:Connect(function()
				if self._profiles[player] == profile then
					self._profiles[player] = nil
				end
				if not self._closing and player.Parent == Players then
					player:Kick("Your data session ended. Please reconnect.")
				end
			end)
			local data = (profile.Data :: unknown) :: PlayerData
			if data.Wrestler.DisplayName == "" then
				data.Wrestler.DisplayName = player.DisplayName
			end
		end)

		if not initialized then
			local released, releaseError = pcall(function()
				if profile:IsActive() then
					profile:EndSession()
				end
				return true
			end)
			if not released then
				warn(`Profile cleanup failed: {tostring(releaseError)}`)
			end
			error(initializationError)
		end
		local data = (profile.Data :: unknown) :: PlayerData
		self._profiles[player] = profile
		return data
	end)
end

function PlayerRepository.BeginClose(self: PlayerRepository)
	self._closing = true
end

function PlayerRepository.Get(self: PlayerRepository, player: Player): PlayerData?
	local profile = self._profiles[player]
	if profile == nil or not profile:IsActive() then
		return nil
	end

	return (profile.Data :: unknown) :: PlayerData
end

function PlayerRepository.Update(
	self: PlayerRepository,
	player: Player,
	mutator: (data: PlayerData) -> ()
): boolean
	local data = self:Get(player)
	if data == nil then
		return false
	end

	mutator(data)
	return true
end

function PlayerRepository.IsLoaded(self: PlayerRepository, player: Player): boolean
	return self:Get(player) ~= nil
end

function PlayerRepository.GetLoadedPlayers(self: PlayerRepository): { Player }
	local players: { Player } = {}
	for player in self._profiles do
		table.insert(players, player)
	end
	return players
end

function PlayerRepository.Release(self: PlayerRepository, player: Player)
	local profile = self._profiles[player]
	if profile == nil then
		return
	end

	self._profiles[player] = nil
	if profile:IsActive() then
		profile:EndSession()
	end
end

function PlayerRepository.ReleaseAll(self: PlayerRepository)
	for player in self._profiles do
		self:Release(player)
	end
end

function PlayerRepository.ApplySettlementAsync(
	self: PlayerRepository,
	userId: number,
	opponentId: number,
	sequence: number,
	matchId: string,
	didWin: boolean,
	reward: SettlementTypes.Reward
): boolean
	local player = Players:GetPlayerByUserId(userId)
	local profile = if player ~= nil then self._profiles[player] else nil
	if profile == nil or not profile:IsActive() then
		return false
	end
	local data = (profile.Data :: unknown) :: PlayerData
	if
		not MatchRewardLedger.ApplySettlement(data, opponentId, sequence, matchId, didWin, reward)
	then
		return false
	end
	local function isSaved(saved: Dictionary): boolean
		local sequences = saved.MatchRewardSequences
		return type(sequences) == "table"
			and (((sequences :: { [string]: number })[tostring(opponentId)] or 0) >= sequence)
	end
	if isSaved(profile.LastSavedData) then
		return true
	end
	local _, saved = Promise.new(function(resolve, _, onCancel)
		local settled = false
		local saveConnection: Connection?
		local endConnection: Connection?
		local timer: thread?
		local function settle(value: boolean)
			if settled then
				return
			end
			settled = true
			if saveConnection ~= nil then
				saveConnection:Disconnect()
			end
			if endConnection ~= nil then
				endConnection:Disconnect()
			end
			if timer ~= nil and timer ~= coroutine.running() then
				task.cancel(timer)
			end
			resolve(value)
		end
		saveConnection = profile.OnAfterSave:Connect(function(snapshot)
			if isSaved(snapshot) then
				settle(true)
			end
		end)
		endConnection = profile.OnSessionEnd:Connect(function()
			settle(false)
		end)
		onCancel(function()
			settle(false)
		end)
		timer = task.delay(PersistenceConfig.SaveConfirmationSeconds, function()
			settle(false)
		end)
		local started = pcall(profile.Save, profile)
		if not started then
			settle(false)
		end
	end):await()
	return saved == true
end

return PlayerRepository
