local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local player_profile = require(ServerScriptService.server.player.data.profile)
local processor = require(ServerScriptService.server.market.processor)
local promise = require(ReplicatedStorage.packages.promise)
type processor = processor.processor

local states = require(ServerScriptService.server.market.states)
type purchase_prompt = states.purchase_prompt
type params = states.params

-- functions
local function await_record_pending(player_processor: processor, params: params): purchase_prompt
	local profile = player_profile.expect(player_processor.player)
	local purchase = params and { params = params, job_id = game.JobId, attempted_to_process = false, accepted = false }

	player_processor.record_pending = true
	processor.set_pending(player_processor, purchase)

	profile:Save()
	local save = promise.fromEvent(profile.OnAfterSave):timeout(60)

	save:catch(function()
		player_processor.record_pending = false
		processor.set_pending(player_processor, nil)
	end)

	save:expect()
	player_processor.record_pending = false

	return purchase
end

-- transitions
local function await_prompt(product_id: number, player: Player, params: params): purchase_prompt
	local player_processor = processor.get(product_id, player)
	local pending = processor.get_pending(player_processor)

	if pending and states.is_dead_prompt(pending) then
		processor.set_pending(player_processor, nil)
	end
	if pending and states.is_local_pending(pending) then
		error(`awaiting prompt to be accepted or cancelled`)
	end
	if pending and states.is_cross_pending(pending) then
		error(`awaiting prompt to be queued for processing`)
	end

	assert(not player_processor.record_pending, `already recording a pending prompt`)
	local prompted_purchase = await_record_pending(player_processor, params) or error(`impossible`)

	MarketplaceService:PromptProductPurchase(player, product_id)
	while processor.get_pending(player_processor) == prompted_purchase do
		task.wait(0.5)
	end

	return prompted_purchase
end

-- listeners
local function try_process_purchase(receipt): nil
	local player = Players:GetPlayerByUserId(receipt.PlayerId) or error(`player offline`)
	local player_processor = processor.get(receipt.ProductId, player)

	local pending_purchase = processor.get_pending(player_processor)
	local params = if pending_purchase then pending_purchase.params else {} :: params

	local profile = player_profile.expect(player)
	local target_id = params and params.target_id or player.UserId

	if pending_purchase then
		pending_purchase.accepted = true
	end
	local success = player_profile.store:MessageAsync(
		player_profile.get_key(target_id),
		{ purchase_id = receipt.PurchaseId, product_id = receipt.ProductId, params = params }
	)
	assert(success, `could not possible queue process for target`)

	if pending_purchase then
		pending_purchase.attempted_to_process = true
	end
	processor.set_pending(player_processor, nil)

	profile:Save();
	(profile.OnAfterSave :: any):Wait()

	return
end

local processing_purchases = {}
function MarketplaceService.ProcessReceipt(receipt: any)
	assert(processing_purchases[receipt.PurchaseId] == nil)
	processing_purchases[receipt.PurchaseId] = true

	local success, err = xpcall(try_process_purchase, debug.traceback, receipt)
	processing_purchases[receipt.PurchaseId] = nil

	assert(success, err)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end
MarketplaceService.PromptProductPurchaseFinished:Connect(function(user_id, product_id, was_purchased)
	if was_purchased then
		return
	end

	local player = Players:GetPlayerByUserId(user_id)
	if not player then
		return
	end

	local player_processor = processor.get(product_id, player)
	local pending_purchase = processor.get_pending(player_processor)
	if not pending_purchase then
		return
	end

	pending_purchase.accepted = was_purchased
	processor.set_pending(player_processor, nil)
end)

-- module
return table.freeze({ await_prompt = await_prompt })
