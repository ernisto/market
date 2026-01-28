local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local vide = require(ReplicatedStorage.packages.vide)

-- consts
local MOCK = {
	DisplayName = "mock",
	Description = "a mocked product usually is loaded when we cant fetch a new info nor have a cache",
	IconImageAssetId = 0,
	PriceInRobux = 1,
	IsLimited = false,
	IsForSale = true,
}

-- cache
local cache_container: StringValue = ReplicatedStorage:FindFirstChild("product_infos")
	or vide.create("StringValue")({ Parent = ReplicatedStorage, Name = "product_infos", Value = "{}" }) :: any

local cache = HttpService:JSONDecode(cache_container.Value)
local function save_cache()
	cache_container.Value = HttpService:JSONEncode(cache)
end

-- module
local function await_get_info(id: number)
	local key = "_" .. id

	local success, data = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, Enum.InfoType.Product)
	cache[key] = if success then data else cache[key] or MOCK

	if not success then
		warn(data)
	end
	if not RunService:IsRunning() then
		save_cache()
	end

	return cache[key]
end

return await_get_info
