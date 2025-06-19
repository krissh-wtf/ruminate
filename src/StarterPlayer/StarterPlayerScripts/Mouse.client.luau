local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
UserInputService.MouseIconEnabled = false

local function createCrosshair()
	local gui = Instance.new("ScreenGui")
	gui.Name = "TransparentCrosshairGui"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local mainCircle = Instance.new("Frame")
	mainCircle.Name = "Crosshair"
	mainCircle.Size = UDim2.new(0, 4, 0, 4)
	mainCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
	mainCircle.AnchorPoint = Vector2.new(0.5, 0.5)
	mainCircle.BackgroundColor3 = Color3.new(1, 1, 1)
	mainCircle.BackgroundTransparency = 0.1
	mainCircle.BorderSizePixel = 0
	mainCircle.ZIndex = 2
	mainCircle.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = mainCircle

	local glow = Instance.new("Frame")
	glow.Size = UDim2.new(0, 10, 0, 10)
	glow.Position = UDim2.new(0.5, 0, 0.5, 0)
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.BackgroundColor3 = Color3.new(1, 1, 1)
	glow.BackgroundTransparency = 0.9
	glow.BorderSizePixel = 0
	glow.ZIndex = 1
	glow.Parent = gui

	local glowCorner = Instance.new("UICorner")
	glowCorner.CornerRadius = UDim.new(1, 0)
	glowCorner.Parent = glow

	local glowGradient = Instance.new("UIGradient")
	glowGradient.Transparency = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 1)
	}
	glowGradient.Parent = glow
end

createCrosshair()
