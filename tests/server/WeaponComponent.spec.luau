--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local WeaponComponent = require(ServerScriptService.Server.Components.WeaponComponent)

return function()
	describe("WeaponComponent", function()
		it("rolls back a reserved use when combat finds no valid target", function()
			local tool = Instance.new("Tool")
			tool:SetAttribute("Durability", 1)
			local component = WeaponComponent.new(tool, "test")
			local consumed, previousUsedAt, revision = component:ConsumeUse()
			expect(consumed).to.equal(true)
			expect(component.Durability).to.equal(0)
			expect(tool.Enabled).to.equal(false)
			expect(component:RollbackUse(previousUsedAt :: number, revision :: number)).to.equal(
				true
			)
			expect(component.Durability).to.equal(1)
			expect(component:CanUse()).to.equal(true)
			expect(component:RollbackUse(previousUsedAt :: number, revision :: number)).to.equal(
				false
			)
			tool:Destroy()
		end)

		it("bounds malformed weapon attributes", function()
			local tool = Instance.new("Tool")
			tool:SetAttribute("Damage", math.huge)
			tool:SetAttribute("PoiseDamage", 1000000)
			tool:SetAttribute("UseCooldown", 0 / 0)
			tool:SetAttribute("MaxDurability", 1000000)
			local component = WeaponComponent.new(tool, "test")
			expect(component.Damage).to.equal(8)
			expect(component.PoiseDamage).to.equal(100)
			expect(component.UseCooldown).to.equal(0.65)
			expect(component.MaxDurability).to.equal(1000)
			tool:Destroy()
		end)

		it("uses service-controlled pickup and restores the arena spawn", function()
			local tool = Instance.new("Tool")
			local handle = Instance.new("Part")
			handle.Name = "Handle"
			handle.CFrame = CFrame.new(12, 5, 8)
			handle.Parent = tool
			tool.Parent = workspace
			local component = WeaponComponent.new(tool, "test")
			expect(tool.CanBeDropped).to.equal(false)
			expect(handle.CanTouch).to.equal(false)
			handle.CFrame = CFrame.new(50, 5, 8)
			component:Reset()
			expect(handle.Position).to.equal(Vector3.new(12, 5, 8))
			tool:Destroy()
		end)
	end)
end
