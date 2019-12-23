--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides functions for handling Assets.
-- An Asset is a group of objects in the game world
-- that can be destroyed by the opposing side.
--]]

local class    = require("libs.class")
local utils    = require("libs.utils")
local Template = require("dct.Template")
local Goal     = require("dct.Goal")
local Logger   = require("dct.Logger").getByName("Asset")
local settings = _G.dct.settings

local function defaultgoal(static)
	local goal = {}
	goal.priority = Goal.priority.PRIMARY
	goal.goaltype = Goal.goaltype.DAMAGE
	goal.objtype  = Goal.objtype.GROUP
	goal.value    = 90

	if static then
		goal.objtype = Goal.objtype.STATIC
	end
	return goal
end

-- TODO: create a codename generator, also move to a
-- common utilities library
local function generateCodename()
	return "write-codename-generator"
end

local Asset = class()
function Asset:__init(template, region)
	self._initcomplete = false
	-- dirty bit used to determine if its internal state has changed
	self._dirty      = false
	self._spawned    = false
	self._dead       = false
	self._targeted   = false
	self._deathgoals = {}
	self._assets     = {}

	if template ~= nil and region ~= nil then
		self._hasDeathGoals = template.hasDeathGoals
		self._tpldata   = template:copyData()
		self.owner      = template.coalition
		self["type"]    = template.objtype
		self.name       = region.name.."_"..self.owner.."_"..template.name
		self.regionname = region.name
		self.codename   = generateCodename()
		self.priority   = region.priority * 65536 + template.priority
		self:_setupmaps()
		self._initcomplete = true
		assert(next(self._deathgoals) ~= nil, "deathgoals nil")
	end
end

-- ignore all but primary targets when it comes to determining
-- if an Asset is "dead"
function Asset:_addDeathGoal(name, goalspec)
	assert(name ~= nil and type(name) == "string", "name must be provided")
	assert(goalspec ~= nil, "goalspec must be provided")

	if goalspec.priority ~= Goal.priority.PRIMARY then
		return
	end

	self._deathgoals[name] = Goal.factory(name, goalspec)
end

--[[
-- This function needs to do three things:
--   mark the object(unit/static/group) in the template dead, dct_dead == true
--   remove deathgoal entry
--   set dirty bit
--   upon no more deathgoals set dead
--]]
function Asset:_removeDeathGoal(name, goal)
	assert(name == nil, "name must be provided")
	assert(goal == nil, "goal must be provided")

	if self:isDead() then
		Logger:error("_removeDeathGoal() called and Asset("..
			self:getName()..") marked as dead")
		return
	end

	local grpdata = self._assets[goal:getGroupName()]
	if grpdata.name == name then
		grpdata.dct_dead = true
		self:_setDirty()
	else
		assert(grpdata.units ~= nil, "no units found, this is a problem")
		for _, unit in ipairs(grpdata.units) do
			if unit.name == name then
				unit.dct_dead = true
				self:_setDirty()
				break
			end
		end
	end

	self._deathgoals[name] = nil
	if next(self._deathgoals) == nil then
		self:_setDead()
	end
end

--[[
-- Adds a death goal to an Asset class, which determines
-- when an Asset is determined to be dead. If no death
-- goals have been defined a default of 90% damaged for all
-- objects in the Asset is used.
--]]
function Asset:_setupDeathGoal(grpdata, static)
	if self._hasDeathGoals then
		if grpdata.dct_deathgoal ~= nil then
			self:_addDeathGoal(grpdata.name, grpdata.dct_deathgoal)
		end
		for _, unit in ipairs(grpdata.units or {}) do
			if unit.dct_deathgoal ~= nil then
				self:_addDeathGoal(unit.name, unit.dct_deathgoal)
			end
		end
	else
		self:_addDeathGoal(grpdata.name, defaultgoal(static))
	end
end

--[[
-- Adds an object (group or static) to the monitored list for this
-- asset. This list will be needed later to save state.
--]]
function Asset:_setupmaps()
	for cat_idx, cat_data in pairs(self._tpldata) do
		for _, grp in ipairs(cat_data) do
			self:_setupDeathGoal(grp.data, cat_idx == 'static')
			self._assets[grp.data.name] = grp.data
		end
	end
end

function Asset:isTargeted()
	return self._targeted
end

function Asset:setTargeted(val)
	assert(type(val) == "boolean",
		"value error: argument must be of type bool")
	self._targeted = val
end

function Asset:isSpawned()
	return self._spawned
end

function Asset:_setDirty()
	self._dirty = true
end

function Asset:isDirty()
	return self._dirty
end

function Asset:getName()
	return self.name
end

function Asset:getPriority()
	-- TODO: the basic priority is:
	--      region.prio * 2^16 + template.prio
	-- but we may later want to deprioritize certian types of objectives
	-- so this can be provided here as a way to get a dynamic priority
	return self.priority
end

function Asset:_setDead()
	self._dead = true
end

function Asset:isDead()
	return self._dead
end

-- TODO: use a bit to denote checking needs to take place
-- change the function to accept an optional force option
-- to force a check, this will require a change to the
-- Asset dcs event handler to change the bit when an
-- asset is hit.
function Asset:checkDead()
	assert(self:isSpawned() == true, "Asset:checkDead(), must be spawned")

	for name, goal in pairs(self._deathgoals) do
		if goal:checkComplete() then
			self:_removeDeathGoal(name, goal)
		end
	end
end

-- Get the names of all DCS objects associated with this
-- Asset class.
function Asset:getObjectNames()
	local keyset = {}
	local n      = 0
	for k,_ in pairs(self._assets) do
		n = n+1
		keyset[n] = k
	end
	return keyset
end

