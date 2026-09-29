--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatTypes = require(ReplicatedStorage.Shared.Types.CombatTypes)
local Trove = require(ReplicatedStorage.Packages.Trove)

type ResolvedAction = CombatTypes.ResolvedAction
type AnimationRole = "Attacker" | "Victim"

local AnimationSystem = {}
AnimationSystem.__index = AnimationSystem

export type AnimationSystem = typeof(setmetatable(
	{} :: {
		_trove: typeof(Trove.new()),
	},
	AnimationSystem
))

local function getAnimationRoot(): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	return if assets ~= nil then assets:FindFirstChild("Animations") else nil
end

local function resolveAnimation(key: string, role: AnimationRole): Animation?
	local root = getAnimationRoot()
	if root == nil then
		return nil
	end

	local entry = root:FindFirstChild(key)
	if entry == nil then
		return nil
	end
	if entry:IsA("Animation") then
		return if role == "Attacker" then entry else nil
	end

	local roleAnimation = entry:FindFirstChild(role)
	return if roleAnimation ~= nil and roleAnimation:IsA("Animation") then roleAnimation else nil
end

local function resolveKey(event: ResolvedAction): string
	if event.MoveId ~= nil then
		return event.MoveId
	elseif event.WeaponId ~= nil then
		return event.WeaponId
	end
	return event.Action
end

function AnimationSystem.new(): AnimationSystem
	return setmetatable({
		_trove = Trove.new(),
	}, AnimationSystem)
end

function AnimationSystem:_playForUser(userId: number, animation: Animation?)
	if animation == nil then
		return
	end

	local player = Players:GetPlayerByUserId(userId)
	local character = if player ~= nil then player.Character else nil
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	local animator = if humanoid ~= nil then humanoid:FindFirstChildOfClass("Animator") else nil
	if animator == nil then
		return
	end

	local track = animator:LoadAnimation(animation)
	local trackTrove = self._trove:Extend()
	trackTrove:Add(track)
	trackTrove:Connect(track.Stopped, function()
		trackTrove:Destroy()
	end)
	track:Play(0.1)
end

function AnimationSystem:PlayResolvedAction(event: ResolvedAction)
	local key = resolveKey(event)
	self:_playForUser(event.AttackerUserId, resolveAnimation(key, "Attacker"))
	if event.TargetUserId ~= nil then
		self:_playForUser(event.TargetUserId, resolveAnimation(key, "Victim"))
	end
end

function AnimationSystem:PlayStartedAction(event: ResolvedAction)
	self:_playForUser(event.AttackerUserId, resolveAnimation(resolveKey(event), "Attacker"))
end

function AnimationSystem:PlayStrikeImpact(event: ResolvedAction)
	if event.TargetUserId ~= nil then
		self:_playForUser(event.TargetUserId, resolveAnimation(resolveKey(event), "Victim"))
	end
end

function AnimationSystem:Destroy()
	self._trove:Destroy()
end

return AnimationSystem
