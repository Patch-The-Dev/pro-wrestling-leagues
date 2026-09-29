--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PlayerDeparture = require(ServerScriptService.Server.Persistence.PlayerDeparture)
local Promise = require(ReplicatedStorage.Packages.Promise)

return function()
	describe("PlayerDeparture", function()
		it("holds profile release until a yielding match settlement finishes", function()
			local player = { UserId = 22 } :: any
			local entered = Instance.new("BindableEvent")
			local completed = Instance.new("BindableEvent")
			local released = false
			local done = false
			local resume: (() -> ())? = nil
			local gate = Promise.new(function(resolve)
				resume = resolve
			end)
			local departure = PlayerDeparture.new({
				Release = function()
					released = true
				end,
				ReleaseAll = function() end,
			} :: any)
			departure:SetBeforeRelease(function()
				entered:Fire()
				gate:await()
			end)
			task.defer(function()
				departure:Release(player)
				done = true
				completed:Fire()
			end)
			entered.Event:Wait()
			expect(released).to.equal(false)
			assert(resume ~= nil, "Departure gate was not created")
			resume()
			if not done then
				completed.Event:Wait()
			end
			expect(released).to.equal(true)
			departure:Destroy()
			entered:Destroy()
			completed:Destroy()
		end)

		it("still releases a profile if the settlement callback fails", function()
			local released = false
			local departure = PlayerDeparture.new({
				Release = function()
					released = true
				end,
				ReleaseAll = function() end,
			} :: any)
			departure:SetBeforeRelease(function()
				error("settlement failure")
			end)
			departure:Release({ UserId = 22 } :: any)
			expect(released).to.equal(true)
			departure:Destroy()
		end)
	end)
end
