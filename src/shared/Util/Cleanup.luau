--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Implementation = require(ReplicatedStorage.Packages._Index["sleitnick_trove@1.8.0"].trove)

-- Keep the library's dynamic promise boundary here. Application state uses the
-- concrete interface below rather than propagating generic cleanup return types.
type PromiseHandle = {
	cancel: (self: any) -> (),
	getStatus: (self: any) -> string,
	finally: (self: any, callback: (...any) -> ...any) -> any,
}

export type Trove = {
	Add: (self: Trove, object: Implementation.Trackable, cleanupMethod: string?) -> (),
	AddPromise: (self: Trove, promise: PromiseHandle) -> (),
	Connect: (
		self: Trove,
		signal: RBXScriptSignal,
		callback: (...any) -> ()
	) -> RBXScriptConnection,
	Clean: (self: Trove) -> (),
	Destroy: (self: Trove) -> (),
}

local Cleanup = {}

function Cleanup.new(): Trove
	return (Implementation.new() :: unknown) :: Trove
end

return table.freeze(Cleanup)
