--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local WeaponService = require(ServerScriptService.Server.Services.WeaponService)

return function()
	describe("WeaponService", function()
		it("reserves durability before combat and restores it on a miss", function()
			local calls = {}
			local tool = Instance.new("Tool")
			local component = {
				Instance = tool,
				DefinitionId = "Test Weapon",
				Durability = 2,
				IsEquippedBy = function()
					return true
				end,
				GetWorldParent = function()
					return workspace
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
			local previousWeapons = WeaponService._weaponsByNetworkId
			local previousMatch = WeaponService._matchService
			local previousCombat = WeaponService._combatService
			WeaponService._weaponsByNetworkId = { test = component }
			WeaponService._matchService = {
				IsMatchActiveFor = function()
					return true
				end,
				IsInstanceInPlayerArena = function()
					return true
				end,
			}
			WeaponService._combatService = {
				ApplyWeaponAttack = function()
					table.insert(calls, "apply")
					return false
				end,
			}
			local succeeded = WeaponService:RequestAction({ UserId = 1 } :: any, "test", "Attack")
			expect(succeeded).to.equal(false)
			expect(table.concat(calls, ",")).to.equal("consume,apply,rollback")
			expect(component.Durability).to.equal(2)
			WeaponService._weaponsByNetworkId = previousWeapons
			WeaponService._matchService = previousMatch
			WeaponService._combatService = previousCombat
			tool:Destroy()
		end)
	end)
end
