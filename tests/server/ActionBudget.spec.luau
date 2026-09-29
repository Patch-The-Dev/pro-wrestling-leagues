--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ActionBudget = require(ServerScriptService.Server.Domain.Combat.ActionBudget)

return function()
	describe("ActionBudget", function()
		it("restores stamina and cooldown when an accepted action is rolled back", function()
			local player = {} :: any
			local stamina = 10
			local combatant = {
				GetState = function()
					return "Roaming"
				end,
				CanSpendStamina = function(_, amount)
					return stamina >= amount
				end,
				SpendStamina = function(_, amount)
					if stamina < amount then
						return false
					end
					stamina -= amount
					return true
				end,
				RestoreStamina = function(_, amount)
					stamina += amount
				end,
			} :: any
			local budget = ActionBudget.new()
			expect(budget:Validate(player, combatant, "Attack")).to.equal(true)
			expect(budget:Commit(player, combatant, "Attack")).to.equal(true)
			expect(stamina).to.equal(5)
			expect(budget:Validate(player, combatant, "Attack")).to.equal(false)
			budget:Rollback(player, combatant, "Attack")
			expect(stamina).to.equal(10)
			expect(budget:Validate(player, combatant, "Attack")).to.equal(true)
			budget:Destroy()
		end)
	end)
end
