--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

Knit.AddServicesDeep(script.Services)

Knit.Start():catch(function(err)
	error(`Server startup failed: {tostring(err)}`)
end)
