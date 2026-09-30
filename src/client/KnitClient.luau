--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Knit selects this implementation at runtime; the cast gives the analyzer
-- the client API when checking files under StarterPlayerScripts.
local Knit =
	require(ReplicatedStorage.Packages.Knit) :: typeof(require(ReplicatedStorage.Packages.Knit.KnitClient))

return Knit
