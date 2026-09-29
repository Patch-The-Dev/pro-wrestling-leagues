--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local RecoveryScheduler = require(ServerScriptService.Server.Domain.Combat.RecoveryScheduler)

return function()
	describe("RecoveryScheduler", function()
		it("ignores a timer after the combatant is invalidated", function()
			local player = {} :: any
			local state = "Stunned"
			local combatant = {
				Player = player,
				GetState = function()
					return state
				end,
				SetState = function(_, nextState)
					state = nextState
				end,
			} :: any
			local scheduler = RecoveryScheduler.new(function(candidate)
				return if candidate == player then combatant else nil
			end)

			scheduler:ScheduleState(combatant, "Stunned", "Roaming", 0.05)
			scheduler:Invalidate(combatant)
			task.wait(0.1)
			expect(state).to.equal("Stunned")
			scheduler:Destroy()
		end)

		it("ignores a timer after a replacement combatant takes ownership", function()
			local player = {} :: any
			local state = "Stunned"
			local combatant = {
				Player = player,
				GetState = function()
					return state
				end,
				SetState = function(_, nextState)
					state = nextState
				end,
			} :: any
			local current = combatant
			local scheduler = RecoveryScheduler.new(function(candidate)
				return if candidate == player then current else nil
			end)

			scheduler:ScheduleState(combatant, "Stunned", "Roaming", 0.05)
			current = {} :: any
			task.wait(0.1)
			expect(state).to.equal("Stunned")
			scheduler:Destroy()
		end)
	end)
end
