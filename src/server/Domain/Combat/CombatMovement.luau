--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatTypes = require(ReplicatedStorage.Shared.Types.CombatTypes)
local Trove = require(ReplicatedStorage.Packages.Trove)

type CombatState = CombatTypes.CombatState
type MovementBaseline = {
	WalkSpeed: number,
	JumpPower: number,
	JumpHeight: number,
	AutoRotate: boolean,
	JumpEnabled: boolean,
}

local LOCKED_STATES: { [CombatState]: boolean } = {
	Stunned = true,
	Grounded = true,
	Grappling = true,
	PerformingMove = true,
	Pinning = true,
	Pinned = true,
	StandingUp = true,
	ClimbingTurnbuckle = true,
	SittingOnTurnbuckle = true,
	Taunting = true,
}

local CombatMovement = {}
CombatMovement.__index = CombatMovement

export type CombatMovement = typeof(setmetatable(
	{} :: {
		_character: Model,
		_humanoid: Humanoid,
		_trove: typeof(Trove.new()),
		_locked: boolean,
		_baseline: MovementBaseline?,
		_ownedRoot: BasePart?,
	},
	CombatMovement
))

function CombatMovement.new(character: Model, humanoid: Humanoid): CombatMovement
	local self = setmetatable({
		_character = character,
		_humanoid = humanoid,
		_trove = Trove.new(),
		_locked = false,
		_baseline = nil :: MovementBaseline?,
		_ownedRoot = nil :: BasePart?,
	}, CombatMovement)
	self._trove:Connect(character.ChildAdded, function(child)
		if self._locked and child.Name == "HumanoidRootPart" and child:IsA("BasePart") then
			self:_claimRoot(child)
		end
	end)
	return self
end

function CombatMovement._claimRoot(self: CombatMovement, root: BasePart)
	local canSet = false
	local succeeded = pcall(function()
		canSet = root:CanSetNetworkOwnership()
	end)
	if not succeeded or not canSet then
		return
	end
	local claimed = pcall(function()
		root:SetNetworkOwner(nil)
	end)
	if claimed then
		self._ownedRoot = root
	end
end

function CombatMovement.SetLocked(self: CombatMovement, locked: boolean)
	if self._locked == locked then
		return
	end
	self._locked = locked
	local humanoid = self._humanoid
	if locked then
		self._baseline = {
			WalkSpeed = humanoid.WalkSpeed,
			JumpPower = humanoid.JumpPower,
			JumpHeight = humanoid.JumpHeight,
			AutoRotate = humanoid.AutoRotate,
			JumpEnabled = humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping),
		}
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
		humanoid.Jump = false
		humanoid.AutoRotate = false
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		local root = self._character:FindFirstChild("HumanoidRootPart")
		if root ~= nil and root:IsA("BasePart") then
			self:_claimRoot(root)
		end
	else
		local baseline = self._baseline
		if baseline ~= nil then
			humanoid.WalkSpeed = baseline.WalkSpeed
			humanoid.JumpPower = baseline.JumpPower
			humanoid.JumpHeight = baseline.JumpHeight
			humanoid.AutoRotate = baseline.AutoRotate
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, baseline.JumpEnabled)
		end
		self._baseline = nil
		local root = self._ownedRoot
		if root ~= nil then
			pcall(function()
				root:SetNetworkOwnershipAuto()
			end)
			self._ownedRoot = nil
		end
	end
end

function CombatMovement.ApplyState(self: CombatMovement, state: CombatState)
	self:SetLocked(LOCKED_STATES[state] == true)
end

function CombatMovement.Destroy(self: CombatMovement)
	self:SetLocked(false)
	self._trove:Destroy()
end

return CombatMovement
