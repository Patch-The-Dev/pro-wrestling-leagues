--!strict

local Targeting = {}

local function getRoot(character: Model): BasePart?
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function hasLineOfSight(
	attackerCharacter: Model,
	targetCharacter: Model,
	offset: Vector3
): boolean
	local attackerRoot = getRoot(attackerCharacter)
	if attackerRoot == nil then
		return false
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { attackerCharacter }
	params.RespectCanCollide = true

	local result = workspace:Raycast(attackerRoot.Position, offset, params)
	return result == nil or result.Instance:IsDescendantOf(targetCharacter)
end

function Targeting.FindNearestOpponent(
	attacker: Player,
	candidates: { Player },
	maximumDistance: number,
	minimumFacingDot: number
): Player?
	local attackerCharacter = attacker.Character
	if attackerCharacter == nil then
		return nil
	end

	local attackerRoot = getRoot(attackerCharacter)
	if attackerRoot == nil then
		return nil
	end

	local bestPlayer: Player? = nil
	local bestDistance = maximumDistance

	for _, candidate in candidates do
		if candidate ~= attacker then
			local candidateCharacter = candidate.Character
			local candidateRoot = if candidateCharacter ~= nil
				then getRoot(candidateCharacter)
				else nil
			local humanoid = if candidateCharacter ~= nil
				then candidateCharacter:FindFirstChildOfClass("Humanoid")
				else nil

			if candidateRoot ~= nil and humanoid ~= nil and humanoid.Health > 0 then
				local offset = candidateRoot.Position - attackerRoot.Position
				local distance = offset.Magnitude
				if distance > 0 and distance <= bestDistance then
					local facingDot = attackerRoot.CFrame.LookVector:Dot(offset.Unit)
					if
						facingDot >= minimumFacingDot
						and hasLineOfSight(attackerCharacter, candidateCharacter, offset)
					then
						bestDistance = distance
						bestPlayer = candidate
					end
				end
			end
		end
	end

	return bestPlayer
end

return Targeting