function Asset:onDCSEvent(event)
	local obj = event.initiator

	if event.id == world.event.S_EVENT_DEAD then
		-- mark the unit/group/static as dead in the template, dct_dead
		-- set dirty bit
		local unitname = obj:getName()
		if obj:getCategory() == Object.Category.UNIT then
			local grpname = obj:getGroup():getName()
			local grp = self._assets[grpname]
			for _, unit in pairs(grp.units) do
				if unit.name == unitname then
					unit.dct_dead = true
					break
				end
			end
		else
			self._assets[unitname].dct_dead = true
		end
		self:_setDirty()
	end
end

local dctkeys = {
	["dct_deathgoal"] = true,
	["dct_dead"]      = true
}

-- modifies 'tbl' with 'keys' keys removed from 'tbl'
local function removekeys(tbl, keys)
	for k, _ in pairs(keys) do
		tbl[k] = nil
	end
end

-- returns a copy of 'grp' with all dct table keys removed
local function removeDCTKeys(grp)
	local g = utils.deepcopy(grp)
	removekeys(g.data, dctkeys)
	for _, unit in ipairs(g.data.units or {}) do
		removekeys(unit, dctkeys)
	end
	return g
end

function Asset:_spawn()
	for cat_idx, cat_data in pairs(self._tpldata) do
		for _, grp in ipairs(cat_data) do
			local gcpy = removeDCTKeys(grp)
			if cat_idx == 'static' then
				coalition.addStaticObject(gcpy.countryid, gcpy.data)
			else
				coalition.addGroup(gcpy.countryid,
					Unit.Category[Template.categorymap[string.upper(cat_idx)]],
					gcpy.data)
			end
		end
	end

	self._spawned = true
	for _, goal in pairs(self._deathgoals) do
		goal:onSpawn()
	end
end

function Asset:spawn()
	if self:isSpawned() then
		Logger:error("runtime bug - asset already spawned")
		return
	end
	self:_spawn()
end

--[[
-- Filtering for marshaling:
--   for-all-units-and-groups:  // basically visit every object
--     if has dct_dead     // this check must be first
--         delete object or set dead state if static
--         // the object was killed in the game no need to keep
--         // to determine if the object is a static, check the category to
--         //   be == 'static'
--     if has dct_deathgoal and dct_deathgoal.completed == true
--	       remove dct_deathgoal entry
--	       // Why? if we mark completed == true we can just have the
--	       // goal factory check completed and return nil the next time
--	       // the objective is loaded. Oh wait if
--	       // dct_deathgoal.complete == true, that means this
--	       // group/static/unit is considered dead, so the object needs
--	       // to be removed, or if is a static set dead.
--	       // This is too complicated, why can't for any object that is
--	       // considered "dead" we just tag the object by adding
--	       // 'dct_dead' == true? Then if the object has a dct_deathgoal
--	       // tag and is static (defined by the deathgoal objtype)
--	       // then we can consider it for keeping and set the dead state
--	       // in the template definition.
--]]
-- TODO: this function is confusing and needs to be re-written
local function filterDeadObjects(tbl, grp)
	-- remove groups that are dead
	if grp.data.dct_dead == true then
		-- we either skip or if a static object that is a primary target
		-- we set dead
		if settings.spawn.deadobjects == false or
			grp.data.dct_deathgoal == nil then
			return
		end

		if not (grp.data.dct_deathgoal.priority == Goal.priority.PRIMARY and
			grp.data.dct_deathgoal.objtype == Goal.objtype.STATIC) then
			return
		end

		local gcpy = utils.deepcopy(grp)
		gcpy.data.dead = true
		table.insert(tbl, gcpy)
		-- we need to return here because the object is dead
		-- so nothing else to do, skip rest of function
		return
	end

	local gcpy = utils.deepcopy(grp)
	-- remove dead units from the group
	if grp.data.units then
		gcpy.data.units = {}
		for _, unit in ipairs(grp.data.units) do
			if unit.dct_dead ~= true then
				table.insert(gcpy.data.units, utils.deepcopy(unit))
			end
		end
	end
	table.insert(tbl, gcpy)
end

-- TODO: this needs to be reviewed
local function filterTemplateData(tpldata)
	local cpytbl = {}

	for cat_idx, cat_data in pairs(tpldata) do
		cpytbl[cat_idx] = {}
		for _, grp in ipairs(cat_data) do
			filterDeadObjects(cpytbl[cat_idx], grp)
		end
		if not next(cpytbl[cat_idx]) then
			cpytbl[cat_idx] = nil
		end
	end
	if not next(cpytbl) then
		cpytbl = nil
	end
	return cpytbl
end

function Asset:marshal(ignoredirty)
	assert(self._initcomplete == true, "init not complete")
	ignoredirty = ignoredirty or false
	if not ignoredirty and self:isDirty() then
		return nil
	end
	self._dirty = false

	-- TODO: if `filterTemplateData()` produces an empty table we should return a
	-- nil as there is no asset really available.
	local tbl = {}
	tbl._dead          = self._dead
	tbl._spawned       = self._spawned
	tbl._hasDeathGoals = self._hasDeathGoals
	tbl._tpldata       = filterTemplateData(self._tpldata)
	tbl.name           = self.name
	tbl.regionname     = self.regionname
	tbl.codename       = self.codename
	tbl.owner          = self.owner
	tbl["type"]        = self["type"]
	tbl.priority       = self.priority
	return tbl
end

function Asset:unmarshal(data)
	assert(self._initcomplete == false, "init completed already")
	utils.mergetables(self, data)
	self:_setupmaps()
	if self:isSpawned() then
		self:_spawn()
	end
	self:_setDirty()
	self._initcomplete = true
end

return Asset
