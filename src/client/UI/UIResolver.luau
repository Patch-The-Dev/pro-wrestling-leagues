--!strict

local Players = game:GetService("Players")

local UIResolver = {}

function UIResolver.Find(path: { string }): Instance?
	local current: Instance? = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	for _, name in path do
		if current == nil then
			return nil
		end
		current = current:FindFirstChild(name)
	end
	return current
end

function UIResolver.SetText(path: { string }, text: string)
	local instance = UIResolver.Find(path)
	if instance ~= nil and instance:IsA("TextLabel") then
		instance.Text = text
		return
	end
	if instance ~= nil and instance:IsA("TextButton") then
		instance.Text = text
		return
	end
	if instance ~= nil and instance:IsA("TextBox") then
		instance.Text = text
	end
end

return UIResolver
