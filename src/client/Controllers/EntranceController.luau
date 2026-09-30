--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AudioSystem = require(script.Parent.Parent.Systems.AudioSystem)
local CameraSystem = require(script.Parent.Parent.Systems.CameraSystem)
local EntranceConfig = require(ReplicatedStorage.Shared.Config.EntranceConfig)
local Knit = require(script.Parent.Parent.KnitClient)
local LightingSystem = require(script.Parent.Parent.Systems.LightingSystem)
local NetworkTypes = require(ReplicatedStorage.Shared.Types.NetworkTypes)
local Promise = require(ReplicatedStorage.Packages.Promise)
local PyroSystem = require(script.Parent.Parent.Systems.PyroSystem)
local Trove = require(ReplicatedStorage.Packages.Trove)

type EntranceCue = NetworkTypes.EntranceCue

local EntranceController = Knit.CreateController({
	Name = "EntranceController",
})

function EntranceController:KnitInit()
	self._trove = Trove.new()
	self._generation = 0
	self._audio = AudioSystem.new()
	self._camera = CameraSystem.new()
	self._lighting = LightingSystem.new()
	self._pyro = PyroSystem.new()
	self._trove:Add(self._audio)
	self._trove:Add(self._camera)
	self._trove:Add(self._lighting)
	self._trove:Add(self._pyro)
end

function EntranceController:_stopPresentation()
	self._generation += 1
	self._audio:StopMusic()
	self._camera:Stop()
	self._lighting:Stop()
	self._pyro:Stop()
end

function EntranceController:KnitStart()
	self._service = Knit.GetService("EntranceService")
	local matchController = Knit.GetController("MatchController")
	self._trove:Connect(matchController.Changed, function(update)
		if update.State == "Starting" or update.State == "Active" or update.State == "Complete" then
			self:_stopPresentation()
		end
	end)
	self._trove:Connect(self._service.EntranceCue, function(cue: EntranceCue)
		local generation = self._generation
		local waitSeconds = math.max(0, cue.StartsAt - workspace:GetServerTimeNow())
		local promise = Promise.delay(waitSeconds):andThen(function()
			if generation ~= self._generation then
				return
			end
			if cue.MatchId ~= nil then
				local match = matchController:GetMatch()
				if match == nil or match.Id ~= cue.MatchId or match.State ~= "Starting" then
					return
				end
			end
			self._audio:PlayMusic(cue.MusicId)
			self._camera:FocusPlayer(cue.UserId, EntranceConfig.CameraFocusSeconds)
			self._pyro:Play(cue.PyroPreset, cue.ArenaId)
			self._lighting:PlayPreset(cue.LightingPreset, EntranceConfig.LightingHoldSeconds)
		end)
		self._trove:AddPromise(promise)
	end)
end

function EntranceController:Preview()
	return self._service:Preview()
end

return EntranceController
