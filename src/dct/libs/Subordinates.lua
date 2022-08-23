-- SPDX-License-Identifier: LGPL-3.0

--- @classmod Subordinates
-- Implements a Subordinate interface that has observable properties.
-- This means the object inheriting this class has subordinate objects
-- that are assumed to be observers of the object as well.

local class = require("libs.class")

local Subordinates = class()

--- constructor
--
-- @field _subordinates hashmap(name, true) of asset names
-- @field _parent name of asset to which this object is a child
function Subordinates:__init()
	self._parent = false
	self._subordinates = {}
	if not self._subeventhandlers then
		self._subeventhandlers = {}
	end
end

--- [static method] gets fields that need to be marshalled
function Subordinates.getNames()
	return { "_subordinates", "_parent", }
end

--- set parent asset name
--
-- @param parent the asset object that is the parent of this object
function Subordinates:setParent(parent)
	self._parent = parent.name
end

--- iterate over all subordinate names
--
-- @return an iterator used in a for loop
function Subordinates:iterateSubordinates()
	return next, self._subordinates, nil
end

--- Process a DCS or DCT event.
--
-- @param event the event to process
-- @return none
function Subordinates:onSubEvent(event)
	local handler = self._subeventhandlers[event.id]
	if handler ~= nil then
		handler(self, event)
	end
end

--- set `obj` as a subordinate of this object
--
-- @param obj the asset object to set as a subordinate of this object
function Subordinates:addSubordinate(obj)
	assert(obj ~= nil,
		"value error: 'obj' must not be nil")
	self._subordinates[obj.name] = true
end

--- remove a subordinate from this object
--
-- @param name [string] name of the object
function Subordinates:removeSubordinate(name)
	self._subordinates[name] = nil
end

return Subordinates
