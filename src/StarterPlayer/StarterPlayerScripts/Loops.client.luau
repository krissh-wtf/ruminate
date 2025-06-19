--!optimize 2

-- Kentiq le gros bg.
-- Krissh le goat

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local startZone, startEvent, nearZone, nearEvent, endDoor, endEvent =
	Workspace:WaitForChild("startZone") :: Part,
	ReplicatedStorage:WaitForChild("startEvent") :: RemoteEvent,
	Workspace:WaitForChild("nearZone") :: Part,
	ReplicatedStorage:WaitForChild("nearEvent") :: RemoteEvent,
	Workspace:WaitForChild("endDoor").openDoor :: ProximityPrompt,
	ReplicatedStorage:WaitForChild("endEvent") :: RemoteEvent

startZone.Touched:Connect(function(hit: BasePart)
	startEvent:FireServer(hit)
end)

nearZone.Touched:Connect(function(hit: BasePart)
	nearEvent:FireServer(true, hit)
end)

nearZone.TouchEnded:Connect(function(hit: BasePart)
	nearEvent:FireServer(false, hit)
end)

endDoor.Triggered:Connect(function(player: Player) 
	endEvent:FireServer(player)
end)

-- endZone.Touched:Connect(function(hit)
-- 	endEvent:FireServer(hit)
-- end)
