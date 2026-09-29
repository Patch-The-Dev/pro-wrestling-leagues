--!strict

local CharacterAdapter = {}

function CharacterAdapter.PlaceAt(character: Model, target: CFrame): boolean
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		character:PivotTo(target)
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		return true
	end
	return false
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
