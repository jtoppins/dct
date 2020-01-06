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
	assert(data.value >= 0 and data.value <= 100,
		"value error: data.value must be between 0 and 100")
	BaseGoal.__init(self, data)
	self._tgtdamage = data.value
end

function DamageGoal:_afterspawn()
	self._maxlife = 1
	if self.objtype == enums.objtype.UNIT then
		self._maxlife = Unit.getByName(self.name):getLife0()
		if self._maxlife == 0 then
			self._maxlife = Unit.getByName(self.name):getLife()
			Logger:warn("DamageGoal:_afterspawn() - maxlife reported"..
				" as 0 using life: "..self._maxlife)
		end
	elseif self.objtype == enums.objtype.STATIC then
		self._maxlife = StaticObject.getByName(self.name):getLife()
	elseif self.objtype == enums.objtype.GROUP then
		self._maxlife = Group.getByName(self.groupname):getInitialSize()
	else
		Logger:error("DamageGoal:_afterspawn() - invalid objtype")
	end
	Logger:debug("DamageGoal:_afterspawn() - goal:\n"..
		require("libs.json"):encode_pretty(self))
end

-- Note: game objects can be removed out from under us, so
-- verify the lookup by name yields an object before using it
function DamageGoal:checkComplete()
	if self:isComplete() then return true end

	local health = 0
	if self.objtype == enums.objtype.UNIT then
		local obj = Unit.getByName(self.name)
		if obj ~= nil then
			health = obj:getLife()
		end
	elseif self.objtype == enums.objtype.STATIC then
		local obj = StaticObject.getByName(self.name)
		if obj ~= nil then
			health = obj:getLife()
		end
	elseif self.objtype == enums.objtype.GROUP then
		local obj = Group.getByName(self.groupname)
		if obj ~= nil then
			health = obj:getSize()
		end
	else
		Logger:error("DamageGoal:checkComplete() - invalid objtype")
		return false
	end

	Logger:debug(string.format("DamageGoal:checkComplete() - "..
		"name: '%s'; health: %3.2f; maxlife: %d",
		self.name, health, self._maxlife))

	local damagetaken = (1 - (health/self._maxlife)) * 100
	if damagetaken > self._tgtdamage then
		return self:_setComplete()
	end
	return false
end

return DamageGoal
