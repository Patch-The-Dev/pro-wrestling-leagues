--!strict

local SoundService = game:GetService("SoundService")

local AudioSystem = {}
AudioSystem.__index = AudioSystem

export type AudioSystem = typeof(setmetatable(
	{} :: {
		_activeSound: Sound?,
	},
	AudioSystem
))

function AudioSystem.new(): AudioSystem
	return setmetatable({
		_activeSound = nil :: Sound?,
	}, AudioSystem)
end

function AudioSystem:PlayMusic(assetId: string?)
	self:StopMusic()
	if assetId == nil then
		return
	end

	local digits = string.match(assetId, "%d+")
	if digits == nil then
		return
	end

	local sound = Instance.new("Sound")
	sound.Name = "EntranceMusic"
	sound.SoundId = `rbxassetid://{digits}`
	sound.Volume = 0.7
	sound.Parent = SoundService
	sound:Play()
	self._activeSound = sound
end

function AudioSystem.StopMusic(self: AudioSystem)
	if self._activeSound ~= nil then
		self._activeSound:Destroy()
		self._activeSound = nil
	end
end

function AudioSystem:Destroy()
	self:StopMusic()
end

return AudioSystem
