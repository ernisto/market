local Players = game:GetService("Players")
local profile = require(script.Parent.data.profile)

-- functions
local function process_player(player)
	local success, result = pcall(profile.await_cached_load, player)
	if not success then
		player:Kick(`couldnt possible load your data:\n{result}`)
		return
	end

	local profile = result

	-- cleanup
	while player:IsDescendantOf(Players) do
		player.AncestryChanged:Wait()
	end
	profile:EndSession()
end

-- listener
Players.PlayerAdded:Connect(process_player)
for _, player in Players:GetPlayers() do
	task.spawn(process_player, player)
end

-- end
return nil
