--//Services
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace");

--//Local Variables
local LocalPlayer = Players.LocalPlayer;

--//Paths
local MainModule = script.Parent.Parent

local CameraComponent = require(MainModule:WaitForChild("Components"):WaitForChild("Camera"))

--//RbxUtil
local RbxUtil = MainModule:WaitForChild('RbxUtil')

local Util = require(RbxUtil:WaitForChild("Util"))

--//Imported Settings
local RealismConfig = require(MainModule.Configs.RealismConfig);

--//Variables
local XZ_VECTOR3 = Vector3.new(1, 0, 1)

local RotationComponent = 
	{
		Rotators = {};
		SetLookAngles = ReplicatedStorage:WaitForChild("SetLookAngles");
	}

-- Connects a self-function by  
-- name to the provided event.

function RotationComponent:Connect(funcName, event)
	return event:Connect(function (...)
		self[funcName](self, ...)
	end)
end

-- Register's a newly added Motor6D  
-- into the provided joint rotator.

function RotationComponent:AddMotor(rotator, motor)
	local parent = motor.Parent

	if parent and parent.Name == "Head" then
		parent.CanCollide = false
	end

	-- Wait until this motor is marked as active
	-- before attempting to use it in the rotator.

	Util:PromiseValue(motor, "Active", function ()
		local data = 
			{ 
				Motor = motor;
				C0 = motor.C0;
			}

		-- If it can be found, use the source RigAttachment for this Motor6D
		-- joint instead of using the static C0 value. This is intended for R15.

		Util:PromiseChild(motor.Part0, motor.Name .. "RigAttachment", function (origin)
			if origin:IsA("Attachment") then
				data.Origin = origin
				data.C0 = nil
			end
		end)

		-- Add this motor to the rotator
		-- by the name of its Part1 value.

		local id = motor.Part1.Name
		rotator.Motors[id] = data
	end)
end

-- Called when the client receives a new look-angle
-- value from the server. This is also called continuously
-- on the client to update the player's view with no latency.

function RotationComponent:OnLookReceive(pitch, yaw)
	local character = LocalPlayer.Character
	local rotator = self.Rotators[character]

	if rotator then
		rotator.Pitch.Goal = pitch
		rotator.Yaw.Goal = yaw
	end
end

-- Computes the look-angle to be used by the client.
-- If no lookVector is provided, the camera's lookVector is used instead.
-- useDir (-1 or 1) can be given to force whether the direction is flipped or not.

function RotationComponent:ComputeLookAngle(lookVector, useDir)
	local inFirstPerson = CameraComponent:IsInFirstPerson()
	local pitch, yaw, dir = 0, 0, 1

	if not lookVector then
		local camera = workspace.CurrentCamera
		lookVector = camera.CFrame.LookVector
	end

	if lookVector then
		local character = LocalPlayer.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")

		if rootPart and rootPart:IsA("BasePart") then
			local cf = rootPart.CFrame
			pitch = -cf.RightVector:Dot(lookVector)

			if not inFirstPerson then
				dir = math.clamp(cf.LookVector:Dot(lookVector) * 10, -1, 1)
			end
		end

		yaw = lookVector.Y
	end

	if useDir then
		dir = useDir
	end

	pitch *= dir
	yaw *= dir

	return pitch, yaw
end

-- Interpolates the current value of a rotator
-- state (pitch/yaw) towards its goal value.

function RotationComponent:StepValue(state, delta)
	local current = state.Current or 0
	local goal = state.Goal

	local pan = 5 / (delta * 60)
	local rate = math.min(1, (delta * 20) / 3)

	local step = math.min(rate, math.abs(goal - current) / pan)
	state.Current = Util:StepTowards(current, goal, step)

	return state.Current
end

-- Called to update all of the look-angles being tracked
-- on the client, as well as our own client look-angles.
-- This is called during every RunService Heartbeat.

