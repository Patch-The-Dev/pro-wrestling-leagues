--!strict

local CharacterAdapter = {}

function CharacterAdapter.PlaceAt(character: Model, target: CFrame)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		character:PivotTo(target)
	end
end

function CharacterAdapter.ApplyBackwardVelocity(character: Model, speed: number): boolean
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return false
	end

	local horizontal = -root.CFrame.LookVector * math.max(0, speed)
	local current = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(horizontal.X, current.Y, horizontal.Z)
	return true
end

return CharacterAdapter
