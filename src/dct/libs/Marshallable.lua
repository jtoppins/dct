-- SPDX-License-Identifier: LGPL-3.0

require("libs")

local class  = libs.class
local utils  = libs.utils

--- Implements a generic [un]marshal construct that can be inherited
-- by other classes that need to impletment marshaling.
--
-- If the inheriting class implements a method "_unmarshalpost(data)"
-- then this method will be run after the object has been reconstructed.
-- This is to account for any special processing that needs to be
-- done due to the serialization process. 'data' is the table of raw
-- seralized data from which the object was reconstructed from.
-- @classmod dct.libs.Marshallable
local Marshallable = class()

--- Constructor.
function Marshallable:__init()
	self._marshalnames = {}
end

--- Add members of the class to the list of items to be marshalled.
-- @param list list of items to track and serialize when requested.
-- @return none
function Marshallable:_addMarshalNames(list)
	for _, name in ipairs(list) do
		self._marshalnames[name] = true
	end
end

--- Marshal the object for serialization.
-- @param copy function to use to copy table members in the object
--        by default dct.libs.utils.shallowclone is used to copy any
--        tables that are encountered.
-- @return table representing object
function Marshallable:marshal(copy)
	copy = copy or utils.shallowclone
	local tbl = {}
	for attribute, _ in pairs(self._marshalnames or {}) do
		assert(type(self[attribute]) ~= "function",
			"value error: cannot marshal functions")
		tbl[attribute] = copy(self[attribute])
	end
	if next(tbl) == nil then
		return nil
	end
	return tbl
end

--- Unmarshal the object from a seralized stream. 'data' is just a table
-- representing what was returned by the marshal method above.
-- @param data the raw table of seralized data from which the object is
--             reconstructed.
-- @return none
function Marshallable:unmarshal(data)
	utils.mergetables(self, data)
	if type(self["_unmarshalpost"]) == "function" then
		self:_unmarshalpost(data)
	end
end

return Marshallable
