local fs = require("@lune/fs")
local serde = require("@lune/serde")

local function generate_mock_uploads(input)
	local output = {}
	for _, env in input.environments do
		local products = {}
		for name, product in input.target.experience.products do
			products[name] = product
			product.productId = 0
			product.assetId = 0
			product.icon = nil
		end

		local placeConfiguration = {}
		local places = {}
		for name, place in input.target.experience.places do
			places[name] = { assetId = 0, isStart = name == "start" }
			placeConfiguration[name] = place.configuration
		end

		output[env.label] = {
			product = products,
			place = places,
			experience = {
				singleton = {
					assetId = 0,
					groupId = input.owner.group,
					startPlaceId = places.start.assetId,
				},
			},
		}
	end
	return output
end
local function generate_real_uploads(state)
	local output = {}
	for env, uploads in state.environments do
		local out_uploads = {}
		for _, upload in uploads do
			local kind, id = upload.id:match("(%w+)_(.+)")
			local name, ext = id:match("(.*)%.(%w+)$")

			if kind == "asset" and ext == "png" then
				kind = "imageAsset"
				id = name
			end
			if not kind or not id then
				continue
			end

			local upload_input = upload.inputs[kind]
			local upload_output = upload.outputs[kind]

			if not upload_input then
				print(upload)
			end
			local out_upload = table.clone(upload_input)
			if typeof(upload_output) == "table" then
				for i, v in upload_output do
					out_upload[i] = v
				end
			end

			out_uploads[kind] = out_uploads[kind] or {}
			out_uploads[kind][id] = out_upload
		end
		output[env] = out_uploads
	end
	return output
end

local output = if fs.isFile(".mantle-state.yml")
	then generate_real_uploads(serde.decode("yaml", fs.readFile(".mantle-state.yml")))
	else generate_mock_uploads(serde.decode("yaml", fs.readFile("mantle.yml")))

fs.writeDir("dist")
fs.writeDir("dist/mantle")
fs.writeFile("dist/mantle/uploads.toml", serde.encode("toml", output))
