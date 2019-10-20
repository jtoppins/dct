--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides functions to define and manage goals.
--]]

local class    = require("libs.class")
local enums    = require("dct.goals.enum")
local BaseGoal = require("dct.goals.BaseGoal")
local Logger   = require("dct.Logger").getByName("Goal")

local DamageGoal = class(BaseGoal)
function DamageGoal:__init(data)
	assert(type(data.value) == 'number',
		"value error: data.value must be a number")
	BaseGoal.__init(self, data)
	self._tgtdamage = data.value
end

function DamageGoal:_afterspawn()
	self._maxlife = 1
	if self.objtype == enums.objtype.UNIT then
		self._maxlife = Unit.getByName(self.name):getLife0()
	elseif self.objtype == enums.objtype.STATIC then
		self._maxlife = StaticObject.getByName(self.name):getLife()
	elseif self.objtype == enums.objtype.GROUP then
		self._maxlife = Group.getByName(self.name):getInitialSize()
	else
		Logger:error("DamageGoal:__afterspawn() - invalid objtype")
	end
end

function DamageGoal:checkComplete()
	local c = self:isComplete()
	if c then return c end

	local health
	if self.objtype == enums.objtype.UNIT then
		health = Unit.getByName(self.name):getLife()
	elseif self.objtype == enums.objtype.STATIC then
		health = StaticObject.getByName(self.name):getLife()
	elseif self.objtype == enums.objtype.GROUP then
		health = Group.getByName(self.name):getSize()
	else
		Logger:error("DamageGoal:checkComplete() - invalid objtype")
		return false
	end

	local damagetaken = (1 - (health/self._maxlife)) * 100
	if damagetaken > self._tgtdamage then
		return self:_setComplete()
	end
	return false
end

return DamageGoal
