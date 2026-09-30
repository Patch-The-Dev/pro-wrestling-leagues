--!strict

local Knit = require(script.Parent.Parent.KnitClient)

local ShopController = Knit.CreateController({
	Name = "ShopController",
})

function ShopController:KnitStart()
	self._economyService = Knit.GetService("EconomyService")
	self._dataController = Knit.GetController("DataController")
end

function ShopController:Purchase(itemId: string)
	return self._economyService:Purchase(itemId):andThen(function(success, reason)
		if success then
			self._dataController:Refresh()
		end
		return success, reason
	end)
end

return ShopController