function RotationComponent:UpdateLookAngles(delta)
	-- Update our own look-angles with no latency
	local pitch, yaw = self:ComputeLookAngle()
	self:OnLookReceive(pitch, yaw)

	-- Submit our look-angles if they have changed enough.
	local lastUpdate = self.LastUpdate or 0
	local now = os.clock()

	if (now - lastUpdate) > .5 then
		pitch = Util:RoundNearestInterval(pitch, .05)
		yaw = Util:RoundNearestInterval(yaw, .05)

		if pitch ~= self.Pitch then
			self.Pitch = pitch
			self.Dirty = true
		end

		if yaw ~= self.Yaw then
			self.Yaw = yaw
			self.Dirty = true
		end

		if self.Dirty then
			self.Dirty = false
			self.LastUpdate = now
			self.SetLookAngles:FireServer(pitch, yaw)	
		end
	end

	-- Update all of the character look-angles
	local camera = workspace.CurrentCamera
	local camPos = camera.CFrame.Position

	local player = LocalPlayer
	local dropList

	for character, rotator in pairs(self.Rotators) do
		if not character.Parent then
			if not dropList then
				dropList = {}
			end

			dropList[character] = true
			continue
		end

		local owner = Players:GetPlayerFromCharacter(character)
		local dist = owner and owner:DistanceFromCharacter(camPos) or 0

		if owner ~= player and dist > 30 then
			continue
		end

		local lastStep = rotator.LastStep or 0
		local stepDelta = now - lastStep

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local rootPart = humanoid and humanoid.RootPart

		if not rootPart then
			continue
		end

		local pitchState = rotator.Pitch
		self:StepValue(pitchState, stepDelta)

		local yawState = rotator.Yaw
		self:StepValue(yawState, stepDelta)

		local motors = rotator.Motors
		rotator.LastStep = now

		if not motors then
			continue
		end

		for name, factors in pairs(self.RotationFactors) do
			local data = motors and motors[name]

			if not data then
				continue
			end

			local motor = data.Motor
			local origin = data.Origin

			if origin then
				local part0 = motor.Part0
				local setPart0 = origin.Parent

				if part0 and part0 ~= setPart0 then
					local newOrigin = part0:FindFirstChild(origin.Name)

					if newOrigin and newOrigin:IsA("Attachment") then
						origin = newOrigin
						data.Origin = newOrigin
					end
				end

				origin = origin.CFrame
			elseif data.C0 then
				origin = data.C0
			else
				continue
			end

			local pitch = pitchState.Current or 0
			local yaw = yawState.Current or 0

			if rotator.SnapFirstPerson and name == "Head" then
				if CameraComponent:IsInFirstPerson() then
					pitch = pitchState.Goal
					yaw = yawState.Goal
				end
			end

			local fPitch = pitch * factors.Pitch
			local fYaw = yaw * factors.Yaw

			-- HACK: Make the arms rotate with a tool.
			if name:sub(-4) == " Arm" or name:sub(-8) == "UpperArm" then
				local tool = character:FindFirstChildOfClass("Tool")

				if tool and not CollectionService:HasTag(tool, "NoArmRotation") then
					if name:sub(1, 5) == "Right" and rootPart:GetRootPart() ~= rootPart then
						fPitch = pitch * 1.3
						fYaw = yaw * 1.3
					else
						fYaw = yaw * .8
					end
				end
			end

			local dirty = false

			if fPitch ~= pitchState.Value then
				pitchState.Value = fPitch
				dirty = true
			end

			if fYaw ~= yawState.Value then
				yawState.Value = fYaw
				dirty = true
			end

			if dirty then
				local rot = origin - origin.Position

				local cf = CFrame.Angles(0, fPitch, 0)
					* CFrame.Angles(fYaw, 0, 0)

				motor.C0 = origin * rot:Inverse() * cf * rot
			end
		end
	end

	-- If the dropList is declared, remove any characters that 
	-- were indexed into it. This is done after iterating over
	-- the rotators to avoid problems with removing data from
	-- a table while iterating over said table.

	if dropList then
		for character in pairs(dropList) do
			local rotator = self.Rotators[character]
			local listener = rotator and rotator.Listener

			if listener then
				listener:Disconnect()
			end

			self.Rotators[character] = nil
		end
	end
end

-- Mounts the provided humanoid into the look-angle
-- update system, binding all of its current and
-- future Motor6D joints into the rotator.

function RotationComponent:MountLookAngle(humanoid)	
	local character = humanoid.Parent
	local rotator = character and self.Rotators[character]

	if not rotator then
		-- Create a rotator for this character.
		rotator = 
			{
				Motors = {};

				Pitch =
				{
					Goal = 0;
					Current = 0;
				};

				Yaw =
				{
					Goal = 0;
					Current = 0;
				};
			}

		-- If this is our character, the rotation 
		-- values should not be interpolated while 
		-- the client is in first person.

		local player = Players:GetPlayerFromCharacter(character)

		if player == LocalPlayer then
			rotator.SnapFirstPerson = true
		end

		-- Register this rotator for the character.
		self.Rotators[character] = rotator

		-- Record all existing Motor6D joints
		-- and begin recording newly added ones.

		local function onDescendantAdded(desc)
			if desc:IsA("Motor6D") then
				self:AddMotor(rotator, desc)
			end
		end

		for _,desc in pairs(character:GetDescendants()) do
			onDescendantAdded(desc)
		end

		rotator.Listener = character.DescendantAdded:Connect(onDescendantAdded)
	end

	return rotator
end

function RotationComponent:Start()
	
	for key, value in pairs(RealismConfig) do
		self[key] = value
	end
	
	RunService.Heartbeat:Connect(function()
		self:UpdateLookAngles()
	end)

	self.SetLookAngles.OnClientEvent:Connect(function(Pitch, Yaw)
		self:OnLookReceive(Pitch, Yaw)
	end)


end

return RotationComponent