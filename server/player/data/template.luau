type purchase_key = string -- `_{id}`
return {
	processed_purchases = {} :: { [purchase_key]: number },
	products = {},
	passes = {},

	cash = 0,
}
