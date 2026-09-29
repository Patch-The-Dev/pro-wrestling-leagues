--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EntranceConfig = require(ReplicatedStorage.Shared.Config.EntranceConfig)
local Knit = require(ReplicatedStorage.Packages.Knit)
local NetworkTypes = require(ReplicatedStorage.Shared.Types.NetworkTypes)

type EntranceCue = NetworkTypes.EntranceCue

local EntranceService = Knit.CreateService({
	Name = "EntranceService",
	Client = {
		EntranceCue = Knit.CreateSignal(),
	},
})

function EntranceService:KnitStart()
	self._dataService = Knit.GetService("DataService")
	self._requestGate = Knit.GetService("RequestGateService")
end

function EntranceService:_buildCue(player: Player, startsAt: number, arenaId: string?): EntranceCue?
	local data = self._dataService:Get(player)
	if data == nil then
		return nil
	end

	return {
		UserId = player.UserId,
		DisplayName = data.Wrestler.DisplayName,
		MusicId = data.Entrance.MusicId,
		PyroPreset = data.Entrance.PyroPreset,
		LightingPreset = data.Entrance.LightingPreset,
		StartsAt = startsAt,
		ArenaId = arenaId,
	}
end

function EntranceService:PlayForPlayers(players: { Player }, arenaId: string)
	local startsAt = workspace:GetServerTimeNow() + EntranceConfig.LeadInSeconds
	for index, entrant in players do
		local cue = self:_buildCue(
			entrant,
			startsAt + (index - 1) * EntranceConfig.EntrantSpacingSeconds,
			arenaId
		)
		if cue ~= nil then
			for _, viewer in players do
				self.Client.EntranceCue:Fire(viewer, cue)
			end
		end
	end
end

function EntranceService.Client:Preview(player: Player)
	if not self.Server._requestGate:Allow(player, "Interaction") then
		return false
	end

	local cue = self.Server:_buildCue(player, workspace:GetServerTimeNow() + 0.25, nil)
	if cue == nil then
		return false
	end
	self.Server.Client.EntranceCue:Fire(player, cue)
	return true
end

return EntranceService
