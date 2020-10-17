--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides functions for handling Assets.
-- An Asset is a group of objects in the game world
-- that can be destroyed by the opposing side.
--]]

local dctenum  = require("dct.enum")

local Asset = {}

function Asset.factory(template, region)
	local assettype = template.objtype
	local asset = nil
	if assettype == dctenum.assetType.AIRSPACE then
		asset = require("dct.assets.Airspace")
	elseif dctenum.assetClass.STRATEGIC[assettype] or
	       assettype == dctenum.assetType.BASEDEFENSE then
		asset = require("dct.assets.StaticAsset")
	elseif assettype == dctenum.assetType.PLAYERGROUP then
		asset = require("dct.assets.Player")
	else
		assert(false, "unsupported asset type: "..assettype)
	end
	return asset(template, region)
end

Asset.Manager = require("dct.assets.AssetManager")

return Asset
