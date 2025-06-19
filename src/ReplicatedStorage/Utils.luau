local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Utils = {}

-- jcpa en vrai si ca change grand chose mais de tt facon ya r a modifier dans la table
local loopsTags, spawns, wChildren =
	table.freeze({
		CollectionService:GetTagged("loop1"),
		CollectionService:GetTagged("loop2"),
		CollectionService:GetTagged("loop3"),
		CollectionService:GetTagged("loop4"),
		CollectionService:GetTagged("loop5"),
		CollectionService:GetTagged("loop6"),
		CollectionService:GetTagged("loop7"),
		CollectionService:GetTagged("loop8"),
		CollectionService:GetTagged("loop9"),
		CollectionService:GetTagged("loop10"),
		CollectionService:GetTagged("loop11"),
		CollectionService:GetTagged("loop12"),
		CollectionService:GetTagged("loop13"),
		CollectionService:GetTagged("loop14"),
		CollectionService:GetTagged("loop15"),
		CollectionService:GetTagged("loop16"),
		CollectionService:GetTagged("loop17"),
		CollectionService:GetTagged("loop18"),
		CollectionService:GetTagged("loop19"),
		CollectionService:GetTagged("loop20"),
		CollectionService:GetTagged("loop21"),
		CollectionService:GetTagged("loop22"),
		CollectionService:GetTagged("loop23"),
		CollectionService:GetTagged("loop24"),
		CollectionService:GetTagged("loop25"),
		CollectionService:GetTagged("loop26"),
		CollectionService:GetTagged("loop27"),
		CollectionService:GetTagged("loop28"),
		CollectionService:GetTagged("loop29"),
		CollectionService:GetTagged("loop30"),
	}), table.freeze({
		[1] = Workspace:FindFirstChild("SpawnLocation1") :: SpawnLocation,
		[2] = Workspace:FindFirstChild("SpawnLocation2") :: SpawnLocation,
	}), table.freeze(Workspace:GetChildren()) -- au cas ou jcpa

local invisPos = Vector3.new(0, -150, 0)

function Utils.setVisibility(elements: { any }, state: boolean)
	for _, elem in elements do
		if state ~= false then
			elem.Transparency = 0
		else
			elem.Transparency = 1
		end
	end
end

function Utils.setEnabled(elements: { any }, state: boolean)
	for _, elem in elements do
		if state ~= false then
			elem.Enabled = true
		else
			elem.Enabled = false
		end
	end
end

function Utils.setCollisions(elements: { BasePart })
	for _, elem in elements do
		elem.CanCollide = not elem.CanCollide
		elem.CanTouch = not elem.CanTouch
		elem.CanQuery = not elem.CanQuery
	end
end

function Utils.giveAttributes()
	for _, child in wChildren do
		if typeof(child) == "Model" and child:GetAttribute("ogPos") == nil then
			child:SetAttribute("ogPos", child:GetPivot())
			child:SetAttribute("isMoved", false)
			print(
				string.format(
					"[Utils.giveAttributes]: %s attributes (ogPos, isMoved) set",
					child.Name
				)
			)
		else
			return
		end
	end
end

function Utils.toSpawn()
	for i, player in Players:GetPlayers() do
		if
			not player.Character or not player.Character:FindFirstChild("HumanoidRootPart")
		then
			print(string.format("[Utils.toSpawn]: %s has no character", player.Name))
			return
		end

		if not spawns[i] then
			print(
				string.format("[Utils.toSpawn]: %s does not exist, quitting...", spawns[i].Name)
			)
			return
		end

		player.Character:FindFirstChild("HumanoidRootPart").CFrame =
			CFrame.new(spawns[i].Position)
	end
end

function Utils.hideModel(model: Model, state: boolean)
	if state ~= false then
		if model:GetAttribute("IsMoved") ~= false then
			model:MoveTo(invisPos)
			model:SetAttribute("isMoved", true)
			print(model.Name, "moved to invisPos")
		end
	else
		if model:GetAttribute("isMoved") == true then
			local ogPos = model:GetAttribute("ogPos") :: CFrame
			model:PivotTo(ogPos)
			model:SetAttribute("isMoved", false)
			print(string.format("[Utils.hideModel]: %s restored to ogPos", model.Name))
		end
	end
end

function Utils.loopActions(loop: number, state: boolean)
	Utils.giveAttributes()
	if loopsTags[loop] then
		for _, elems in loopsTags[loop] do
			if elems:IsA("BasePart") then
				Utils.setVisibility({ elems }, state)
			elseif elems:IsA("Model") then
				Utils.hideModel(elems, state)
				-- elseif elems:IsA("GuiObject") then
				-- 	Utils.setEnabled({ elems }, state)
			end
		end
	end

	if state == false then Utils.toSpawn() end
end

return Utils
