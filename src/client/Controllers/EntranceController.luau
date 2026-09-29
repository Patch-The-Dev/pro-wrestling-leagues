--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Promise = require(ReplicatedStorage.Packages.Promise)
local Trove = require(ReplicatedStorage.Packages.Trove)
local EntranceConfig = require(ReplicatedStorage.Shared.Config.EntranceConfig)
local AudioSystem = require(script.Parent.Parent.Systems.AudioSystem)
local CameraSystem = require(script.Parent.Parent.Systems.CameraSystem)
local LightingSystem = require(script.Parent.Parent.Systems.LightingSystem)
local PyroSystem = require(script.Parent.Parent.Systems.PyroSystem)

local EntranceController = Knit.CreateController({
	Name = "EntranceController",
})

function EntranceController:KnitInit()
	self._trove = Trove.new()
	self._audio = AudioSystem.new()
	self._camera = CameraSystem.new()
	self._lighting = LightingSystem.new()
	self._pyro = PyroSystem.new()
	self._trove:Add(self._audio)
	self._trove:Add(self._camera)
	self._trove:Add(self._lighting)
	self._trove:Add(self._pyro)
end

function EntranceController:KnitStart()
	self._service = Knit.GetService("EntranceService")
	self._trove:Connect(self._service.EntranceCue, function(cue)
		local waitSeconds = math.max(0, cue.StartsAt - workspace:GetServerTimeNow())
		local promise = Promise.delay(waitSeconds):andThen(function()
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
