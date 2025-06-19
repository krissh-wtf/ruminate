--//Services
local Players = game:GetService("Players")
local LightingService = game:GetService("Lighting")
local UserGameSettings = UserSettings():GetService("UserGameSettings")
local Workspace = game:GetService("Workspace");
local RunService = game:GetService("RunService");
local UserInputService = game:GetService("UserInputService");

--//Local Variables
local LocalPlayer = Players.LocalPlayer;
local Camera = Workspace.CurrentCamera;

--//Paths
local MainModule = script.Parent.Parent

--//Instances
local MotionBlur: BlurEffect = Instance.new("BlurEffect")
MotionBlur.Name = "MotionBlur"
MotionBlur.Parent = LightingService

--//RbxUtil
local RbxUtil = MainModule:WaitForChild('RbxUtil')

local Spring = require(RbxUtil:WaitForChild("Spring"))
local Maid = require(RbxUtil:WaitForChild("Maid"))

--//Sessions
local RuntimeMaid = Maid.new();

--//Imported Settings
local CameraConfig = require(MainModule.Configs.CameraConfig);

local DriftMin = CameraConfig.DriftMin
local DriftMax = CameraConfig.DriftMax
local BaseMult = CameraConfig.BaseMult

local MouseIcon = CameraConfig.MouseIcon

local BlurMult = CameraConfig.BlurMult
local MaxBlur = CameraConfig.MaxBlur

local TiltSpeed = CameraConfig.TiltSpeed
local TiltAngle = CameraConfig.TiltAngle
local TiltDamper = CameraConfig.TiltDamper

local LookSwaySpeed = CameraConfig.LookSwaySpeed
local LookSwayDamper = CameraConfig.LookSwayDamper
local LookSwayMaxAngle = CameraConfig.LookSwayMaxAngle
local LookSwayMouseDamper = CameraConfig.LookSwayMouseDamper

local LandEffectSpeed = CameraConfig.LandEffectSpeed
local LandEffectDamper = CameraConfig.LandEffectDamper
local LandEffectVelocity = CameraConfig.LandEffectVelocity

local BreathingScale = CameraConfig.BreathingScale
local BreathingSpeed = CameraConfig.BreathingSpeed

--//Variables
local XZ_VECTOR3 = Vector3.new(1, 0, 1)

local Drift = 0
local CameraTick = 0
local Offstates = {"Freefall"}
local MouseDelta = nil

--//Math
local abs = math.abs
local clamp = math.clamp

--//Local Types
local MouseDelta : Vector2

--//Module
local FpsCamera = 
	{
		HeadMirrors = {};

		HeadAttachments = 
		{
			FaceCenterAttachment = true;
			FaceFrontAttachment = true;
			HairAttachment = true;
			HatAttachment = true;
		};

		InvalidRotationStates =
		{
			Swimming = true; 
			Climbing = true;
			Dead = true;
		};
	}


-- Refresh and set local variables
function FpsCamera:RefreshCharacterVariables()
	self.Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait();
	self.RootPart = self.Character:WaitForChild("HumanoidRootPart");
	self.Humanoid = self.Character:WaitForChild("Humanoid");
	self.Head = self.Character:WaitForChild("Head");
end;

-- Writes a warning to the output
-- in context of the FpsCamera.

function FpsCamera:Warn(...)
	warn("[FpsCamera]", ...)
end

-- Connects a self-function by  
-- name to the provided event.

function FpsCamera:Connect(funcName, event)
	return event:Connect(function (...)
		self[funcName](self, ...)
	end)
end

-- Returns true if the client is
-- currently in first person.

function FpsCamera:IsInFirstPerson()
	local camera = workspace.CurrentCamera

	if camera then
		if camera.CameraType.Name == "Scriptable" then
			return false
		end

		local focus = camera.Focus.Position
		local origin = camera.CFrame.Position

		return (focus - origin).Magnitude <= 1
	end

	return false
end

-- Returns the subject position the FpsCamera
-- wants Roblox's camera to be using right now.

