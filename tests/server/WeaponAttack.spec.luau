--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local WeaponAttack = require(ServerScriptService.Server.Domain.Combat.WeaponAttack)

return function()
	describe("WeaponAttack", function()
		it("reserves durability before combat and restores it on a miss", function()
			local calls = {}
			local player = { UserId = 1 } :: any
			local component = {
				DefinitionId = "Test Weapon",
				Durability = 2,
				IsEquippedBy = function()
					return true
				end,
				CanUse = function()
					return true
				end,
				ConsumeUse = function(self)
					table.insert(calls, "consume")
					self.Durability -= 1
					return true, -math.huge, 1
				end,
				RollbackUse = function(self)
					table.insert(calls, "rollback")
					self.Durability += 1
				end,
				GetDamageSpec = function()
					return {} :: any
				end,
			} :: any
			local matchSource = {
				IsMatchActiveFor = function()
					return true
				end,
			} :: any
			local combatSource = {
				ApplyWeaponAttack = function()
					table.insert(calls, "apply")
					return false
				end,
			} :: any
			local succeeded = WeaponAttack.Try(
				player,
				component,
				matchSource,
				combatSource,
				function()
					return true
				end
			)
			expect(succeeded).to.equal(false)
			expect(table.concat(calls, ",")).to.equal("consume,apply,rollback")
			expect(component.Durability).to.equal(2)
		end)
	end)
end
