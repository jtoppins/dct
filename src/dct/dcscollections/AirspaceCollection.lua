--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Represents an airspace.
-- AirspaceCollection<IDCSObjectCollection>:
-- * DCS-objects, none associated with an airspace
-- * invincible, asset cannot die (i.e. be deleted)
-- * status, track zero-sum influence of which side "controls"
--   this region
-- * spawn, nothing to spawn
--]]

local class = require("libs.class")
local IDCSObjectCollection = require("dct.dcscollections.IDCSObjectCollection")

local AirspaceCollection = class(IDCSObjectCollection)
function AirspaceCollection:__init(asset, template, region)
	self._marshalnames = {"_location", "_volume"}
	IDCSObjectCollection.__init(self, asset, template, region)
end

function AirspaceCollection:_completeinit(template, _)
	assert(template.location ~= nil,
		"runtime error: AirspaceCollection requires template to"..
		" define a location")
	self._location = template.location
	assert(template.volume ~= nil,
		"runtime error: AirspaceCollection requires template to"..
		" define a volume")
	self._volume = template.volume
end

function AirspaceCollection:getLocation()
	return self._location
end

return AirspaceCollection
