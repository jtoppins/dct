--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides functions to define and manage death goals
-- for DCS objects tracked by assets.
--]]

local class = require("libs.class")
local Logger = require("dct.libs.Logger").getByName("DeathGoal")

local objtype = {
	["UNIT"]    = 1,
	["STATIC"]  = 2,
	["GROUP"]   = 3,
	["SCENERY"] = 4,
}

local priority = {
	["PRIMARY"]   = 1,
	["SECONDARY"] = 2,
}

local function get_scenery_obj(id)
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

local function getobject(ot, name)
	local getobj = {
		[objtype.UNIT]   = Unit.getByName,
		[objtype.STATIC] = StaticObject.getByName,
		[objtype.GROUP]  = Group.getByName,
		[objtype.SCENERY]= get_scenery_obj,
	}
	local getlifefuncs = {
		[objtype.UNIT]   = Unit.getLife,
		[objtype.STATIC] = StaticObject.getLife,
		[objtype.GROUP]  = get_group_size,
		[objtype.SCENERY]= SceneryObject.getLife,
	}

	return getobj[ot](name), getlifefuncs[ot]
end

local DamageGoal = class()
function DamageGoal:__init(data)
	assert(type(data.value) == 'number',
		"value error: data.value must be a number")
	assert(data.value >= 0 and data.value <= 100,
		"value error: data.value must be between 0 and 100")
	self.priority   = data.priority or priority.PRIMARY
	self.objtype    = data.objtype
	self.name       = data.name
	self.groupname  = self.name
	self._complete  = false
	self._tgtdamage = data.value
end

function DamageGoal:_setComplete()
	self._complete = true
	return self._complete
end

function DamageGoal:isComplete()
	return self._complete
end

function DamageGoal:getName()
	return self.name
end

--[[
-- There are some things that need to be done once the object being tracked
-- by this goal has been spawned. This provides a generic interface for
-- handling this work.
--
-- We need to know the group name associated with a unit name because that
-- is how the Asset's template is organized. The easiest way to find that
-- association is to just let the engine tell us once the unit has been
-- spawned.
--
-- We don't need the group information until the unit is spawned anyway.
--]]
function DamageGoal:onSpawn()
	if self.objtype == objtype.UNIT then
		self.groupname = Unit.getByName(self.name):getGroup():getName()
	end

	local obj, getlife = getobject(self.objtype, self.name)
	if obj == nil or not Object.isExist(obj) and
	   not Group.isExist(obj) then
		Logger:error("onSpawn() - object '%s' doesn't exist,"..
			" presumed dead", self.name)
		self:_setComplete()
		return
	end

	local life = getlife(obj)
	if life == nil or life < 1 then
		Logger:error("onSpawn() - object '%s' initial life value is"..
			" nil or below 1: %s",
			tostring(self.name), tostring(life))
		self._maxlife = 1
	else
		self._maxlife = life
	end

	Logger:debug("onSpawn() - goal: %s",
		require("libs.json"):encode_pretty(self))
end

-- cannot be called until after the object is spawned
function DamageGoal:getGroupName()
	return self.groupname
end

--[[--
-- Check if to goal has been met, if it has return true
--
-- @return: true or false
--
-- Note: game objects can be removed out from under us, so
-- verify the lookup by name yields an object before using it
--]]
function DamageGoal:checkComplete()
	if self:isComplete() then
		return true
	end

	local status = self:getStatus()
	Logger:debug("checkComplete() - status: %.2f%%", status)

	if status >= self._tgtdamage then
		return self:_setComplete()
	end
	return false
end

--[[--
-- Get the percentage damage taken by the tracked DCS object.
-- Return a number between 0 and 100.
--
-- @return: percentage damage taken by the DCS object
--]]
function DamageGoal:getStatus()
	if self:isComplete() then
		return 100
	end

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
	return (1 - (health/self._maxlife)) * 100
end

--[[
-- data - a description of a Goal object, its fields are:
--
--   * [required] goaltype - defines the specific goal object to create
--   * [required] objtype  - the type of DCS object to be monitored
--   * [required] value    - an opaque value defining further details about
--                           a specific goal type, for example a damage type
--                           goal would define a number for how much damage
--                           a DCS game object would need to take before it
--                           was considered 'complete'.
--   * [optional] priority - specifies the overall priority of the goal
--                           right now only PRIMARY goals are tracked in
--                           objectives. (Default: is to set goal priority
--                           to PRIMARY)
--
-- name - the name of the DCS object
--]]
local Goal = {}
function Goal.factory(name, data)
	assert(type(name) == 'string', "value error, name")
	assert(type(data) == 'table', "value error, data")

	data.name = name
	return DamageGoal(data)
end

Goal.priority = priority
Goal.objtype  = objtype

return Goal
