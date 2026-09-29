--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Trove = require(ReplicatedStorage.Packages.Trove)

local ArenaController = Knit.CreateController({
	Name = "ArenaController",
})

function ArenaController:KnitInit()
	self._trove = Trove.new()
end

function ArenaController:KnitStart()
	self._turnbuckleService = Knit.GetService("TurnbuckleService")
	local input = Knit.GetController("InputController")
	self._trove:Connect(input.TurnbuckleRequested, function()
		self._turnbuckleService:Toggle():catch(function(err)
			warn(`Turnbuckle request failed: {tostring(err)}`)
		end)
	end)
end

return ArenaController
