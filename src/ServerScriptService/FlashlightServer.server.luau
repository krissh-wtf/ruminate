local ReplicatedStorage = game:GetService("ReplicatedStorage")
local toggleEvent = ReplicatedStorage:WaitForChild("ToggleFlashlight")

toggleEvent.OnServerEvent:Connect(function(player, isOn)
	local character = player.Character
	if not character then return end

	local tool = character:FindFirstChildOfClass("Tool")
	if not tool or tool.Name ~= "Flashlight" then return end

	local handle = tool:FindFirstChild("Handle")
	if not handle then return end

	local light = handle:FindFirstChild("SurfaceLight")
	local sound = handle:FindFirstChild("ToggleSound")
	if not light then return end

	light.Enabled = not light.Enabled
	if sound then
		sound:Play()
	end
end)