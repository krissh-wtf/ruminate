--//Services
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

--//Components
local Components = script:WaitForChild("Components")

local CameraComponent = require(Components:WaitForChild("Camera"))
local FootstepsComponent = require(Components:WaitForChild("Footsteps"))
local LookAngleComponent = require(Components:WaitForChild("LookAngle"))

--//Module
local FPSSysClient = {
	BindTag = "RealismHook";
}

-- Humanoid Added
function FPSSysClient:OnHumanoidAdded(humanoid)
	
	if humanoid:IsA("Humanoid") then
		LookAngleComponent:MountLookAngle(humanoid)
		FootstepsComponent:MountMaterialSounds(humanoid)
		
	end
	
end

-- Init FPSys
function FPSSysClient:Start()
	
	assert(not _G.DefineRealismClient, "FPSSys can only be started once on the client!")
	_G.DefineRealismClient = true

	for _,humanoid in pairs(CollectionService:GetTagged(self.BindTag)) do
		self:OnHumanoidAdded(humanoid)
	end

	CollectionService:GetInstanceAddedSignal(self.BindTag):Connect(function(humanoid)
		self:OnHumanoidAdded(humanoid)
	end)

	CameraComponent:Start()
	LookAngleComponent:Start()

end

return FPSSysClient
