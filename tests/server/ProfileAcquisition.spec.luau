--!strict

return function()
	local Players = game:GetService("Players")
	local ServerScriptService = game:GetService("ServerScriptService")
	local Repository = require(ServerScriptService.Server.Persistence.PlayerRepository)
	local Template = require(ServerScriptService.Server.Persistence.ProfileTemplate)
	local function copy(value)
		if type(value) ~= "table" then
			return value
		end
		local result = {}
		for key, item in value do
			result[key] = copy(item)
		end
		return result
	end
	describe("Profile acquisition lifecycle", function()
		for _, step in { "AddUserId", "Reconcile", "Connect" } do
			it(`releases an acquired profile when {step} fails`, function()
				local ends = 0
				local player = { UserId = 99, Parent = Players, DisplayName = "Test" } :: any
				local profile = {
					Data = copy(Template),
					AddUserId = function()
						if step == "AddUserId" then
							error("initialization failed")
						end
					end,
					Reconcile = function()
						if step == "Reconcile" then
							error("initialization failed")
						end
					end,
					IsActive = function()
						return ends == 0
					end,
					EndSession = function()
						ends += 1
					end,
					OnSessionEnd = {
						Connect = function()
							if step == "Connect" then
								error("subscription failed")
							end
						end,
					},
				}
				local repository = Repository.new({
					StartSessionAsync = function()
						return profile
					end,
				} :: any)
				expect(repository:LoadAsync(player):await()).to.equal(false)
				expect(ends).to.equal(1)
				expect(repository:Get(player)).to.equal(nil)
			end)
		end
		it("cancels an acquisition during shutdown and releases a late session", function()
			local started = false
			local ends = 0
			local player = { UserId = 99, Parent = Players, DisplayName = "Test" } :: any
			local repository = Repository.new({
				StartSessionAsync = function(_, _, options)
					started = true
					while not options.Cancel() do
						task.wait()
					end
					return {
						Data = copy(Template),
						AddUserId = function() end,
						Reconcile = function() end,
						IsActive = function()
							return ends == 0
						end,
						EndSession = function()
							ends += 1
						end,
					}
				end,
			} :: any)
			local load = repository:LoadAsync(player)
			local deadline = os.clock() + 3
			while not started and os.clock() < deadline do
				task.wait()
			end
			assert(started, "The profile acquisition did not start")
			repository:BeginClose()
			expect(load:await()).to.equal(false)
			expect(ends).to.equal(1)
			expect(repository:Get(player)).to.equal(nil)
			expect(repository:LoadAsync(player):await()).to.equal(false)
		end)
	end)
end
