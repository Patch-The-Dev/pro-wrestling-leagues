--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local Combatant = require(ServerScriptService.Server.Domain.Combat.Combatant)

return function()
	describe("Combatant movement", function()
		it("locks incapacitated movement and restores the character on recovery", function()
			local character = Instance.new("Model")
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Parent = character
			local humanoid = Instance.new("Humanoid")
			humanoid.WalkSpeed = 22
			humanoid.JumpPower = 60
			humanoid.AutoRotate = true
			humanoid.Parent = character
			character.Parent = workspace

			local combatant = Combatant.new({ UserId = 10 } :: any, character)
			expect(combatant:SetState("Stunned")).to.equal(true)
			expect(humanoid.WalkSpeed).to.equal(0)
			expect(humanoid.JumpPower).to.equal(0)
			expect(humanoid.AutoRotate).to.equal(false)
			expect(combatant:SetState("Roaming")).to.equal(true)
			expect(humanoid.WalkSpeed).to.equal(22)
			expect(humanoid.JumpPower).to.equal(60)
			expect(humanoid.AutoRotate).to.equal(true)

			expect(combatant:SetState("Grounded")).to.equal(true)
			expect(humanoid.WalkSpeed).to.equal(0)
			combatant:ResetForMatchEnd()
			expect(combatant:GetState()).to.equal("Roaming")
			expect(humanoid.WalkSpeed).to.equal(22)
			combatant:Destroy()
			character:Destroy()
		end)
	end)
end
