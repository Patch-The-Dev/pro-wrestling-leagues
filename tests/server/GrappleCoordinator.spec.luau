--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local GrappleCoordinator = require(ServerScriptService.Server.Domain.Combat.GrappleCoordinator)

return function()
	describe("GrappleCoordinator", function()
		it("cancels damage if the target is no longer valid at resolution", function()
			local attacker = { UserId = 10 } :: any
			local victim = { UserId = 20 } :: any
			local attackerState = "Grappling"
			local victimState = "Stunned"
			local damageCount = 0
			local eventCount = 0
			local destroyed = false
			local targetValid = false
			local attackerCombatant = {
				GetState = function()
					return attackerState
				end,
				SetState = function(_, state)
					attackerState = state
				end,
				AddFinisher = function() end,
			} :: any
			local victimCombatant = {
				GetState = function()
					return victimState
				end,
				SetState = function(_, state)
					victimState = state
				end,
				ApplyDamage = function()
					damageCount += 1
				end,
			} :: any
			local coordinator = GrappleCoordinator.new(
				function(player)
					return if player == attacker then attackerCombatant else victimCombatant
				end,
				function()
					return targetValid
				end,
				{
					ScheduleState = function() end,
					ScheduleVictim = function() end,
				} :: any,
				function()
					eventCount += 1
				end,
				function() end
			)
			local session = {
				Id = "out-of-range",
				Initiator = attacker,
				Victim = victim,
				Destroy = function()
					destroyed = true
				end,
			} :: any
			coordinator._sessions[session.Id] = session
			coordinator:_resolve(
				session,
				attackerCombatant,
				victimCombatant,
				false,
				"Grapple",
				"Bodyslam",
				{
					HealthDamage = 10,
					PoiseDamage = 0,
					AttackerFinisher = 0,
					VictimFinisher = 0,
					StunSeconds = 0.5,
				},
				1,
				false
			)
			expect(damageCount).to.equal(0)
			expect(eventCount).to.equal(0)
			expect(attackerState).to.equal("Roaming")
			expect(victimState).to.equal("Roaming")
			expect(destroyed).to.equal(true)

			-- The same resolver must still apply a valid grapple exactly once.
			targetValid = true
			attackerState = "Grappling"
			victimState = "Stunned"
			destroyed = false
			local validSession = {
				Id = "valid",
				Initiator = attacker,
				Victim = victim,
				Destroy = function()
					destroyed = true
				end,
			} :: any
			coordinator._sessions[validSession.Id] = validSession
			coordinator:_resolve(
				validSession,
				attackerCombatant,
				victimCombatant,
				false,
				"Grapple",
				"Bodyslam",
				{
					HealthDamage = 10,
					PoiseDamage = 0,
					AttackerFinisher = 0,
					VictimFinisher = 0,
					StunSeconds = 0.5,
				},
				1,
				false
			)
			expect(damageCount).to.equal(1)
			expect(eventCount).to.equal(2)
			expect(destroyed).to.equal(true)
			coordinator:Destroy()
		end)
	end)
end
