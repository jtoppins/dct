--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides functions for handling StaticCollections.
-- An BaseAsset is a group of objects in the game world
-- that can be destroyed by the opposing side.
--]]

require("math")
local class    = require("libs.class")
local utils    = require("libs.utils")
local Logger   = require("dct.Logger").getByName("Asset")
local dctutils = require("dct.utils")
local Goal     = require("dct.Goal")
local IDCSObjectCollection = require("dct.dcscollections.IDCSObjectCollection")
local settings = _G.dct.settings

--[[
StaticCollection<IDCSObjectCollection>:
	attributes(private):
	- _tpldata
	- _dead
	- _deathgoals

	methods(private):

-- StaticAsset
--    represents assets that do not move
--  difference from BaseAsset
	* DCS-objects, has associated DCS objects
		* objects do not move
		* has death goals due to having DCS objects
--]]

local StaticCollection = class(IDCSObjectCollection)
function StaticCollection:__init(asset, template, region)
	self._marshalnames = {
		"_dead", "_spawned", "_hasDeathGoals", "_maxdeathgoals",
	}
	self._spawned       = false
	self._dead          = false
	self._maxdeathgoals = 0
	self._curdeathgoals = 0
	self._deathgoals    = {}
	self._assets        = {}
	IDCSObjectCollection.__init(self, asset, template, region)
end

function StaticCollection:_completeinit(template, _ --[[region]])
	self._hasDeathGoals = template.hasDeathGoals
	self._tpldata       = template:copyData()
end

--[[
-- ignore all but primary targets when it comes to determining
-- if we are "dead"
--]]
function StaticCollection:_addDeathGoal(name, goalspec)
	assert(name ~= nil and type(name) == "string",
		"value error: name must be provided")
	assert(goalspec ~= nil, "value error: goalspec must be provided")

	if goalspec.priority ~= Goal.priority.PRIMARY then
		return
	end

	self._deathgoals[name] = Goal.factory(name, goalspec)
	self._curdeathgoals = self._curdeathgoals + 1
	self._maxdeathgoals = math.max(self._curdeathgoals, self._maxdeathgoals)
end

--[[
-- This function needs to do three things:
--   mark the object(unit/static/group) in the template dead,
--      dct_dead == true
--   remove deathgoal entry
--   upon no more deathgoals set dead
--]]
function StaticCollection:_removeDeathGoal(name, goal)
	assert(name ~= nil and type(name) == "string",
		"value error: name must be provided")
	assert(goal ~= nil, "value error: goal must be provided")

	Logger:debug("_removeDeathGoal() - obj name: "..name)
	if self:isDead() then
		Logger:error("_removeDeathGoal() called and StaticCollection("..
			self._asset.name..") marked as dead")
		return
	end

	local grpdata = self._assets[goal:getGroupName()]
	if grpdata.name == name then
		grpdata.dct_dead = true
	else
		assert(grpdata.units ~= nil, "no units found, this is a problem")
		for _, unit in ipairs(grpdata.units) do
			if unit.name == name then
				unit.dct_dead = true
				break
			end
		end
	end

	self._deathgoals[name] = nil
	self._curdeathgoals = self._curdeathgoals - 1
	if next(self._deathgoals) == nil then
		self:setDead(true)
	end
end

--[[
-- Adds a death goal, which determines when the Collection is determined
-- to be dead. If no death goals have been defined a default of 90%
-- damaged for all objects in the Collection is used.
--]]
function StaticCollection:_setupDeathGoal(grpdata, static)
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
		self:_addDeathGoal(grpdata.name,
			IDCSObjectCollection.defaultgoal(static))
	end
end

--[[
-- Adds an object (group or static) to the monitored list for this
-- asset. This list will be needed later to save state.
--]]
function StaticCollection:_setup()
	for _, grp in ipairs(self._tpldata) do
		self:_setupDeathGoal(grp.data,
			grp.category == Unit.Category.STRUCTURE)
		self._assets[grp.data.name] = grp.data
	end
	assert(next(self._deathgoals) ~= nil,
		"runtime error: StaticCollection must have a deathgoal: "..
		self._asset.name)
