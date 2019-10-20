--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides functions to define and manage goals.
--]]

local class = require("libs.class")
local enums  = require("dct.goals.enum")

local BaseGoal = class()
function BaseGoal:__init(data)
	self.priority   = data.priority or enums.priority.PRIMARY
	self.objtype    = data.objtype
	self.name       = data.name
	self._complete = false
end

function BaseGoal:_setComplete()
	self._complete = true
	return self._complete
end

function BaseGoal:isComplete()
	return self._complete
end

function BaseGoal:getName()
	return self.name
end

-- There are some things that need to be done once the object being tracked
-- by this goal has been spawned. This provides a generic interface for
-- handling this work.
function BaseGoal:onSpawn()
	self.groupname = self.name
	if self.objtype == enums.objtype.GROUP then
		self.groupname = Unit.getByName(self.name):getGroup():getName()
	end

	if type(self._afterspawn) == 'function' then
		self:_afterspawn()
	end
end

function BaseGoal:getGroupName()
	return self.groupname
end

function BaseGoal:checkComplete()
	assert(false, "isComplete() is a virtual function and must be overridden")
end

return BaseGoal
