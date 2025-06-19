local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local flashlightEvent = ReplicatedStorage:WaitForChild("ToggleFlashlight")
local tool = script.Parent

tool.Equipped:Connect(function()
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.F then
			flashlightEvent:FireServer()
		end
	end)
end)
