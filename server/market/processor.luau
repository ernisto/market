local ServerScriptService = game:GetService("ServerScriptService")

local player_profile = require(ServerScriptService.server.player.data.profile)
local states = require(ServerScriptService.server.market.states)

-- defs
export type processor = {
	product_id: number,
	player: Player,

	record_pending: boolean,
}

-- vars
local cache = setmetatable({}, {
	__index = function(cache, index)
		local tab = {}
		cache[index] = tab
		return tab
	end,
})

-- functions
local new_processor
local function get_processor(id: number, player: Player): processor
	return cache[id][player] or new_processor(id, player)
end

-- constructor
function new_processor(id: number, player: Player): processor
	local processor = {
		product_id = id,
		player = player,

		record_pending = false,
	}

	cache[id][player] = processor
	return processor
end

-- methods
local function get_pending(processor: processor): states.purchase_prompt?
	local profile = player_profile.expect(processor.player)
	local key = tostring(processor.product_id)

	if not profile.Data.products[key] then
		profile.Data.products[key] = { pending = nil }
	end
	return profile.Data.products[key].pending
end
local function set_pending(processor: processor, pending: states.purchase_prompt?)
	local profile = player_profile.expect(processor.player)
	local key = tostring(processor.product_id)

	if not profile.Data.products[key] then
		profile.Data.products[key] = { pending = nil }
	end
	profile.Data.products[key].pending = pending
end

-- module
return table.freeze({ get = get_processor, get_pending = get_pending, set_pending = set_pending })
