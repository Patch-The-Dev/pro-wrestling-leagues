--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local Targeting = require(ServerScriptService.Server.Domain.Combat.Targeting)

return function()
	describe("Targeting", function()
		local function makeCharacter(name: string, position: Vector3): Model
			local character = Instance.new("Model")
			character.Name = name
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Anchored = true
			root.Position = position
			root.Parent = character
			local humanoid = Instance.new("Humanoid")
			humanoid.Parent = character
			character.Parent = workspace
			return character
		end

		it("selects an opponent in front and within range", function()
			local attackerCharacter = makeCharacter("Attacker", Vector3.new(0, 20, 0))
			local targetCharacter = makeCharacter("Target", Vector3.new(0, 20, -4))
			local attacker = { Character = attackerCharacter } :: any
			local opponent = { Character = targetCharacter } :: any
			expect(Targeting.FindNearestOpponent(attacker, { opponent }, 6, 0.2)).to.equal(opponent)
			targetCharacter.HumanoidRootPart.Position = Vector3.new(0, 20, 4)
			expect(Targeting.FindNearestOpponent(attacker, { opponent }, 6, 0.2)).to.equal(nil)
			attackerCharacter:Destroy()
			targetCharacter:Destroy()
		end)

		it("rejects a target behind solid cover", function()
			local attackerCharacter = makeCharacter("Attacker", Vector3.new(0, 30, 0))
			local targetCharacter = makeCharacter("Target", Vector3.new(0, 30, -4))
			local blocker = Instance.new("Part")
			blocker.Anchored = true
			blocker.Size = Vector3.new(4, 4, 1)
			blocker.Position = Vector3.new(0, 30, -2)
			blocker.Parent = workspace
			local attacker = { Character = attackerCharacter } :: any
			local opponent = { Character = targetCharacter } :: any
			expect(Targeting.FindNearestOpponent(attacker, { opponent }, 6, 0.2)).to.equal(nil)
			attackerCharacter:Destroy()
			targetCharacter:Destroy()
			blocker:Destroy()
		end)
	end)
end
