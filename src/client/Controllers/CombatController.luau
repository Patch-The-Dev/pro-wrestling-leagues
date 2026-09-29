--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationSystem = require(script.Parent.Parent.Systems.AnimationSystem)
local Knit = require(ReplicatedStorage.Packages.Knit)
local Promise = require(ReplicatedStorage.Packages.Promise)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)

local CombatController = Knit.CreateController({
	Name = "CombatController",
})

function CombatController:KnitInit()
	self._trove = Trove.new()
	self.ActionResolved = Signal.new()
	self._activeGrappleSession = nil
	self._activePinSession = nil
	self._animations = AnimationSystem.new()
	self._trove:Add(self.ActionResolved)
	self._trove:Add(self._animations)
end

function CombatController:KnitStart()
	self._combatService = Knit.GetService("CombatService")
	local input = Knit.GetController("InputController")

	self._trove:Connect(input.ActionRequested, function(action)
		self._combatService:RequestAction(action):catch(function(err)
			warn(`Combat request failed: {tostring(err)}`)
		end)
	end)

	self._trove:Connect(input.GrappleRequested, function(direction, running)
		self._combatService:RequestGrapple(direction, running):catch(function(err)
			warn(`Grapple request failed: {tostring(err)}`)
		end)
	end)

	self._trove:Connect(input.ContextPressed, function()
		if self._activePinSession ~= nil then
			self._combatService:SubmitPinInput(self._activePinSession):catch(function(err)
				warn(`Pin input request failed: {tostring(err)}`)
			end)
		elseif self._activeGrappleSession ~= nil then
			self._combatService:TryReverse(self._activeGrappleSession):catch(function(err)
				warn(`Reversal request failed: {tostring(err)}`)
			end)
		end
	end)

	self._trove:Connect(self._combatService.ActionResolved, function(event)
		self._animations:PlayResolvedAction(event)
		self.ActionResolved:Fire(event)
	end)

	self._trove:Connect(self._combatService.GrappleWindow, function(sessionId, endsAt)
		self._activeGrappleSession = sessionId
		local remaining = math.max(0, endsAt - workspace:GetServerTimeNow())
		local expiry = Promise.delay(remaining + 0.05):andThen(function()
			if self._activeGrappleSession == sessionId then
				self._activeGrappleSession = nil
			end
		end)
		self._trove:AddPromise(expiry)
	end)

	self._trove:Connect(self._combatService.PinPrompt, function(sessionId, _targetTime)
		self._activePinSession = sessionId
	end)

	self._trove:Connect(self._combatService.PinResolved, function(sessionId)
		if self._activePinSession == sessionId then
			self._activePinSession = nil
		end
	end)
end

return CombatController
