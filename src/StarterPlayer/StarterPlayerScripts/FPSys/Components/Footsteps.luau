--//Services
local RunService = game:GetService("RunService");

--//Paths
local MainModule = script.Parent.Parent

--//RbxUtil
local RbxUtil = MainModule:WaitForChild('RbxUtil')

local Util = require(RbxUtil:WaitForChild("Util"))

--//Imported Settings
local RealismConfig = require(MainModule.Configs.RealismConfig);

--//Variables
local XZ_VECTOR3 = Vector3.new(1, 0, 1)

--//Module
local FootstepsComponent = {}

-- Mounts the custom material walking sounds into the provided
-- humanoid. This mounting assumes the HumanoidRootPart is the
-- part that will be storing the character's "Running" sound.

function FootstepsComponent:MountMaterialSounds(humanoid)
	local character = humanoid.Parent
	local rootPart = character and character:WaitForChild("HumanoidRootPart", 10)

	if not (rootPart and rootPart:IsA("BasePart")) then
		return
	end

	Util:PromiseChild(rootPart, "Running", function (running)
		if not running:IsA("Sound") then
			return
		end
		
		for key, value in pairs(RealismConfig) do
			self[key] = value
		end

		local oldPitch = Instance.new("NumberValue")
		oldPitch.Name = "OldPitch"
		oldPitch.Parent = running
		oldPitch.Value = 1

		local function onStateChanged(old, new)			
			if new.Name:find("Running") then
				while humanoid:GetState() == new do
					local hipHeight = humanoid.HipHeight

					if humanoid.RigType.Name == "R6" then
						hipHeight = 2.8
					end

					local scale = hipHeight / 3
					local speed = (rootPart.Velocity * XZ_VECTOR3).Magnitude

					local volume = ((speed - 4) / 12) * scale
					running.Volume = math.clamp(volume, 0, 1)

					local pitch = oldPitch.Value / ((scale * 15) / speed)
					running.Pitch = pitch

					RunService.Heartbeat:Wait()
				end	
			end
		end

		local function updateRunningSoundId()
			local soundId = self.Sounds.Concrete
			local material = humanoid.FloorMaterial.Name

			if not self.Sounds[material] then
				material = self.MaterialMap[material]
			end

			if self.Sounds[material] then
				soundId = self.Sounds[material]
			end

			running.SoundId = "rbxassetid://" .. soundId
		end

		local floorListener = humanoid:GetPropertyChangedSignal("FloorMaterial")
		floorListener:Connect(updateRunningSoundId)

		running.EmitterSize = 1
		running.MaxDistance = 50

		updateRunningSoundId()
		humanoid.StateChanged:Connect(onStateChanged)

		onStateChanged(nil, Enum.HumanoidStateType.Running)
	end)
end

return FootstepsComponent