function FpsCamera:GetSubjectPosition()
	if self:IsInFirstPerson() then
		local camera = workspace.CurrentCamera
		local subject = camera.CameraSubject

		if subject and subject:IsA("Humanoid") and subject.Health > 0 then
			local character = subject.Parent
			local head = character and character:FindFirstChild("Head")

			if head and head:IsA("BasePart") then
				local cf = head.CFrame
				local offset = cf * CFrame.new(0, (head.Size.Y / 1), 0)

				return offset.Position, cf.LookVector
			end
		end
	end

	return self:GetBaseSubjectPosition()
end

-- This is an overload function for TransparencyController:IsValidPartToModify(part)
-- You may call it directly if you'd like, as it does not have any external dependencies.

function FpsCamera:IsValidPartToModify(part)
	if part:FindFirstAncestorOfClass("Tool") then
		return false
	end

	if part:IsA("Decal") then
		part = part.Parent
	end

	if part and part:IsA("BasePart") then
		local accessory = part:FindFirstAncestorWhichIsA("Accoutrement")

		if accessory then
			if part.Name ~= "Handle" then
				local handle = accessory:FindFirstChild("Handle", true)

				if handle and handle:IsA("BasePart") then
					part = handle
				end
			end

			for _,child in pairs(part:GetChildren()) do
				if child:IsA("Attachment") then
					if self.HeadAttachments[child.Name] then
						return true
					end
				end
			end
		elseif part.Name == "Head" then
			local model = part.Parent
			local camera = workspace.CurrentCamera
			local humanoid = model and model:FindFirstChildOfClass("Humanoid")

			if humanoid and camera.CameraSubject == humanoid then
				return true
			end
		end
	end

	return false
end

-- Overloads BaseCamera:GetSubjectPosition() with
-- the GetSubjectPosition function of the FpsCamera.

function FpsCamera:MountBaseCamera(BaseCamera)
	local base = BaseCamera.GetSubjectPosition
	self.GetBaseSubjectPosition = base

	if base then
		BaseCamera.GetBaseSubjectPosition = base
		BaseCamera.GetSubjectPosition = self.GetSubjectPosition
	else
		self:Warn("MountBaseCamera - Could not find BaseCamera:GetSubjectPosition()!")
	end
end

-- This is an overload function for TransparencyController:Update()
-- Do not call directly, or it will throw an assertion!

function FpsCamera:UpdateTransparency(...)
	assert(self ~= FpsCamera)
	self:BaseUpdate(...)

	if self.ForceRefresh then
		self.ForceRefresh = false

		if self.SetSubject then
			local camera = workspace.CurrentCamera
			self:SetSubject(camera.CameraSubject)
		end
	end
end

-- This is an overloaded function for TransparencyController:SetupTransparency(character)
-- Do not call directly, or it will throw an assertion!

function FpsCamera:SetupTransparency(character, ...)
	assert(self ~= FpsCamera)
	self:BaseSetupTransparency(character, ...)

	if self.AttachmentListener then
		self.AttachmentListener:Disconnect()
	end

	self.AttachmentListener = character.DescendantAdded:Connect(function (obj)
		if obj:IsA("Attachment") and self.HeadAttachments[obj.Name] then
			if typeof(self.cachedParts) == "table" then
				self.cachedParts[obj.Parent] = true
			end

			if self.transparencyDirty ~= nil then
				self.transparencyDirty = true
			end
		end
	end)
end


-- Overloads functions in Roblox's TransparencyController 
-- module with replacement functions in the FpsCamera.

function FpsCamera:MountTransparency(Transparency)
	local baseUpdate = Transparency.Update

	if baseUpdate then
		Transparency.BaseUpdate = baseUpdate
		Transparency.Update = self.UpdateTransparency
	else
		self:Warn("MountTransparency - Could not find Transparency:Update()!")
	end

	if Transparency.IsValidPartToModify then
		Transparency.IsValidPartToModify = self.IsValidPartToModify
		Transparency.HeadAttachments = self.HeadAttachments
		Transparency.ForceRefresh = true
	else
		self:Warn("MountTransparency - Could not find Transparency:IsValidPartToModify(part)!")
	end

	if Transparency.SetupTransparency then
		Transparency.BaseSetupTransparency = Transparency.SetupTransparency
		Transparency.SetupTransparency = self.SetupTransparency
	else
		self:Warn("MountTransparency - Could not find Transparency:SetupTransparency(character)!")
	end
