--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CombatConfig = require(ReplicatedStorage.Shared.Config.CombatConfig)
local PinSession = require(ServerScriptService.Server.Domain.Combat.PinSession)

return function()
	describe("PinSession", function()
		local pinner = {} :: any
		local victim = {} :: any

		it("accepts only the victim during the active input window", function()
			local session = PinSession.new("pin", pinner, victim)
			local targetTime = session:NextPrompt()
			expect(targetTime ~= nil).to.equal(true)
			expect(session:SubmitInput(victim)).to.equal(false)
			expect(session:SubmitInput(pinner)).to.equal(false)

			session._targetTime = workspace:GetServerTimeNow()
			expect(session:SubmitInput(victim)).to.equal(true)
			expect(session:SubmitInput(victim)).to.equal(false)
			expect(session:DidEscape()).to.equal(true)
			expect(session:IsFinished()).to.equal(true)
			session:Destroy()
		end)

		it("rejects late input and finishes after the configured misses", function()
			local session = PinSession.new("pin", pinner, victim)
			for index = 1, CombatConfig.Pin.MaximumMisses do
				expect(session:NextPrompt() ~= nil).to.equal(true)
				session._targetTime = workspace:GetServerTimeNow()
					- CombatConfig.Pin.InputWindowSeconds
					- 0.1
				expect(session:SubmitInput(victim)).to.equal(false)
				session:ExpirePrompt()
				expect(session:GetMisses()).to.equal(index)
			end
			expect(session:IsFinished()).to.equal(true)
			expect(session:DidEscape()).to.equal(false)
			expect(session:NextPrompt()).to.equal(nil)
			session:Destroy()
		end)

		it("allows bounded server-measured latency only after the target time", function()
			local session = PinSession.new("pin", pinner, victim, 0.1)
			session:NextPrompt()
			session._targetTime = workspace:GetServerTimeNow()
				- CombatConfig.Pin.InputWindowSeconds
				- 0.05
			expect(session:SubmitInput(victim)).to.equal(true)
			session:Destroy()

			local capped = PinSession.new("pin", pinner, victim, 1)
			capped:NextPrompt()
			capped._targetTime = workspace:GetServerTimeNow()
				- CombatConfig.Pin.InputWindowSeconds
				- CombatConfig.Pin.MaximumOneWayLatencyCompensationSeconds
				- 0.05
			expect(capped:SubmitInput(victim)).to.equal(false)
			capped:Destroy()
		end)
	end)
end
