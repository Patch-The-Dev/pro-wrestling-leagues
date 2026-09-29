--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local StrikeResolver = require(ServerScriptService.Server.Application.StrikeResolver)

return function()
	describe("StrikeResolver", function()
		local attacker = { UserId = 10 } :: any
		local victim = { UserId = 20 } :: any

		local function setup()
			local state = "Roaming"
			local damageCount = 0
			local startedCount = 0
			local resolvedCount = 0
			local targetInRange = true
			local matchActive = true
			local attackerCombatant = {
				GetState = function()
					return state
				end,
				CanSetState = function()
					return true
				end,
				SetState = function(_, nextState)
					state = nextState
					return true
				end,
				AddFinisher = function() end,
			} :: any
			local victimCombatant = {
				GetState = function()
					return "Roaming"
				end,
				ApplyDamage = function()
					damageCount += 1
				end,
			} :: any
			local resolver = StrikeResolver.new({
				DataSource = {
					Get = function()
						return { Wrestler = { Moves = { Attack1 = "Left Punch" } } } :: any
					end,
				},
				Budget = {
					PeekAttackSequence = function()
						return 1
					end,
					CommitAttackSequence = function() end,
					Commit = function()
						return true
					end,
				} :: any,
				Recovery = {
					ScheduleState = function() end,
					ScheduleVictim = function() end,
				} :: any,
				GetCombatant = function(player)
					return if player == attacker then attackerCombatant else victimCombatant
				end,
				FindTarget = function()
					return if targetInRange then victim else nil
				end,
				CanResolve = function()
					return matchActive
				end,
				EmitStarted = function()
					startedCount += 1
				end,
				EmitToParticipants = function()
					resolvedCount += 1
				end,
			})
			return resolver,
				attackerCombatant,
				function()
					return damageCount, startedCount, resolvedCount
				end,
				function(inRange)
					targetInRange = inRange
				end,
				function(active)
					matchActive = active
				end
		end

		it("applies damage after the server-owned impact delay", function()
			local resolver, combatant, counts = setup()
			expect(resolver:Request(attacker, "Attack", combatant)).to.equal(true)
			local damage, started, resolved = counts()
			expect(damage).to.equal(0)
			expect(started).to.equal(1)
			expect(resolved).to.equal(0)
			task.wait(0.6)
			damage, _, resolved = counts()
			expect(damage).to.equal(1)
			expect(resolved).to.equal(1)
			resolver:Destroy()
		end)

		it("misses when the target leaves range before impact", function()
			local resolver, combatant, counts, setInRange = setup()
			expect(resolver:Request(attacker, "Attack", combatant)).to.equal(true)
			setInRange(false)
			task.wait(0.6)
			local damage, _, resolved = counts()
			expect(damage).to.equal(0)
			expect(resolved).to.equal(1)
			resolver:Destroy()
		end)

		it("cancels a pending impact when the match closes", function()
			local resolver, combatant, counts, _, setMatchActive = setup()
			expect(resolver:Request(attacker, "Attack", combatant)).to.equal(true)
			setMatchActive(false)
			task.wait(0.6)
			local damage, _, resolved = counts()
			expect(damage).to.equal(0)
			expect(resolved).to.equal(0)
			resolver:Destroy()
		end)
	end)
end
