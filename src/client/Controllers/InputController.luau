--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local CombatTypes = require(ReplicatedStorage.Shared.Types.CombatTypes)
local InputConfig = require(ReplicatedStorage.Shared.Config.InputConfig)
local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)

type GrappleDirection = CombatTypes.GrappleDirection

local InputController = Knit.CreateController({
	Name = "InputController",
})

function InputController:KnitInit()
	self._trove = Trove.new()
	self.ActionRequested = Signal.new()
	self.GrappleRequested = Signal.new()
	self.ContextPressed = Signal.new()
	self.TurnbuckleRequested = Signal.new()
	self._held = {} :: { [Enum.KeyCode]: boolean }

	self._trove:Add(self.ActionRequested)
	self._trove:Add(self.GrappleRequested)
	self._trove:Add(self.ContextPressed)
	self._trove:Add(self.TurnbuckleRequested)
end

function InputController:_grappleDirection(): GrappleDirection
	if self._held[Enum.KeyCode.W] then
		return "Forward"
	elseif self._held[Enum.KeyCode.A] then
		return "Left"
	elseif self._held[Enum.KeyCode.S] then
		return "Backward"
	elseif self._held[Enum.KeyCode.D] then
		return "Right"
	end
	return "Finisher"
end

function InputController:KnitStart()
	self._trove:Connect(UserInputService.InputBegan, function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() ~= nil then
			return
		end

		self._held[input.KeyCode] = true

		if input.UserInputType == InputConfig.Attack then
			self.ActionRequested:Fire("Attack")
		elseif input.KeyCode == InputConfig.Grapple then
			self.GrappleRequested:Fire(
				self:_grappleDirection(),
				self._held[InputConfig.RunModifier] == true
			)
		elseif input.KeyCode == InputConfig.Context then
			self.ContextPressed:Fire()
		elseif input.KeyCode == InputConfig.Pin then
			self.ActionRequested:Fire("Pin")
		elseif input.KeyCode == InputConfig.RunningAttack then
			self.ActionRequested:Fire("RunningAttack")
		elseif input.KeyCode == InputConfig.TurnbuckleAttack then
			self.ActionRequested:Fire("TurnbuckleAttack")
		elseif input.KeyCode == InputConfig.TurnbuckleClimb then
			self.TurnbuckleRequested:Fire()
		elseif input.KeyCode == InputConfig.Taunt then
			self.ActionRequested:Fire("Taunt")
		elseif input.KeyCode == InputConfig.Dash then
			self.ActionRequested:Fire("Dash")
		end
	end)

	self._trove:Connect(UserInputService.InputEnded, function(input)
		self._held[input.KeyCode] = nil
	end)
end

return InputController
