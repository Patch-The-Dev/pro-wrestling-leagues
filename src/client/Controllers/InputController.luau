--!strict

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
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
	self._thumbstick = Vector2.zero

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
	if self._thumbstick.Y > 0.4 then
		return "Forward"
	elseif self._thumbstick.X < -0.4 then
		return "Left"
	elseif self._thumbstick.Y < -0.4 then
		return "Backward"
	elseif self._thumbstick.X > 0.4 then
		return "Right"
	end
	local character = Players.LocalPlayer.Character
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if humanoid ~= nil and root ~= nil and root:IsA("BasePart") then
		local movement = humanoid.MoveDirection
		if movement.Magnitude > 0.2 then
			local forward = movement:Dot(root.CFrame.LookVector)
			local right = movement:Dot(root.CFrame.RightVector)
			if math.abs(forward) >= math.abs(right) then
				return if forward >= 0 then "Forward" else "Backward"
			end
			return if right >= 0 then "Right" else "Left"
		end
	end
	return "Finisher"
end

function InputController:_requestGrapple()
	self.GrappleRequested:Fire(
		self:_grappleDirection(),
		self._held[InputConfig.RunModifier] == true
			or self._held[InputConfig.Gamepad.RunModifier] == true
	)
end

function InputController:_bindTouchAction(
	name: string,
	title: string,
	key: Enum.KeyCode,
	callback: () -> ()
)
	local actionName = `PWL_{name}`
	ContextActionService:BindAction(actionName, function(_, state)
		if state == Enum.UserInputState.Begin and UserInputService:GetFocusedTextBox() == nil then
			callback()
		end
		return Enum.ContextActionResult.Sink
	end, true, key)
	ContextActionService:SetTitle(actionName, title)
	self._trove:Add(function()
		ContextActionService:UnbindAction(actionName)
	end)
end

function InputController:KnitStart()
	local gamepad = InputConfig.Gamepad
	self:_bindTouchAction("Attack", "Strike", gamepad.Attack, function()
		self.ActionRequested:Fire("Attack")
	end)
	self:_bindTouchAction("Grapple", "Grapple", gamepad.Grapple, function()
		self:_requestGrapple()
	end)
	self:_bindTouchAction("Context", "Counter", gamepad.Context, function()
		self.ContextPressed:Fire()
	end)
	self:_bindTouchAction("Pin", "Pin", gamepad.Pin, function()
		self.ActionRequested:Fire("Pin")
	end)
	self:_bindTouchAction("Dash", "Dash", gamepad.Dash, function()
		self.ActionRequested:Fire("Dash")
	end)

	self._trove:Connect(UserInputService.InputChanged, function(input)
		if input.KeyCode == Enum.KeyCode.Thumbstick1 then
			self._thumbstick = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)

	self._trove:Connect(UserInputService.InputBegan, function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() ~= nil then
			return
		end

		self._held[input.KeyCode] = true

		if input.UserInputType == InputConfig.Attack then
			self.ActionRequested:Fire("Attack")
		elseif input.KeyCode == InputConfig.Grapple then
			self:_requestGrapple()
		elseif input.KeyCode == InputConfig.Context then
			self.ContextPressed:Fire()
		elseif input.KeyCode == InputConfig.Pin then
			self.ActionRequested:Fire("Pin")
		elseif
			input.KeyCode == InputConfig.RunningAttack or input.KeyCode == gamepad.RunningAttack
		then
			self.ActionRequested:Fire("RunningAttack")
		elseif
			input.KeyCode == InputConfig.TurnbuckleAttack
			or input.KeyCode == gamepad.TurnbuckleAttack
		then
			self.ActionRequested:Fire("TurnbuckleAttack")
		elseif
			input.KeyCode == InputConfig.TurnbuckleClimb
			or input.KeyCode == gamepad.TurnbuckleClimb
		then
			self.TurnbuckleRequested:Fire()
		elseif input.KeyCode == InputConfig.Taunt or input.KeyCode == gamepad.Taunt then
			self.ActionRequested:Fire("Taunt")
		elseif input.KeyCode == InputConfig.Dash then
			self.ActionRequested:Fire("Dash")
		end
	end)

	self._trove:Connect(UserInputService.InputEnded, function(input)
		self._held[input.KeyCode] = nil
		if input.KeyCode == Enum.KeyCode.Thumbstick1 then
			self._thumbstick = Vector2.zero
		end
	end)
end

return InputController