end

-- Returns the current angle being used
-- by Roblox's shadow mapping system.

function FpsCamera:GetShadowAngle()
	local angle = LightingService:GetSunDirection()

	if angle.Y < -0.3 then
		-- Use the moon's angle instead.
		angle = LightingService:GetMoonDirection()
	end

	return angle
end

-- Forces a copy object to mirror the value of
-- a property on the provided base object.

function FpsCamera:MirrorProperty(base, copy, prop)
	base:GetPropertyChangedSignal(prop):Connect(function ()
		copy[prop] = base[prop]
	end)
end

-- Creates a lazy object-mirror for the provided part.
-- This is used to make the Head visible in first person.

function FpsCamera:AddHeadMirror(desc)
	if desc:IsA("BasePart") and self:IsValidPartToModify(desc) then
		local mirror = desc:Clone()
		mirror:ClearAllChildren()

		mirror.Locked = true
		mirror.Anchored = true
		mirror.CanCollide = false
		mirror.Parent = self.MirrorBin

		local function onChildAdded(child)
			local prop

			if child:IsA("DataModelMesh") then
				prop = "Scale"
			elseif child:IsA("Decal") then
				prop = "Transparency"
			end

			if prop then
				local copy = child:Clone()
				copy.Parent = mirror

				self:MirrorProperty(child, copy, prop)
			end
		end

		for _,child in pairs(desc:GetChildren()) do
			onChildAdded(child)
		end

		self.HeadMirrors[desc] = mirror
		self:MirrorProperty(desc, mirror, "Transparency")

		desc.ChildAdded:Connect(onChildAdded)
	end
end

-- Removes the mirror copy of the provided
-- object from the HeadMirrors table, if it
-- is defined in there presently.

function FpsCamera:RemoveHeadMirror(desc)
	local mirror = self.HeadMirrors[desc]

	if mirror then
		mirror:Destroy()
		self.HeadMirrors[desc] = nil
	end
end

-- Called when the user's rotation type is changed.
-- This is a strong indication the user is in first person
-- and needs to have its first person movement smoothened out.

function FpsCamera:OnRotationTypeChanged()
	local camera = workspace.CurrentCamera
	local subject = camera and camera.CameraSubject

	if subject and subject:IsA("Humanoid") then
		local rotationType = UserGameSettings.RotationType

		if rotationType == Enum.RotationType.CameraRelative then
			subject.AutoRotate = false

			RunService:BindToRenderStep("FpsCamera", 1000, function (delta)
				if subject.AutoRotate or not subject:IsDescendantOf(game) or (subject.SeatPart and subject.SeatPart:IsA("VehicleSeat")) then
					RunService:UnbindFromRenderStep("FpsCamera")
					return
				end

				if camera.CameraType.Name == "Scriptable" then
					return
				end

				local rootPart = subject.RootPart
				local isGrounded = rootPart and rootPart:IsGrounded()

				if rootPart and not isGrounded then
					local state = subject:GetState()
					local canRotate = true

					if self.InvalidRotationStates[state.Name] then
						canRotate = false
					end

					if subject.Sit and subject.SeatPart then
						local root = rootPart:GetRootPart()

						if root ~= rootPart then
							canRotate = false
						end
					end

					if canRotate then
						local pos = rootPart.Position
						local step = math.min(0.2, (delta * 40) / 3)

						local look = camera.CFrame.LookVector
						look = (look * XZ_VECTOR3).Unit

						local cf = CFrame.new(pos, pos + look)
						rootPart.CFrame = rootPart.CFrame:Lerp(cf, step)
					end
				end

				if self:IsInFirstPerson() then
					local cf = camera.CFrame
					local headPos, headLook = self:GetSubjectPosition(subject)

					if headPos then
						local offset = (headPos - cf.Position)
						cf += offset

						camera.CFrame = cf
						camera.Focus += offset
					end

					local shadowAngle = self:GetShadowAngle()
					local inView = cf.LookVector:Dot(shadowAngle)

					if inView < 0 then
						for real, mirror in pairs(self.HeadMirrors) do
							mirror.CFrame = real.CFrame + (shadowAngle * 9)
						end
					end

					self.MirrorBin.Parent = (inView < 0 and camera or nil)
				else
					self.MirrorBin.Parent = nil
				end
			end)
		else
			subject.AutoRotate = true
			self.MirrorBin.Parent = nil
		end
	end
