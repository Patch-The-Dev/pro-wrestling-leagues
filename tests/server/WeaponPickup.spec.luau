--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local WeaponPickup = require(ServerScriptService.Server.Domain.Combat.WeaponPickup)

return function()
	describe("WeaponPickup", function()
		it("rejects a nearby weapon when movement was implausible", function()
			local player = { UserId = 7 } :: any
			local pickupCalls = 0
			local component = {
				Instance = Instance.new("Tool"),
				IsAvailableForPickup = function()
					return true
				end,
				Pickup = function()
					pickupCalls += 1
					return true
				end,
			} :: any
			local matchSource = {
				IsMatchActiveFor = function()
					return true
				end,
				IsInstanceInPlayerArena = function()
					return true
				end,
			} :: any
			local movementSource = {
				IsMovementPlausible = function()
					return false
				end,
			} :: any
			local allowed, reason = WeaponPickup.Try(
				player,
				component.Instance,
				matchSource,
				movementSource,
				function()
					return component:IsAvailableForPickup()
				end,
				function()
					return true
				end,
				function()
					return component:Pickup(player)
				end
			)
			expect(allowed).to.equal(false)
			expect(reason).to.equal("Character movement is not plausible")
			expect(pickupCalls).to.equal(0)
			component.Instance:Destroy()
		end)

		it("allows pickup after match, arena, movement, and range validation", function()
			local player = { UserId = 8 } :: any
			local pickupCalls = 0
			local component = {
				Instance = Instance.new("Tool"),
				IsAvailableForPickup = function()
					return true
				end,
				Pickup = function()
					pickupCalls += 1
					return true
				end,
			} :: any
			local matchSource = {
				IsMatchActiveFor = function()
					return true
				end,
				IsInstanceInPlayerArena = function()
					return true
				end,
			} :: any
			local movementSource = {
				IsMovementPlausible = function()
					return true
				end,
			} :: any
			local allowed = WeaponPickup.Try(
				player,
				component.Instance,
				matchSource,
				movementSource,
				function()
					return component:IsAvailableForPickup()
				end,
				function()
					return true
				end,
				function()
					return component:Pickup(player)
				end
			)
			expect(allowed).to.equal(true)
			expect(pickupCalls).to.equal(1)
			component.Instance:Destroy()
		end)
	end)
end
