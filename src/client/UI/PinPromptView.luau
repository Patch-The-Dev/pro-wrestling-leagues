--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CombatConfig = require(ReplicatedStorage.Shared.Config.CombatConfig)
local Trove = require(ReplicatedStorage.Packages.Trove)

local PinPromptView = {}
PinPromptView.__index = PinPromptView

export type PinPromptView = typeof(setmetatable(
	{} :: {
		_trove: typeof(Trove.new()),
		_gui: ScreenGui?,
		_label: TextLabel?,
		_marker: Frame?,
		_zone: Frame?,
		_targetTime: number?,
		_startTime: number,
	},
	PinPromptView
))

local function frame(parent: Instance, name: string, color: Color3): Frame
	local element = Instance.new("Frame")
	element.Name = name
	element.BackgroundColor3 = color
	element.BorderSizePixel = 0
	element.Parent = parent
	return element
end

function PinPromptView.new(): PinPromptView
	local self = setmetatable({
		_trove = Trove.new(),
		_gui = nil :: ScreenGui?,
		_label = nil :: TextLabel?,
		_marker = nil :: Frame?,
		_zone = nil :: Frame?,
		_targetTime = nil :: number?,
		_startTime = 0,
	}, PinPromptView)
	self._trove:Connect(RunService.RenderStepped, function()
		self:_render()
	end)
	return self
end

function PinPromptView:_ensureGui(): boolean
	if self._gui ~= nil then
		return true
	end
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return false
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "PinTimingPrompt"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.Enabled = false
	gui.Parent = playerGui
	self._trove:Add(gui)

	local panel = frame(gui, "Panel", Color3.fromRGB(19, 23, 32))
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.78)
	panel.Size = UDim2.new(0.9, 0, 0, 84)
	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MaxSize = Vector2.new(340, 84)
	sizeConstraint.MinSize = Vector2.new(220, 84)
	sizeConstraint.Parent = panel
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel

	local label = Instance.new("TextLabel")
	label.Name = "Instruction"
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = Color3.fromRGB(238, 242, 247)
	label.TextSize = 15
	label.Text = "Press counter in the green zone"
	label.Size = UDim2.new(1, -24, 0, 30)
	label.Position = UDim2.fromOffset(12, 7)
	label.Parent = panel

	local rail = frame(panel, "TimingRail", Color3.fromRGB(56, 64, 77))
	rail.Position = UDim2.fromOffset(18, 49)
	rail.Size = UDim2.new(1, -36, 0, 13)
	local zone = frame(rail, "SuccessZone", Color3.fromRGB(63, 190, 121))
	zone.Size = UDim2.fromScale(0, 1)
	local marker = frame(rail, "Marker", Color3.fromRGB(255, 255, 255))
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.Position = UDim2.fromScale(0, 0.5)
	marker.Size = UDim2.fromOffset(4, 22)

	self._gui = gui
	self._label = label
	self._marker = marker
	self._zone = zone
	return true
end

function PinPromptView:Show(targetTime: number)
	if not self:_ensureGui() then
		return
	end
	local window = CombatConfig.Pin.InputWindowSeconds
	self._targetTime = targetTime
	self._startTime = math.min(workspace:GetServerTimeNow(), targetTime - 0.65)
	local duration = math.max(0.1, targetTime + window - self._startTime)
	local zoneStart = math.clamp((targetTime - window - self._startTime) / duration, 0, 1)
	local zoneEnd = math.clamp((targetTime + window - self._startTime) / duration, 0, 1)
	local zone = self._zone :: Frame
	zone.Position = UDim2.fromScale(zoneStart, 0)
	zone.Size = UDim2.fromScale(zoneEnd - zoneStart, 1)
	local gui = self._gui :: ScreenGui
	gui.Enabled = true
	self:_render()
end

function PinPromptView:_render()
	local targetTime = self._targetTime
	if targetTime == nil then
		return
	end
	local now = workspace:GetServerTimeNow()
	local window = CombatConfig.Pin.InputWindowSeconds
	local duration = math.max(0.1, targetTime + window - self._startTime)
	local progress = math.clamp((now - self._startTime) / duration, 0, 1)
	local marker = self._marker :: Frame
	marker.Position = UDim2.fromScale(progress, 0.5)
	local label = self._label :: TextLabel
	if now < targetTime - window then
		label.Text = "Press counter in the green zone"
	elseif now <= targetTime + window then
		label.Text = "COUNTER NOW"
	else
		label.Text = "Waiting for the next count"
	end
end

function PinPromptView:Hide()
	self._targetTime = nil
	if self._gui ~= nil then
		self._gui.Enabled = false
	end
end

function PinPromptView:Destroy()
	self._trove:Destroy()
end

return PinPromptView
