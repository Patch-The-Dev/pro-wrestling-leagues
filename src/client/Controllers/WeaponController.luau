--!strict

local Knit = require(script.Parent.Parent.KnitClient)

local WeaponController = Knit.CreateController({
	Name = "WeaponController",
})

function WeaponController:KnitStart()
	self._service = Knit.GetService("WeaponService")
end

function WeaponController:Pickup(networkId: string)
	return self._service:RequestAction(networkId, "Pickup")
end

function WeaponController:Drop(networkId: string)
	return self._service:RequestAction(networkId, "Drop")
end

function WeaponController:Attack(networkId: string)
	return self._service:RequestAction(networkId, "Attack")
end

return WeaponController
