--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides functions to define and manage goals.
--]]

local class    = require("libs.class")
local enums    = require("dct.goals.enum")
local BaseGoal = require("dct.goals.BaseGoal")
local Logger   = dct.Logger.getByName("Goal")

local function getobject(objtype, name)
	local switch = {
		[enums.objtype.UNIT]   = Unit.getByName,
		[enums.objtype.STATIC] = StaticObject.getByName,
		[enums.objtype.GROUP]  = Group.getByName,
		[enums.objtype.SCENERY]=
			function(n)
				return { id_ = tonumber(n), }
			end
	}
	local lifefncs = {
		[enums.objtype.UNIT]   = Unit.getLife0,
		[enums.objtype.STATIC] = StaticObject.getLife,
		[enums.objtype.GROUP]  = Group.getInitialSize,
		[enums.objtype.SCENERY]= SceneryObject.getLife,
	}

	local obj = nil
	if switch[objtype] ~= nil then
		obj = switch[objtype](name)
	end
	return obj, lifefncs[objtype]
end

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
	local obj, getlife = getobject(self.objtype, self.name)
	if obj == nil then
		Logger:error("DamageGoal:_afterspawn() - object doesn't exist")
		self:_setComplete()
		return
	end

	local life = getlife(obj)
	if life ~= nil and life == 0 and self.objtype == enums.objtype.UNIT then
		self._maxlife = obj:getLife()
		Logger:warn("DamageGoal:_afterspawn() - maxlife reported"..
			" as 0 using life: "..self._maxlife)
	else
		self._maxlife = life or 2500
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
	elseif self.objtype == enums.objtype.SCENERY then
		local obj = { id_ = tonumber(self.name) }
		health = SceneryObject.getLife(obj)
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
