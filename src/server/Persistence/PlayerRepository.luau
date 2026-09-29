--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)
local Promise = require(ReplicatedStorage.Packages.Promise)

local PersistenceConfig = require(script.Parent.Parent.Config.PersistenceConfig)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local ProfileMigrations = require(script.Parent.ProfileMigrations)
local ProfileSanitizer = require(script.Parent.ProfileSanitizer)
local ProfileTemplate = require(script.Parent.ProfileTemplate)

type Dictionary = { [string]: unknown }
type PlayerData = PlayerDataTypes.PlayerData

type SessionEndSignal = {
	Connect: (self: SessionEndSignal, callback: () -> ()) -> (),
}

type Profile = {
	Data: Dictionary,
	AddUserId: (self: Profile, userId: number) -> (),
	Reconcile: (self: Profile) -> (),
	IsActive: (self: Profile) -> boolean,
	EndSession: (self: Profile) -> (),
	OnSessionEnd: SessionEndSignal,
}

type SessionOptions = {
	Cancel: () -> boolean,
}

type ProfileStoreHandle = {
	Mock: ProfileStoreHandle,
	StartSessionAsync: (self: ProfileStoreHandle, key: string, options: SessionOptions) -> Profile?,
}

local PlayerRepository = {}
PlayerRepository.__index = PlayerRepository

export type PlayerRepository = typeof(setmetatable(
	{} :: {
		_store: ProfileStoreHandle,
		_profiles: { [Player]: Profile },
	},
	PlayerRepository
))

function PlayerRepository.new(): PlayerRepository
	local store = (
		ProfileStore.New(PersistenceConfig.StoreName, ProfileTemplate) :: unknown
	) :: ProfileStoreHandle
	if RunService:IsStudio() and PersistenceConfig.UseMockStoreInStudio then
		store = store.Mock
	end

	return setmetatable({
		_store = store,
		_profiles = {},
	}, PlayerRepository)
end

function PlayerRepository:LoadAsync(player: Player)
	return Promise.try(function()
		local profile = self._store:StartSessionAsync(`Player_{player.UserId}`, {
			Cancel = function()
				return player.Parent ~= Players
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
		end)

		if not initialized then
			if profile:IsActive() then
				profile:EndSession()
			end
			error(initializationError)
		end

		profile.OnSessionEnd:Connect(function()
			if self._profiles[player] == profile then
				self._profiles[player] = nil
			end

			if player.Parent == Players then
				player:Kick("Your data session ended. Please reconnect.")
			end
		end)

		if player.Parent ~= Players then
			profile:EndSession()
			error("Player left while profile was loading")
		end

		local data = (profile.Data :: unknown) :: PlayerData
		if data.Wrestler.DisplayName == "" then
			data.Wrestler.DisplayName = player.DisplayName
		end

		self._profiles[player] = profile
		return data
	end)
end

function PlayerRepository:Get(player: Player): PlayerData?
	local profile = self._profiles[player]
	if profile == nil or not profile:IsActive() then
		return nil
	end

	return (profile.Data :: unknown) :: PlayerData
end

function PlayerRepository:Update(player: Player, mutator: (data: PlayerData) -> ()): boolean
	local data = self:Get(player)
	if data == nil then
		return false
	end

	mutator(data)
	return true
end

function PlayerRepository:IsLoaded(player: Player): boolean
	return self:Get(player) ~= nil
end

function PlayerRepository:Release(player: Player)
	local profile = self._profiles[player]
	if profile == nil then
		return
	end

	self._profiles[player] = nil
	if profile:IsActive() then
		profile:EndSession()
	end
end

function PlayerRepository:ReleaseAll()
	for player in self._profiles do
		self:Release(player)
	end
end

return PlayerRepository
