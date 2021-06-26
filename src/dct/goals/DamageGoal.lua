--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides functions to define and manage goals.
--]]

local class    = require("libs.class")
local enums    = require("dct.goals.enum")
local BaseGoal = require("dct.goals.BaseGoal")
local Logger   = require("dct.libs.Logger").getByName("DamageGoal")

local function get_scenery_life(obj)
	-- In case a scenery object cannot be acessed by the scripting engine yet,
	-- return a placeholder value
	if not SceneryObject.isExist(obj) then
		return 1
	end
	return SceneryObject.getLife(obj)
end

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
	local switch = {
		[enums.objtype.UNIT]   = Unit.getByName,
		[enums.objtype.STATIC] = StaticObject.getByName,
		[enums.objtype.GROUP]  = Group.getByName,
		[enums.objtype.SCENERY]= get_scenery_id,
	}
	local getlifefncs = {
		[enums.objtype.UNIT]   = Unit.getLife,
		[enums.objtype.STATIC] = StaticObject.getLife,
		[enums.objtype.GROUP]  = get_group_size,
		[enums.objtype.SCENERY]= get_scenery_life,
	}

	local obj = nil
	if switch[objtype] ~= nil then
		obj = switch[objtype](name)
	end
	local lifetbl = getlifefncs
	return obj, lifetbl[objtype]
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
	if obj == nil then
		Logger:error("_afterspawn() - object '%s' doesn't exist", self.name)
		self:_setComplete()
		return
	end

	local life = getlife(obj)
	if life == nil or life < 1 then
		Logger:error("_afterspawn() - object '%s' life value is nil or "..
			"below 1: %s", tostring(life))
		life = 1
	end

	self._maxlife = life

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
	end

	Logger:debug("getStatus() - name: '%s'; health: %.2f; maxlife: %.2f",
		self.name, health, self._maxlife)

	local damagetaken = (1 - (health/self._maxlife)) * 100
	if damagetaken > self._tgtdamage then
		return self:_setComplete()
	end
	return false
end

return DamageGoal
