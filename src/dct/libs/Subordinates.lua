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
-- @field _parent reference to object to which this object is a child
function Subordinates:__init()
	self._parent = false
	self._subordinates = {}
end

--- [static method] gets fields that need to be marshalled
function Subordinates.getNames()
	return { "_subordinates", "_parent", }
end

--- set parent object
--
-- @param parent the object that is the parent of this object
function Subordinates:setParent(parent)
	if parent == nil then
		self._parent = nil
	else
		self._parent = parent.name
	end
end

--- get parent object
--
-- @return parent object that is the parent of this object
function Subordinates:getParent()
	return self._parent
end

--- iterate over all subordinate names
--
-- @return an iterator used in a for loop
function Subordinates:iterateSubordinates()
	return next, self._subordinates, nil
end

--- set `obj` as a subordinate of this object
--
-- @param obj the asset object to set as a subordinate of this object
function Subordinates:addSubordinate(obj)
	assert(obj ~= nil, "value error: 'obj' must not be nil")
	self._subordinates[obj.name] = true
	obj:setParent(self)
end

--- remove a subordinate from this object
--
-- @param name [string] name of the object
function Subordinates:removeSubordinate(name)
	self._subordinates[name] = nil
end

return Subordinates
