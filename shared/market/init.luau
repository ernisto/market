local ReplicatedStorage = game:GetService("ReplicatedStorage")

local mantle_uploads = require(ReplicatedStorage.mantle_uploads)
local product = require(ReplicatedStorage.shared.market.product)
export type product = product.product
export type bundle = product.bundle
export type pass = product.pass

local env_uploads = if game.GameId == mantle_uploads.release.experience.singleton.assetId
	then mantle_uploads.release
	else mantle_uploads.dev

-- module
return table.freeze({
	products = table.freeze({
		expect_by_id = product.expect_by_id,

		vip = product.pass(env_uploads.product.vip),
	}),
})