end

-- Lerp function 
-- Used on Renderstepped

function FpsCamera:NumLerp(num1: number, num2: number, rate: number) : number
	return num1 + (num2-num1)*rate
end

-- Function to get mouse drift
-- Used on Renderstepped

function FpsCamera:GetMouseDrift(Drift : number, MouseDelta : Vector2, dt : number) : number
	return FpsCamera:NumLerp(Drift, clamp(MouseDelta.X, DriftMin, DriftMax), (BaseMult * dt))
end

-- Main function for Motion Blir
-- Instead of using :BindToRenderStepped
-- Uses .RenderStepped for better performance

function FpsCamera:StartMotionBlur()

	local function MotionBlurFunction(Delta)

		MouseDelta = UserInputService:GetMouseDelta()

		Drift = self:GetMouseDrift(Drift, MouseDelta, Delta)

		MotionBlur.Size = clamp(abs(Drift * BlurMult), 0, MaxBlur)

	end

	-- Maintain the MotionBlur in the RenderStepped loop
	RuntimeMaid:GiveTask(RunService.RenderStepped:Connect(MotionBlurFunction));
end

-- Main function for Spring based effects
-- Instead of using :BindToRenderStepped
-- Uses .RenderStepped for better performance

function FpsCamera:StartSprings()

	local SpeedSpring = Spring.new(0)
	SpeedSpring.s = 16

	local BreathAlphaSpring = Spring.new(1)
	BreathAlphaSpring.s = 8
	BreathAlphaSpring.d = 0.9

	local TiltSpring = Spring.new(0)
	TiltSpring.s = TiltSpeed
	TiltSpring.d = TiltDamper

	local LookSwaySpring = Spring.new(Vector2.new())
	LookSwaySpring.s = LookSwaySpeed
	LookSwaySpring.d = LookSwayDamper

	local LandEffectSpring = Spring.new(0)
	LandEffectSpring.s = LandEffectSpeed
	LandEffectSpring.d = LandEffectDamper

	local function GetBreathing(Alpha : number)
		return Vector3.new(Alpha * (BreathingScale.X/10 * math.sin(tick() * BreathingSpeed)), Alpha * (BreathingScale.Y/10 * math.cos(tick() * BreathingSpeed)), 0)
	end

	local function SpringsFunction(Delta)

		local RootPart: BasePart = self.RootPart
		local Humanoid: Humanoid = self.Humanoid

		local RelativeVector = CFrame.new().VectorToObjectSpace(RootPart.CFrame, RootPart.AssemblyLinearVelocity)
		local CurrentSpeed = (Vector3.new(1, 0, 1) * RelativeVector).Magnitude
		local MoveDirection = RootPart.CFrame:VectorToObjectSpace(Humanoid.MoveDirection)
		local IsActive = not table.find(Offstates, Humanoid:GetState().Name)

		MouseDelta = UserInputService:GetMouseDelta()
		SpeedSpring.t = IsActive and CurrentSpeed or 0

		if BreathAlphaSpring then BreathAlphaSpring.t = (not IsActive and 0 or CurrentSpeed > 0.1 and 0 or 1) end

		if TiltSpring then TiltSpring.t = -MoveDirection.X end
		if LookSwaySpring then LookSwaySpring.t = Vector2.new(math.clamp(MouseDelta.X/LookSwayMouseDamper.X, -LookSwayMaxAngle.X, LookSwayMaxAngle.X), math.clamp(MouseDelta.Y/LookSwayMouseDamper.Y, -LookSwayMaxAngle.Y, LookSwayMaxAngle.Y)) end
		CameraTick = CameraTick + Delta * SpeedSpring.p

		Humanoid.CameraOffset = Vector3.new(SpeedSpring.p / 64 * math.sin(CameraTick / 2.15) + (GetBreathing(BreathAlphaSpring.p).X or 0), SpeedSpring.p / 82 * math.cos(CameraTick / 1.65) + (GetBreathing(BreathAlphaSpring.p).Y or 0), 0)
		Camera.CFrame = Camera.CFrame * CFrame.Angles((math.rad(LandEffectSpring.p * (Delta * 60)) or 0) + (math.rad(LookSwaySpring.p.Y) or 0), 0, (math.rad(TiltSpring.p * TiltAngle) or 0) + (math.rad(LookSwaySpring.p.X) or 0))
	end

	--//StateChanged
	self.Humanoid.StateChanged:Connect(function(OldState : Enum.HumanoidStateType, NewState : Enum.HumanoidStateType)

		if NewState == Enum.HumanoidStateType.Landed then

			LandEffectSpring:Impulse(-LandEffectVelocity)

			task.delay(0.1, function()
				LandEffectSpring:Impulse(LandEffectVelocity)
			end)

		end

	end)

	-- Maintain the Springs in the RenderStepped loop
	RuntimeMaid:GiveTask(RunService.RenderStepped:Connect(SpringsFunction));
