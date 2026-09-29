--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Promise = require(ReplicatedStorage.Packages.Promise)
local Trove = require(ReplicatedStorage.Packages.Trove)

local CameraSystem = {}
CameraSystem.__index = CameraSystem

export type CameraSystem = typeof(setmetatable(
	{} :: {
		_trove: typeof(Trove.new()),
		_generation: number,
		_baselineType: Enum.CameraType?,
		_baselineSubject: Instance?,
	},
	CameraSystem
))

function CameraSystem.new(): CameraSystem
	return setmetatable({
		_trove = Trove.new(),
		_generation = 0,
		_baselineType = nil,
		_baselineSubject = nil,
	}, CameraSystem)
end

function CameraSystem:_restore(camera: Camera)
	local baselineType = self._baselineType
	self._baselineType = nil

	if baselineType ~= nil then
		camera.CameraType = baselineType
	end
	camera.CameraSubject = self._baselineSubject
	self._baselineSubject = nil
end

function CameraSystem:FocusPlayer(userId: number, duration: number)
	local camera = workspace.CurrentCamera
	local player = Players:GetPlayerByUserId(userId)
	local character = if player ~= nil then player.Character else nil
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	if camera == nil or humanoid == nil then
		return Promise.resolve()
	end

	if self._baselineType == nil then
		self._baselineType = camera.CameraType
		self._baselineSubject = camera.CameraSubject
	end

	self._generation += 1
	local generation = self._generation
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = humanoid

	local promise = Promise.delay(math.max(0, duration)):andThen(function()
		if generation ~= self._generation or workspace.CurrentCamera ~= camera then
			return
		end
		self:_restore(camera)
	end)
	self._trove:AddPromise(promise)
	return promise
end

function CameraSystem:Destroy()
	self._generation += 1
	local camera = workspace.CurrentCamera
	if camera ~= nil and self._baselineType ~= nil then
		self:_restore(camera)
	end
	self._trove:Destroy()
end

return CameraSystem
