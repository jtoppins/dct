--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Represents an airspace.
-- Airspaces cannot die (i.e. be deleted), track zero-sum influence of
-- which side "controls" the space, and spawn nothing
--]]

local class = require("libs.class")
local AssetBase = require("dct.assets.AssetBase")

local Airspace = class(AssetBase)
function Airspace:__init(template, region)
	self.__clsname = "Airspace"
	AssetBase.__init(self, template, region)
	self:_addMarshalNames({
		"_location",
		"_volume",
	})
end

function Airspace:_completeinit(template, region)
	AssetBase._completeinit(self, template, region)
	assert(template.location ~= nil,
		"runtime error: Airspace requires template to define a location")
	self._location = template.location
	assert(template.volume ~= nil,
		"runtime error: Airspace requires template to define a volume")
	self._volume = template.volume
end

-- TODO: need to figure out how to track influence within this space

return Airspace
