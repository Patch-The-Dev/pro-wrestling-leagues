--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local MatchPlacement = require(ServerScriptService.Server.Domain.Match.MatchPlacement)

return function()
	describe("MatchPlacement", function()
		local function makeCharacter(position: Vector3): Model
			local character = Instance.new("Model")
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Parent = character
			character:PivotTo(CFrame.new(position))
			return character
		end

		it("restores original positions after a match", function()
			local firstCharacter = makeCharacter(Vector3.new(10, 5, 0))
			local secondCharacter = makeCharacter(Vector3.new(20, 5, 0))
			local first = { Character = firstCharacter } :: any
			local second = { Character = secondCharacter } :: any
			local placement = MatchPlacement.new({ first, second }, {
				CFrame.new(100, 5, 0),
				CFrame.new(110, 5, 0),
			})
			assert(placement ~= nil, "Expected valid match placement")
			expect(placement:Place()).to.equal(true)
			expect(firstCharacter:GetPivot().Position.X).to.equal(100)
			placement:Restore()
			expect(firstCharacter:GetPivot().Position.X).to.equal(10)
			expect(secondCharacter:GetPivot().Position.X).to.equal(20)
			firstCharacter:Destroy()
			secondCharacter:Destroy()
		end)

		it("rolls back partial placement and never moves a respawned character", function()
			local firstCharacter = makeCharacter(Vector3.new(10, 5, 0))
			local oldCharacter = makeCharacter(Vector3.new(20, 5, 0))
			local newCharacter = makeCharacter(Vector3.new(30, 5, 0))
			local first = { Character = firstCharacter } :: any
			local second = { Character = oldCharacter } :: any
			local spawns = { CFrame.new(100, 5, 0), CFrame.new(110, 5, 0) }
			local placement = MatchPlacement.new({ first, second }, spawns)
			assert(placement ~= nil, "Expected valid match placement")
			second.Character = newCharacter
			expect(placement:Place()).to.equal(false)
			expect(firstCharacter:GetPivot().Position.X).to.equal(10)
			expect(newCharacter:GetPivot().Position.X).to.equal(30)
			firstCharacter:Destroy()
			oldCharacter:Destroy()
			newCharacter:Destroy()
		end)
	end)
end
