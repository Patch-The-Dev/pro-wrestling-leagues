--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ArenaRegistry = require(ServerScriptService.Server.Components.ArenaRegistry)

local function createArena(): Model
	local arena = Instance.new("Model")
	arena.Name = "TestRing"
	arena:SetAttribute("ArenaId", "TestRing")
	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	spawns.Parent = arena
	for index = 1, 2 do
		local spawn = Instance.new("Part")
		spawn.Name = tostring(index)
		spawn.Parent = spawns
	end
	arena.Parent = workspace
	return arena
end

return function()
	describe("ArenaRegistry", function()
		it("keeps a match reservation while its arena is replaced", function()
			local registry = ArenaRegistry.new()
			local original = createArena()
			registry:Add(original)
			expect(registry:Reserve("first-match", 2, "TestRing")).to.equal("TestRing")

			registry:Remove(original)
			original:Destroy()
			local replacement = createArena()
			registry:Add(replacement)
			expect(registry:Reserve("second-match", 2, "TestRing")).to.equal(nil)

			registry:Release("first-match")
			expect(registry:Reserve("second-match", 2, "TestRing")).to.equal("TestRing")
			registry:Destroy()
			replacement:Destroy()
		end)
	end)
end
