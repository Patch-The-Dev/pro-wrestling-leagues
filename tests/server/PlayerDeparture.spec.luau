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

		it("settles every loaded profile before the shutdown release", function()
			local first = { UserId = 11 } :: any
			local second = { UserId = 22 } :: any
			local loaded = { first, second }
			local callbacks = 0
			local releases = 0
			local releasedAll = false
			local done = false
			local resume: (() -> ())? = nil
			local gate = Promise.new(function(resolve)
				resume = resolve
			end)
			local departure = PlayerDeparture.new({
				GetLoadedPlayers = function()
					return table.clone(loaded)
				end,
				Release = function(_, player)
					releases += 1
					local index = table.find(loaded, player)
					if index ~= nil then
						table.remove(loaded, index)
					end
				end,
				ReleaseAll = function()
					releasedAll = true
				end,
			} :: any)
			departure:SetBeforeRelease(function()
				callbacks += 1
				gate:await()
			end)
			task.defer(function()
				departure:Release(first)
			end)
			local deadline = os.clock() + 3
			while callbacks < 1 and os.clock() < deadline do
				task.wait(0.02)
			end
			expect(callbacks).to.equal(1)
			task.defer(function()
				departure:ReleaseAll()
				done = true
			end)
			while callbacks < 2 and os.clock() < deadline do
				task.wait(0.02)
			end
			expect(callbacks).to.equal(2)
			expect(releases).to.equal(0)
			expect(releasedAll).to.equal(false)
			assert(resume ~= nil, "Shutdown settlement gate was not created")
			resume()
			while not done and os.clock() < deadline do
				task.wait(0.02)
			end
			expect(done).to.equal(true)
			expect(releases).to.equal(2)
			expect(releasedAll).to.equal(true)
			departure:Destroy()
		end)

		it("includes a profile that finishes loading during shutdown", function()
			local first = { UserId = 31 } :: any
			local second = { UserId = 32 } :: any
			local loaded = { first }
			local pendingLoad = true
			local callbacks = {}
			local released = {}
			local done = false
			local resumeFirst: (() -> ())? = nil
			local firstGate = Promise.new(function(resolve)
				resumeFirst = resolve
			end)
			local departure = PlayerDeparture.new({
				GetLoadedPlayers = function()
					return table.clone(loaded)
				end,
				Release = function(_, player)
					released[player] = true
					local index = table.find(loaded, player)
					if index ~= nil then
						table.remove(loaded, index)
					end
				end,
				ReleaseAll = function() end,
			} :: any)
			departure:SetBeforeRelease(function(player)
				callbacks[player] = true
				if player == first then
					firstGate:await()
				end
			end)
			local deadline = os.clock() + 3
			task.defer(function()
				departure:ReleaseAll(deadline, function()
					return pendingLoad
				end)
				done = true
			end)
			while not callbacks[first] and os.clock() < deadline do
				task.wait(0.02)
			end
			expect(callbacks[first]).to.equal(true)
			table.insert(loaded, second)
			pendingLoad = false
			while not callbacks[second] and os.clock() < deadline do
				task.wait(0.02)
			end
			expect(callbacks[second]).to.equal(true)
			expect(released[first]).to.equal(nil)
			assert(resumeFirst ~= nil, "First shutdown release gate was not created")
			resumeFirst()
			while not done and os.clock() < deadline do
				task.wait(0.02)
			end
			expect(done).to.equal(true)
			expect(released[first]).to.equal(true)
			expect(released[second]).to.equal(true)
			departure:Destroy()
		end)
	end)
end