end

function StaticCollection:getLocation()
	if self._location == nil then
		local points = {}
		for k,v in pairs(self._assets) do
			points[k] = {
				["x"] = v.x, ["y"] = 0, ["z"] = v.y,
			}
		end

		self._location = dctutils.centroid(points)
	end
	return self._location
end

--[[
-- getStatus - percentage remaining of the asset from 0 - 100
--]]
function StaticCollection:getStatus()
	return math.floor((1 - (self._curdeathgoals / self._maxdeathgoals)) * 100)
end

function StaticCollection:setDead(val)
	self._dead = val
end

function StaticCollection:isDead()
	return self._dead
end

function StaticCollection:checkDead()
	assert(self:isSpawned() == true, "runtime error: asset must be spawned")

	local cnt = 0
	for name, goal in pairs(self._deathgoals) do
		cnt = cnt + 1
		if goal:checkComplete() then
			self:_removeDeathGoal(name, goal)
		end
	end
	Logger:debug(string.format("checkDead(%s) - max goals: %d; "..
		"cur goals: %d; checked: %d", self._asset.name,
		self._maxdeathgoals, self._curdeathgoals, cnt))
end

-- Get the names of all DCS objects associated with this
-- Asset class.
function StaticCollection:getObjectNames()
	local keyset = {}
	local n      = 0
	for k,_ in pairs(self._assets) do
		n = n+1
		keyset[n] = k
	end
	return keyset
end

function StaticCollection:onDCSEvent(event)
	-- only handle DEAD events
	if event.id ~= world.event.S_EVENT_DEAD then
		Logger:debug(string.format("onDCSEvent() - StaticCollection(%s)"..
		" not DEAD event, ignoring", self._asset.name))
		return
	end

	local obj = event.initiator

	-- mark the unit/group/static as dead in the template, dct_dead
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

	-- delete any deathgoal related to the unit notified as dead,
	-- this may work around any bug in DCS where the object is still
	-- kept and its health reports a non-zero value
	local goal = self._deathgoals[unitname]
	if goal ~= nil then
		self:_removeDeathGoal(unitname, goal)
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

function StaticCollection:_spawn()
	for _, grp in ipairs(self._tpldata) do
		local gcpy = removeDCTKeys(grp)
		if gcpy.category == Unit.Category.STRUCTURE then
			coalition.addStaticObject(gcpy.countryid, gcpy.data)
		else
			coalition.addGroup(gcpy.countryid, gcpy.category, gcpy.data)
		end
	end

	self._spawned = true
	for _, goal in pairs(self._deathgoals) do
		goal:onSpawn()
	end
end

function StaticCollection:spawn(ignore)
	if not ignore and self:isSpawned() then
		Logger:error("runtime bug - asset already spawned")
		return
	end
	self:_spawn()
end

function StaticCollection:isSpawned()
	return self._spawned
end

function StaticCollection:destroy()
	-- TODO: need some way of determining the difference between a
	-- unit group and static
	for name, _ in pairs(self._assets) do
		local object = Group.getByName(name)
		if object then
			object:destroy()
		end
	end
end

local function filterDeadObjects(tbl, grp)
	-- remove groups that are dead
	if grp.data.dct_dead == true then
		-- we either skip or if a static object that is a primary target
		-- we set dead
		if settings.spawndead == false or
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

local function filterTemplateData(tpldata)
	local cpytbl = {}

	for _, grp in ipairs(tpldata) do
		filterDeadObjects(cpytbl, grp)
	end
	if not next(cpytbl) then
		cpytbl = nil
	end
	return cpytbl
end

function StaticCollection:marshal()
	local tbl = {}
	tbl._tpldata = filterTemplateData(self._tpldata)
	if next(tbl._tpldata) == nil then
		return nil
	end
	return utils.mergetables(tbl, IDCSObjectCollection.marshal(self))
end

return StaticCollection
