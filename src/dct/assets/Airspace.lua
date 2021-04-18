--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Represents an airspace.
-- Airspaces cannot die (i.e. be deleted), track zero-sum influence of
-- which side "controls" the space, and spawn nothing
--]]

local AssetBase = require("dct.assets.AssetBase")

local Airspace = require("libs.namedclass")("Airspace", AssetBase)
function Airspace:__init(template)
	AssetBase.__init(self, template)
	self:_addMarshalNames({
		"_radius",
	})
end

function Airspace.assettypes()
	return {
		require("dct.enum").assetType.AIRSPACE,
	}
end

function Airspace:_completeinit(template)
	AssetBase._completeinit(self, template)
	assert(template.radius ~= nil,
		"runtime error: Airspace requires template to define a radius")
	self._radius = template.radius
end

-- TODO: need to figure out how to track influence within this space

return Airspace
