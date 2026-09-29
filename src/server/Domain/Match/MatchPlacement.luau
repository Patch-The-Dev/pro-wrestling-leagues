--!strict

local CharacterAdapter = require(script.Parent.Parent.Parent.Adapters.CharacterAdapter)

type Entry = {
	Player: Player,
	Character: Model,
	ReturnCFrame: CFrame,
}

local MatchPlacement = {}
MatchPlacement.__index = MatchPlacement

export type MatchPlacement = typeof(setmetatable(
	{} :: {
		_entries: { Entry },
		_spawns: { CFrame },
	},
	{} :: typeof(MatchPlacement)
))

function MatchPlacement.new(players: { Player }, spawns: { CFrame }): MatchPlacement?
	if #spawns < #players then
		return nil
	end

	local entries: { Entry } = {}
	for _, player in players do
		local character = player.Character
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		if character == nil or root == nil or not root:IsA("BasePart") then
			return nil
		end
		table.insert(entries, {
			Player = player,
			Character = character,
			ReturnCFrame = character:GetPivot(),
		})
	end

	return setmetatable({ _entries = entries, _spawns = table.clone(spawns) }, MatchPlacement)
end

function MatchPlacement:Restore()
	for _, entry in self._entries do
		if entry.Player.Character == entry.Character then
			CharacterAdapter.PlaceAt(entry.Character, entry.ReturnCFrame)
		end
	end
end

function MatchPlacement:Place(): boolean
	for index, entry in self._entries do
		if
			entry.Player.Character ~= entry.Character
			or not CharacterAdapter.PlaceAt(entry.Character, self._spawns[index])
		then
			self:Restore()
			return false
		end
	end
	return true
end

return MatchPlacement
