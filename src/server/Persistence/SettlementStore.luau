--!strict

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local Config = require(script.Parent.Parent.Config.PersistenceConfig)
local Types = require(script.Parent.SettlementTypes)

local SettlementStore = {}

local function copy(value: unknown): unknown
	if type(value) ~= "table" then
		return value
	end
	local result: { [string | number]: unknown } = {}
	for key, item in value :: { [string | number]: unknown } do
		result[key] = copy(item)
	end
	return result
end

function SettlementStore.new(): Types.Store
	if not RunService:IsStudio() or not Config.UseMockStoreInStudio then
		return (DataStoreService:GetDataStore(Config.SettlementStoreName) :: unknown) :: Types.Store
	end
	-- Studio follows the same update/list contract without accessing live player data.
	local values: { [string]: unknown } = {}
	local store: Types.Store = {
		GetAsync = function(_, key)
			return copy(values[key])
		end,
		UpdateAsync = function(_, key, transform)
			local updated = transform(copy(values[key]))
			if updated ~= nil then
				values[key] = copy(updated)
			end
			return copy(updated)
		end,
		RemoveAsync = function(_, key)
			local old = values[key]
			values[key] = nil
			return copy(old)
		end,
		ListKeysAsync = function(_, prefix, pageSize)
			local keys: { { KeyName: string } } = {}
			for key in values do
				if string.sub(key, 1, #prefix) == prefix then
					table.insert(keys, { KeyName = key })
				end
			end
			table.sort(keys, function(a, b)
				return a.KeyName < b.KeyName
			end)
			local index = 1
			local pages: Types.Pages
			pages = {
				IsFinished = #keys <= pageSize,
				GetCurrentPage = function()
					local page: { { KeyName: string } } = {}
					for offset = index, math.min(index + pageSize - 1, #keys) do
						table.insert(page, keys[offset])
					end
					return page
				end,
				AdvanceToNextPageAsync = function()
					index += pageSize
					pages.IsFinished = index + pageSize > #keys
				end,
			}
			return pages
		end,
	}
	return store
end

return table.freeze(SettlementStore)
