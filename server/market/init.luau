local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local market = require(ReplicatedStorage.shared.market)
local net = require(ServerScriptService.server.net)
local player_profile = require(ServerScriptService.server.player.data.profile)
local product = require(ReplicatedStorage.shared.market.product)
export type product = product.product

local states = require(script.states)
local transition = require(script.transition)

-- vars
local sanitization: { [number]: (Player, states.params) -> () } = {}
local handlers: { [number]: (Player, states.params) -> () } = {}

-- functions
local function handle(product: product, callback: (Player, states.params) -> ())
	handlers[product.id] = callback
end
local function sanitize(product: product, callback: (player: Player, params: states.params) -> ())
	sanitization[product.id] = callback
end

local function assert_availability(product: product, player: Player, params: states.params)
	local profile = player_profile.expect(player)
	if product.kind == "pass" then
		assert(not profile.Data.passes[tostring(product.id)], `player already owns pass {product.id}`)
	elseif product.kind == "consumable" then
		assert(handlers[product.id], `product didnt implemented yet`)
		assert(product.amount == nil, `robux purchases doesnt respect product amount, consider create another product`)
	end

	if sanitization[product.id] then
		sanitization[product.id](player, params)
	end
end
local function give(product: product, player: Player, params: states.params)
	if product.kind == "pass" then
		local profile = player_profile.expect(player)
		profile.Data.passes[tostring(product.id)] = true
	elseif product.kind == "bundle" then
		for _, product in product.products do
			give(product, player, params)
		end
	end

	net.game.market.purchase_completed.fire(player)
	local handler = if product.id
		then handlers[product.id]
		elseif product.kind == "consumable" then error(`attempt to give unhandled product {product.id}`)
		else nil

	for i = 1, ((product :: any).amount or 1) do
		if handler then
			handler(player, params)
		end
	end
end

local function await_prompt(product: product, player: Player, params: states.params)
	assert_availability(product, player, params)
	return transition.await_prompt(product.id, player, params)
end

local function await_owns_pass(pass: product, player: Player)
	local profile = player_profile.await_expect(player)
	return profile ~= nil and profile.Data.passes[tostring(pass.id)] == true
end
local function await_expect_pass(pass: product, player: Player)
	if await_owns_pass(pass, player) then
		return true
	end
	await_prompt(pass, player, {})
	return false
end

-- listeners
type message = { purchase_id: number, product_id: number, params: states.params }
Players.PlayerAdded:Connect(function(player)
	local profile = player_profile.await_expect(player)
	profile:MessageHandler(function(message, complete)
		local product_message = message :: message
		local product = market.products.expect_by_id(product_message.product_id)
		local data = profile.Data :: player_profile.data

		local purchase_key = `_{product_message.purchase_id}`
		if data.processed_purchases[purchase_key] then
			data.processed_purchases[purchase_key] += 1
			return complete()
		end

		local params = product_message.params
		if not params.target_id or player.UserId == params.target_id then
			give(product, player, params)
		end

		profile.Data.processed_purchases[purchase_key] = 1
		complete()
	end)
end)

net.game.market.prompt.on(function(player, data): ()
	local product = market.products.expect_by_id(data.product_id)
	return await_prompt(product, player, { target_id = data.target_id })
end)

-- module
return table.freeze({
	await_prompt = await_prompt,

	await_expect_pass = await_expect_pass,
	await_owns_pass = await_owns_pass,

	sanitize = sanitize,
	handle = handle,

	assert_availability = assert_availability,
	give = give,

	products = market.products,
})
