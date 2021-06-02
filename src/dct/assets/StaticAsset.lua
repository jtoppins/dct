--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Static asset, represents assets that do not move.
--
-- StaticAsset<DCSObjects>:
--   has associated DCS objects, has death goals related to the
--   state of the DCS objects, the asset does not move
--]]

local enum     = require("dct.enum")
local dctutils = require("dct.utils")
local vector   = require("dct.libs.vector")
local DCSObjects = require("dct.assets.DCSObjects")

local StaticAsset = require("libs.namedclass")("StaticAsset", DCSObjects)
function StaticAsset:__init(template)
	DCSObjects.__init(self, template)
end

function StaticAsset.assettypes()
	return {
		enum.assetType.OCA,
		enum.assetType.BASEDEFENSE,
		enum.assetType.SHORAD,
		enum.assetType.SPECIALFORCES,
		enum.assetType.AMMODUMP,
		enum.assetType.FUELDUMP,
		enum.assetType.C2,
		enum.assetType.EWR,
		enum.assetType.MISSILE,
		enum.assetType.PORT,
		enum.assetType.SAM,
		enum.assetType.FACILITY,
		enum.assetType.BUNKER,
		enum.assetType.CHECKPOINT,
		enum.assetType.FACTORY,
		enum.assetType.FOB,
		enum.assetType.LOGISTICS,
	}
end

function StaticAsset:getLocation()
	if self._location == nil then
		local vec2, n
		for _, grp in pairs(self._assets) do
			vec2, n = dctutils.centroid2D(grp.data, vec2, n)
		end
		vec2.z = nil
		self._location = vector.Vector3D(vec2, land.getHeight(vec2)):raw()
	end
	return DCSObjects.getLocation(self)
end

return StaticAsset
