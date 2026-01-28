local ReplicatedStorage = game:GetService("ReplicatedStorage")

local await_get_info = require(ReplicatedStorage.shared.market.get_info)
local vide = require(ReplicatedStorage.packages.vide)

local mantle_uploads = require(ReplicatedStorage.mantle_uploads)
type product_upload = typeof(mantle_uploads.release.product.vip)

-- defs
type image_id = number
type ratio = number

type discount = {
	ratio: ratio,
	time_end: number?,
}

export type bundle = base_product & { kind: "bundle", products: { consumable }, total_price: number }
export type consumable = base_product & { kind: "consumable", amount: number? }
export type pass = base_product & { kind: "pass" }

export type product = bundle | consumable | pass
type base_product = {
	id: number,
	discount: discount?,
	price_wons: number?,
	category: number?,
	price: number,
	icon: image_id,
	display_name: string,
	description: string,
	is_for_sale: boolean,
	is_limited: boolean,
	is_loaded: vide.source<boolean>,
}

local function process_description(description: string, output: base_product)
	description = description:gsub("\n?wons:%s*(%d+)\n?", function(wons)
		output.price_wons = tonumber(wons)
		return "\n"
	end)

	description = description:gsub("\n?category:%s*(%d+)\n?", function(category)
		output.category = tonumber(category)
		return "\n"
	end)

	local discount_ratio
	description = description:gsub("\n?discount:%s*(%d+)%%\n?", function(_discount_ratio)
		discount_ratio = (tonumber(_discount_ratio) or 0) / 100
		return "\n"
	end)
	local m, d, y
	description = description:gsub(
		"\n?until:%s*0*(%d+)/0*(%d+)/0*(%d+)\n?",
		function(_m, _d, _y)
			m = tonumber(_m)
			d = tonumber(_d)
			y = 2000 + (tonumber(_y) or 0)
			return "\n"
		end :: any
	)

	output.discount = discount_ratio
		and table.freeze({
			ratio = discount_ratio,
			time_end = d and m and y and os.time({ day = d, month = m, year = y }),
		})

	output.description = description
	return output
end

-- module
local function base_product(upload: product_upload): base_product
	local data = {
		kind = "product",
		id = upload.assetId,
		is_loaded = vide.source(false),
		price = upload.price,
		display_name = upload.name,
		description = upload.description,
	}
	process_description(data.description, data :: any)

	task.spawn(function()
		local info = await_get_info(upload.assetId)

		if not info.DisplayName:match("^[#%s]+$") then
			data.display_name = info.DisplayName
		end
		data.icon = info.DisplayIconImageAssetId
		data.price = info.PriceInRobux
		data.description = info.Description
		data.is_for_sale = info.IsForSale
		data.is_limited = info.IsLimited

		process_description(data.description, data)
		data.is_loaded(true)
	end)
	return data
end

local cache: { [number]: any } = {}
local function amount_consumable(upload: product_upload, amount: number): consumable
	local product = base_product(upload)
	local consumable = table.clone(product) :: consumable

	consumable.amount = amount
	consumable.kind = "consumable"

	local is_loaded = product.is_loaded
	consumable.is_loaded = vide.derive(function(): boolean
		if not is_loaded() then
			return false
		end
		for k, v in product do
			consumable[k] = v
		end

		consumable.display_name = `{product.display_name} [{amount}x]`
		consumable.price_wons = product.price_wons and product.price_wons * amount
		consumable.price = product.price and product.price * amount
		return true
	end)
	return consumable
end
local function consumable(upload: product_upload, amount: number?): consumable
	local id = upload.assetId

	if amount then
		return amount_consumable(upload, amount)
	end
	if cache[id] then
		return cache[id]
	end

	local consumable: consumable = base_product(upload) :: any
	consumable.kind = "consumable"

	cache[id] = consumable
	return consumable
end
local function bundle(upload: product_upload, products: { consumable }): bundle
	local id = upload.assetId
	if cache[id] then
		return cache[id]
	end

	local product = base_product(upload)
	local bundle = table.clone(product) :: bundle

	bundle.kind = "bundle"
	bundle.products = products

	local is_loaded = bundle.is_loaded
	local total_price = vide.derive(function(): number?
		is_loaded()
		for k, v in product do
			bundle[k] = v
		end

		local price = 0
		local loaded: true? = true
		for _, product in products do
			if not product.is_loaded() then
				loaded = nil
			end
			price += product.price
		end
		bundle.discount = { ratio = 1 - bundle.price / price, time_end = bundle.discount and bundle.discount.time_end }
		bundle.total_price = price
		return loaded and price
	end)
	bundle.is_loaded = vide.derive(function()
		return is_loaded() and total_price() ~= nil
	end)

	cache[id] = bundle
	return bundle
end
local function pass(upload: product_upload): pass
	local id = upload.assetId
	if cache[id] then
		return cache[id]
	end

	local pass = base_product(upload) :: pass
	pass.kind = "pass"

	cache[id] = pass
	return pass
end

local function expect_by_id(id: number): product
	return cache[id] or error(`product with id '{id}' not defined`)
end

-- module
return table.freeze({
	expect_by_id = expect_by_id,
	consumable = consumable,
	bundle = bundle,
	pass = pass,
})
