--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides functions to define and manage goals.
--]]

local class    = require("libs.class")
local enums    = require("dct.goals.enum")
local BaseGoal = require("dct.goals.BaseGoal")
local Logger   = require("dct.libs.Logger").getByName("DamageGoal")

local function get_scenery_id(id)
	return { id_ = tonumber(id), }
end

-- counts the number of alive units in the group manually, because
-- Group.getSize() can return an outdated value during death events
local function get_group_size(grp)
	local alive = 0
	for _, unit in pairs(grp:getUnits()) do
		-- Unit.getLife() uses a value lesser than 1 to indicate that
		-- the unit is dead
		if unit ~= nil and unit:getLife() >= 1 then
			alive = alive + 1
		end
	end
	return alive
end

local function getobject(objtype, name)
	local getobj = {
		[enums.objtype.UNIT]    = Unit.getByName,
		[enums.objtype.STATIC]  = StaticObject.getByName,
		[enums.objtype.GROUP]   = Group.getByName,
		[enums.objtype.SCENERY] = get_scenery_id,
	}
	local getlifefncs = {
		[enums.objtype.UNIT]    = Unit.getLife,
		[enums.objtype.STATIC]  = StaticObject.getLife,
		[enums.objtype.GROUP]   = get_group_size,
		[enums.objtype.SCENERY] = SceneryObject.getLife,
	}

	local obj = getobj[objtype](name)
	return obj, getlifefncs[objtype]
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
	local obj, getlife = getobject(self.objtype, self.name)
	if obj == nil or not Object.isExist(obj) and not Group.isExist(obj) then
		Logger:error("_afterspawn() - object '%s' doesn't exist, presumed dead",
			self.name)
		self:_setComplete()
		return
	end

	local life = getlife(obj)
	if life == nil or life < 1 then
		Logger:error("_afterspawn() - object '%s' initial life value is nil or "..
			"below 1: %s", tostring(self.name), tostring(life))
		self._maxlife = 1
	else
		self._maxlife = life
	end

	Logger:debug("_afterspawn() - goal: %s",
		require("libs.json"):encode_pretty(self))
end

-- Note: game objects can be removed out from under us, so
-- verify the lookup by name yields an object before using it
function DamageGoal:checkComplete()
	if self:isComplete() then return true end
	local status = self:getStatus()

	Logger:debug("checkComplete() - status: %.2f%%", status)

	if status >= self._tgtdamage then
		return self:_setComplete()
	end
end

-- returns the completion percentage of the damage goal
function DamageGoal:getStatus()
	if self:isComplete() then return 100 end

	local health = 0
	local obj, getlife = getobject(self.objtype, self.name)
	if obj ~= nil then
		health = getlife(obj)
		if health == nil then
			Logger:warn("getStatus() - object '%s' health value is nil",
				self.name)
			health = 0
		end
	end

	Logger:debug("getStatus() - name: '%s'; health: %.2f; maxlife: %.2f",
		self.name, health, self._maxlife)

	local damagetaken = (1 - (health/self._maxlife)) * 100
	if damagetaken > self._tgtdamage then
		self:_setComplete()
		return 100
	end
	return damagetaken
end

return DamageGoal
