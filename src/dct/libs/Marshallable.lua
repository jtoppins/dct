--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Implements a Marshallable interface
--]]

local class  = require("libs.class")
local utils  = require("libs.utils")

--[[
-- Implements a generic [un]marshal construct that can be inherited
-- by other classes that need to impletment marshaling.
--
-- If the inheriting class implements a method "_unmarshalpost(data)"
-- then this method will be run after the object has been reconstructed.
-- This is to account for any special processing that needs to be
-- done due to the serialization process. 'data' is the table of raw
-- unseralized data from which the object was reconstructed from.
--]]
local Marshallable = class()
function Marshallable:__init()
	self._marshalnames = {}
end

--[[
-- Add members of the class to the list of items to be marshalled.
-- Returns: none
--]]
function Marshallable:_addMarshalNames(list)
	for _, name in ipairs(list) do
		self._marshalnames[name] = true
	end
end

--[[
-- Marshal the object for serialization.
-- Returns: table representing object
--]]
function Marshallable:marshal()
	local tbl = {}
	for attribute, _ in pairs(self._marshalnames or {}) do
		assert(type(self[attribute]) ~= "function",
			"value error: cannot marshal functions")
		tbl[attribute] = self[attribute]
	end
	return tbl
end

--[[
-- Unmarshal the object from a seralized stream. 'data' is just a table
-- representing what was returned by the marshal method above.
-- Returns: none
--]]
function Marshallable:unmarshal(data)
	utils.mergetables(self, data)
	if type(self["_unmarshalpost"]) == "function" then
		self:_unmarshalpost(data)
	end
end

return Marshallable
