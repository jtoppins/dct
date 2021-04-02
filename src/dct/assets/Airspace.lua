--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Represents an airspace.
-- Airspaces cannot die (i.e. be deleted), track zero-sum influence of
-- which side "controls" the space, and spawn nothing
--]]

local vector = require("dct.libs.vector")
local AssetBase = require("dct.assets.AssetBase")

local Airspace = require("libs.namedclass")("Airspace", AssetBase)
function Airspace:__init(template)
	AssetBase.__init(self, template)
	self:_addMarshalNames({
		"_location",
		"_volume",
	})
end

function Airspace.assettypes()
	return {
		require("dct.enum").assetType.AIRSPACE,
	}
end

function Airspace:_completeinit(template)
	AssetBase._completeinit(self, template)
	assert(template.location ~= nil,
		"runtime error: Airspace requires template to define a location")
	self._location = vector.Vector3D(template.location):raw()
	assert(template.volume ~= nil,
		"runtime error: Airspace requires template to define a volume")
	self._volume = template.volume
end

-- TODO: need to figure out how to track influence within this space

return Airspace