end

-- Called when the player's character is added.
-- Sets up mirroring of the player's head for first person.

function FpsCamera:OnCharacterAdded(character)
	local mirrorBin = self.MirrorBin

	if mirrorBin then
		mirrorBin:ClearAllChildren()
		mirrorBin.Parent = nil
	end

	self.HeadMirrors = {}

	for _,desc in pairs(character:GetDescendants()) do
		self:AddHeadMirror(desc)
	end

	self:Connect("AddHeadMirror", character.DescendantAdded)
	self:Connect("RemoveHeadMirror", character.DescendantRemoving)
end

-- Called once to start the FpsCamera logic.
-- Binds and overloads everything necessary.

local started = false

function FpsCamera:Start()
	
	if started then
		return
	else
		started = true
	end
	
	self:RefreshCharacterVariables()
	
	RuntimeMaid:GiveTask(LocalPlayer.CharacterAdded:Connect(function()
		self:RefreshCharacterVariables()
	end))

	local PlayerScripts = LocalPlayer:WaitForChild("PlayerScripts")
	local PlayerModule = PlayerScripts:WaitForChild("PlayerModule")

	local baseCamera = PlayerModule:FindFirstChild("BaseCamera", true)
	local transparency = PlayerModule:FindFirstChild("TransparencyController", true)

	if baseCamera and baseCamera:IsA("ModuleScript") then
		local module = require(baseCamera)
		self:MountBaseCamera(module)
	else
		self:Warn("Start - Could not find BaseCamera module!")
	end

	if transparency and transparency:IsA("ModuleScript") then
		local module = require(transparency)
		self:MountTransparency(module)
	else
		self:Warn("Start - Cound not find TransparencyController module!")
	end

	local rotListener = UserGameSettings:GetPropertyChangedSignal("RotationType")
	self:Connect("OnRotationTypeChanged", rotListener)

	self.MirrorBin = Instance.new("Folder")
	self.MirrorBin.Name = "HeadMirrors"

	if self.Character then
		self:OnCharacterAdded(self.Character)
	end
	

	self:Connect("OnCharacterAdded", LocalPlayer.CharacterAdded)
	
	self:StartMotionBlur()
	self:StartSprings()
	
end

return FpsCamera
