--!strict

local Knit = require(script.KnitClient)

Knit.AddControllersDeep(script.Controllers)

Knit.Start():catch(function(err)
	error(`Client startup failed: {tostring(err)}`)
end)
