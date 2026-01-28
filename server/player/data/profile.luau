-- packages
local ServerScriptService = game:GetService("ServerScriptService")
local profile_store = require(ServerScriptService.packages.profile_store)

local template = require(script.Parent.template)
export type data = typeof(template)

export type Profile = profile_store.Profile<data>

-- module
local players_store = profile_store.New("players", template)
local player_profile = { store = players_store }
local profiles = {}
local loadings = {}

-- functions
function player_profile.get_key(user_id: number): string
	return tostring(user_id)
end
function player_profile.is_loading(player: Player): boolean
	return loadings[player] or false
end
function player_profile.find(player: Player): Profile?
	return profiles[player]
end
function player_profile.expect(player: Player, error_message: string?): Profile
	return player_profile.find(player) or error(error_message or `profile wasnt loaded`)
end
function player_profile.await_find(player: Player): Profile?
	while player.Parent and not profiles[player] do
		task.wait()
	end
	return profiles[player]
end
function player_profile.await_expect(player: Player, error_message: string?): Profile
	return player_profile.await_find(player) or error(error_message or `profile isnt loading/loaded`)
end

-- builder
function player_profile.await_cached_load(player: Player): Profile
	while loadings[player] do
		task.wait()
	end
	if profiles[player] then
		return profiles[player]
	end

	loadings[player] = true
	local self = players_store:StartSessionAsync(player_profile.get_key(player.UserId), {})

	loadings[player] = nil
	assert(self, `generic ProfileStore error`)

	-- start up
	self:AddUserId(player.UserId)
	self:Reconcile()

	-- cache
	profiles[player] = self
	self.OnSessionEnd:Connect(function()
		profiles[player] = nil
	end)

	-- end
	return self :: any
end

-- end
return player_profile
