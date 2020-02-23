--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Represents a null collection.
-- A null collection that doesn't die, is always spawned, never
-- reduces status, and is not associated with any DCS objects
--]]

local class = require("libs.class")
local IDCSObjectCollection = require("dct.dcscollections.IDCSObjectCollection")

local NullCollection = class(IDCSObjectCollection)
function NullCollection:__init(asset, template, region)
	IDCSObjectCollection.__init(self, asset, template, region)
end

return NullCollection
