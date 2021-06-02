--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- DCSObjects<AssetBase>:
--   has associated DCS objects, has death goals related to the
--   state of the DCS objects.
--]]

require("math")
local enum     = require("dct.enum")
local utils    = require("libs.utils")
local Goal     = require("dct.Goal")
local AssetBase = require("dct.assets.AssetBase")

--[[
-- ignore all but primary targets when it comes to determining
-- if we are "dead"
--]]
local function add_death_goal(self, name, goalspec)
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
local function remove_death_goal(self, name, goal)
	assert(name ~= nil and type(name) == "string",
		"value error: name must be provided")
	assert(goal ~= nil, "value error: goal must be provided")

	self._logger:debug(string.format("remove_death_goal() - obj name: %s",
		name))
	if self:isDead() then
		self._logger:error(string.format("remove_death_goal() called "..
			"'%s' marked as dead", self.name))
		return
	end

	local grpdata = self._assets[goal:getGroupName()].data
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
-- Adds a death goal, which determines when the Asset is dead.
-- If no death goals have been defined a default of 90%
-- damaged for all objects in the Asset is used.
--]]
local function setup_death_goal(self, grpdata, category)
	if self._hasDeathGoals then
		if grpdata.dct_deathgoal ~= nil then
			add_death_goal(self, grpdata.name, grpdata.dct_deathgoal)
		end
		for _, unit in ipairs(grpdata.units or {}) do
			if unit.dct_deathgoal ~= nil then
				add_death_goal(self, unit.name, unit.dct_deathgoal)
			end
		end
	else
		add_death_goal(self, grpdata.name,
			AssetBase.defaultgoal(
				category == Unit.Category.STRUCTURE or
				category == enum.UNIT_CAT_SCENERY))
	end
end

local function mark_unit_dead(asset, grpname, unitname)
	local grp = asset._assets[grpname]
	for _, unit in pairs(grp.data.units) do
		if unit.name == unitname then
			unit.dct_dead = true
			break
		end
	end
end

local function checkgoal(asset, name)
	local goal = asset._deathgoals[name]
	if goal and goal:checkComplete() then
		remove_death_goal(asset, name, goal)
	end
end

local function handle_dead(self, event)
	local obj = event.initiator

	-- mark the unit/group/static as dead in the template, dct_dead
	local unitname = tostring(obj:getName())
	if obj:getCategory() == Object.Category.UNIT then
		local grpname = obj:getGroup():getName()
		mark_unit_dead(self, grpname, unitname)
		checkgoal(self, grpname)
	else
		self._assets[unitname].data.dct_dead = true
		if self._assets[unitname].category == enum.UNIT_CAT_SCENERY then
			dct.Theater.singleton():getSystem(
				"dct.systems.bldgPersist"):addObject(unitname)
		end
		checkgoal(self, unitname)
	end

	-- delete any deathgoal related to the unit notified as dead,
	-- this may work around any bug in DCS where the object is still
	-- kept and its health reports a non-zero value
	local goal = self._deathgoals[unitname]
	if goal ~= nil then
		remove_death_goal(self, unitname, goal)
	end
end

local DCSObjects = require("libs.namedclass")("DCSObjects", AssetBase)
function DCSObjects:__init(template)
	self._maxdeathgoals = 0
	self._curdeathgoals = 0
	self._deathgoals    = {}
	self._assets        = {}
	self._eventhandlers = utils.mergetables({
		[world.event.S_EVENT_DEAD] = handle_dead,
	}, self._eventhandlers)
	AssetBase.__init(self, template)
	self:_addMarshalNames({
		"_hasDeathGoals",
		"_maxdeathgoals",
	})
end

function DCSObjects:_completeinit(template)
	AssetBase._completeinit(self, template)
	self._hasDeathGoals = template.hasDeathGoals
	self._tpldata       = template:copyData()
end

--[[
-- Adds an object (group or static) to the monitored list for this
-- asset. This list will be needed later to save state.
--]]
function DCSObjects:_setup()
	for _, grp in ipairs(self._tpldata) do
		setup_death_goal(self, grp.data, grp.category)
		self._assets[grp.data.name] = grp
	end
	if next(self._deathgoals) == nil then
		self._logger:error("runtime error: must have a deathgoal, deleting")
		self:setDead(true)
	end
end

function DCSObjects:getStatus()
	return math.floor((1 - (self._curdeathgoals / self._maxdeathgoals)) * 100)
end

function DCSObjects:getObjectNames()
	local keyset = {}
	local n      = 0
	for k,_ in pairs(self._assets) do
		n = n+1
		keyset[n] = k
	end
	return keyset
end

function DCSObjects:update()
	if not self:isSpawned() then
		return
	end

	local cnt = 0
	for name, goal in pairs(self._deathgoals) do
		cnt = cnt + 1
		if goal:checkComplete() then
			remove_death_goal(self, name, goal)
		end
	end
	self._logger:debug(string.format(
		"update() - max goals: %d; cur goals: %d; checked: %d",
		self._maxdeathgoals, self._curdeathgoals, cnt))
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

local function _spawn(grp)
	if grp.category == enum.UNIT_CAT_SCENERY then
		return
	end
	if grp.category == Unit.Category.STRUCTURE then
		coalition.addStaticObject(grp.countryid, grp.data)
	else
		coalition.addGroup(grp.countryid, grp.category, grp.data)
	end
end

function DCSObjects:spawn(ignore)
	if not ignore and self:isSpawned() then
		self._logger:error("runtime bug - already spawned")
		return
	end
	for _, grp in ipairs(self._tpldata) do
		_spawn(removeDCTKeys(grp))
	end

	AssetBase.spawn(self)
	for _, goal in pairs(self._deathgoals) do
		goal:onSpawn()
	end
end

function DCSObjects:despawn()
	for name, grp in pairs(self._assets) do
		local object
		if grp.category == Unit.Category.STRUCTURE then
			object = StaticObject.getByName(name)
		else
			object = Group.getByName(name)
		end
		if object then
			object:destroy()
		end
	end
	AssetBase.despawn(self)
end

local function filterDeadObjects(tbl, grp)
	-- remove groups that are dead
	if grp.data.dct_dead == true then
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
		if not next(gcpy.data.units) then
			-- there are no alive units do not add the group
			return
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

function DCSObjects:marshal()
	local tbl = AssetBase.marshal(self)
	if tbl == nil then
		return nil
	end
	if self.regenerate then
		tbl._tpldata = self._tpldata
	else
		tbl._tpldata = filterTemplateData(self._tpldata)
	end
	if tbl._tpldata == nil then
		return nil
	end
	return tbl
end

return DCSObjects
