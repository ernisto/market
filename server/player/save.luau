local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local save_profile = require(ServerScriptService.server.save_profile)

local template = require(script.Parent.template)
export type data = typeof(template)

-- vars
local player_save = save_profile.handle("player", template)
local profiles = {}

-- functions
local function process_player(player: Player)
	local profile = save_profile.await_load(player_save, tostring(player.UserId))
	if profile == nil then
		return player:Kick(`couldnt possible load your data`)
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	profiles[player] = profile
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
	end)

	-- cleanup
	player.AncestryChanged:Connect(function()
		if player:IsDescendantOf(Players) then
			return
		end
		profile:EndSession()
	end)
	return
end
local function await_global_update(player_id: number, message: save_profile.message)
	return save_profile.await_global_update(player_save, tostring(player_id), message)
end

local function find(player: Player)
	return profiles[player]
end
local function assert(player: Player)
	return find(player) or error(`profile didnt loaded`)
end
local function await_assert(player: Player)
	while player.Parent and profiles[player] == nil do
		task.wait()
	end
	return assert(player)
end

-- listener
Players.PlayerAdded:Connect(process_player)
for _, player in Players:GetPlayers() do
	task.spawn(process_player, player)
end

-- end
return {
	await_global_update = await_global_update,
	await_assert = await_assert,
	assert = assert,
	find = find,
}
