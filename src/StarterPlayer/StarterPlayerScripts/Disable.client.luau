--// Services
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

--// Local Variables
local player = Players.LocalPlayer
local soundsFolder = Workspace:FindFirstChild("Sound")

--// First person
local Players = game:GetService("Players")
Players.LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson

--// Disable Core GUI
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)

--// Disable Reset Button
local function disableReset()
	local function tryDisable()
		local success = pcall(function()
			StarterGui:SetCore("ResetButtonCallback", false)
		end)
		return success
	end

	if not tryDisable() then
		task.spawn(function()
			while not tryDisable() do
				task.wait(0.5)
			end
		end)
	end
end

--// Whitelisted Sound Check
local function isWhitelisted(sound: Sound)
	return soundsFolder and sound:IsDescendantOf(soundsFolder)
end

--// Mute Non-Whitelisted Sounds
local function muteSounds()
	for _, obj in Workspace:GetDescendants() do
		if obj:IsA("Sound") and not isWhitelisted(obj) then
			obj.Volume = 0
		end
	end
end

--// Configure Sound Environment
SoundService.AmbientReverb = Enum.ReverbType.Hallway

--// Character Setup
local function setupCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid")

	-- Remove force field
	local forceField = character:FindFirstChildOfClass("ForceField")
	if forceField then forceField:Destroy() end

	-- Configure humanoid properties
	humanoid.WalkSpeed = 8
	humanoid.JumpHeight = 0
	humanoid.JumpPower = 0
	humanoid.BreakJointsOnDeath = false

	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)

end

--// Initial Setup
disableReset()
muteSounds()
if player.Character then setupCharacter(player.Character) end

--// Event Listeners
player.CharacterAdded:Connect(function(char)
	setupCharacter(char)
	disableReset()
	muteSounds()
end)

