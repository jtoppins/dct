--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Implements a Subordinate interface that has observable properties.
-- This means the object inheriting this class has subordinate objects
-- that are assumed to be observers of the object as well.
--]]

local class = require("libs.class")

local Subordinates = class()
function Subordinates:__init()
	self._subordinates = {}
	if not self._subeventhandlers then
		self._subeventhandlers = {}
	end
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

function Subordinates.getNames()
	return { "_subordinates", }
end

function Subordinates:addSubordinate(obj)
	assert(obj ~= nil,
		"value error: 'obj' must not be nil")
	self._subordinates[obj.name] = true
end

function Subordinates:removeSubordinate(name)
	self._subordinates[name] = nil
end

return Subordinates
