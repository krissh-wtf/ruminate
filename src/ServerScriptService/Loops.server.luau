--!optimize 2

-- Kentiq le gros bg.
-- Krissh le goat

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Utils = require(ReplicatedStorage.Utils)

local currentLoop, looping, endable, debounce = 0, false, false, 0.1
local lastFiredLoop, entered = { 0, 0 }, {}

local startEvent, nearEvent, endEvent =
	ReplicatedStorage.startEvent :: RemoteEvent,
	ReplicatedStorage.nearEvent :: RemoteEvent,
	ReplicatedStorage.endEvent :: RemoteEvent

local startActionsEvent, endActionsEvent =
	ReplicatedStorage.startActionsEvent :: BindableEvent,
	ReplicatedStorage.endActionsEvent :: BindableEvent

startActionsEvent.Event:Connect(function(loop: number)
	lastFiredLoop[2] = loop
	print(string.format("🟡🟡 [startActionsEvent.Event] received for loop: %d", loop))
	Utils.loopActions(lastFiredLoop[2], true)
end)

endActionsEvent.Event:Connect(function(loop: number)
	lastFiredLoop[1] = loop
	print(string.format("🟠🟠 [endActionsEvent.Event] received for loop: %d", loop))
	Utils.loopActions(lastFiredLoop[1], true)
end)

startEvent.OnServerEvent:Connect(function(player: Player, hit: BasePart)
	local character = player.Character :: Model
	if character and hit:IsDescendantOf(character) and looping == false then
		looping = true
		local nextLoop = currentLoop + 1

		if nextLoop == 1 or lastFiredLoop[1] == (nextLoop - 1) then
			currentLoop = nextLoop
			print(
				string.format(
					"🟢🟢 [startEvent.OnServerEvent]: triggered, starting loop %d...",
					currentLoop
				)
			)
			startActionsEvent:Fire(currentLoop)
		else
			print(
				string.format(
					"🟢 [startEvent.OnServerEvent]: touched, but conditions not met for loop. nextLoop: %d, lastFiredLoop[2]: %d",
					nextLoop,
					lastFiredLoop[2]
				)
			)
		end

		task.delay(debounce, function() looping = false end)
	else
		print(
			"🟢 [startEvent.OnServerEvent]: no character or currently looping, ignoring..."
		)
		return
	end
end)

nearEvent.OnServerEvent:Connect(function(player: Player, state: boolean, hit: BasePart)
	local character = player.Character
	local name = player.Name

	if character and hit:IsDescendantOf(character) and looping == false then
		if state == true then
			if #Players:GetPlayers() < 2 then
				print("🔵 [nearEvent.OnServerEvent]: not enough players, skipping...")
				endable = true
				return
			end

			local position = table.find(entered, name)
			if position == nil then
				table.insert(entered, name)
				print(
					string.format("🔵🔵 [nearEvent.OnServerEvent]: %s entered nearZone", name)
				)
			else
				print(
					string.format(
						"🔵 [nearEvent.OnServerEvent]: %s already in nearZone, ignoring...",
						name
					)
				)
			end

			return
		elseif state == false then
			local position = table.find(entered, name)
			if position ~= nil then
				table.remove(entered, position)
				print(
					string.format(
						"🔵🔵 [nearEvent.OnServerEvent]: %s removed from nearZone",
						name
					)
				)
			else
				print(
					string.format("🔵 [nearEvent.OnServerEvent]: %s not found in nearZone", name)
				)
			end

			return
		end
	else
		print(
			string.format(
				"🔵 [nearEvent.OnServerEvent]: event fired by %s, state: %s",
				name,
				tostring(state)
			)
		)
		return
	end
end)

endEvent.OnServerEvent:Connect(function(player: Player, hit: BasePart)
	local character = player.Character
	if endable == true then
		if character and hit:IsDescendantOf(character) and looping == false then
			looping = true

			if currentLoop > 0 and lastFiredLoop[1] then
				print(
					string.format(
						"🔴🔴 [endEvent.OnServerEvent]: triggered, ending loop %d",
						currentLoop
					)
				)
				endActionsEvent:Fire(currentLoop)
			else
				print(
					string.format(
						"🔴 [endEvent.OnServerEvent]: touched, but conditions not met for loop. currentLoop: %d, lastFiredLoop[1]: %d",
						currentLoop,
						lastFiredLoop[1]
					)
				)
			end

			task.delay(debounce, function() looping = false end)
		else
			print(
				"🔴 [endEvent.OnServerEvent]: no character or currently looping, ignoring..."
			)
			return
		end
	else
		print("🔴 [endEvent.OnServerEvent]: not endable, ignoring...")
		return
	end
end)
