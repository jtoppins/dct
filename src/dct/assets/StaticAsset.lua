--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Static asset, represents assets that do not move.
--
-- StaticAsset<AssetBase>:
--   has associated DCS objects, has death goals related to the
--   state of the DCS objects, the asset does not move
--]]

require("math")
local class    = require("libs.class")
local utils    = require("libs.utils")
local Logger   = dct.Logger.getByName("Asset")
local enum     = require("dct.enum")
local dctutils = require("dct.utils")
local vector   = require("dct.libs.vector")
local Goal     = require("dct.Goal")
local AssetBase= require("dct.assets.AssetBase")

local StaticAsset = class(AssetBase)
function StaticAsset:__init(template, region)
	self.__clsname = "StaticAsset"
	self._maxdeathgoals = 0
	self._curdeathgoals = 0
	self._deathgoals    = {}
	self._assets        = {}
	self._eventhandlers = {
		[world.event.S_EVENT_DEAD] = self.handleDead,
	}
	AssetBase.__init(self, template, region)
	self:_addMarshalNames({
		"_hasDeathGoals",
		"_maxdeathgoals",
	})
end

function StaticAsset:_completeinit(template, region)
	AssetBase._completeinit(self, template, region)
	self._hasDeathGoals = template.hasDeathGoals
	self._tpldata       = template:copyData()
end

--[[
-- ignore all but primary targets when it comes to determining
-- if we are "dead"
--]]
function StaticAsset:_addDeathGoal(name, goalspec)
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
function StaticAsset:_removeDeathGoal(name, goal)
	assert(name ~= nil and type(name) == "string",
		"value error: name must be provided")
	assert(goal ~= nil, "value error: goal must be provided")

	Logger:debug(string.format("%s:_removeDeathGoal() - obj name: %s",
		self.__clsname, name))
	if self:isDead() then
		Logger:error(string.format("%s:_removeDeathGoal() called "..
			"'%s' marked as dead", self.__clsname, self.name))
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
function StaticAsset:_setupDeathGoal(grpdata, category)
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
			AssetBase.defaultgoal(
				category == Unit.Category.STRUCTURE or
				category == enum.UNIT_CAT_SCENERY))
	end
end

--[[
-- Adds an object (group or static) to the monitored list for this
-- asset. This list will be needed later to save state.
--]]
function StaticAsset:_setup()
	for _, grp in ipairs(self._tpldata) do
		self:_setupDeathGoal(grp.data, grp.category)
		self._assets[grp.data.name] = grp
	end
	assert(next(self._deathgoals) ~= nil,
		string.format("runtime error: %s must have a deathgoal: %s",
			self.__clsname, self.name))
end

function StaticAsset:getLocation()
	if self._location == nil then
		local vec2, n
		for _, grp in pairs(self._assets) do
			vec2, n = dctutils.centroid(grp.data, vec2, n)
		end
		self._location = vector.Vector3D(vec2, land.getHeight(vec2))
	end
	return self._location
end

function StaticAsset:getStatus()
	return math.floor((1 - (self._curdeathgoals / self._maxdeathgoals)) * 100)
end

function StaticAsset:getObjectNames()
	local keyset = {}
	local n      = 0
	for k,_ in pairs(self._assets) do
		n = n+1
		keyset[n] = k
	end
	return keyset
end

function StaticAsset:handleDead(event)
	local obj = event.initiator

	-- mark the unit/group/static as dead in the template, dct_dead
	local unitname = tostring(obj:getName())
	if obj:getCategory() == Object.Category.UNIT then
		local grpname = obj:getGroup():getName()
		local grp = self._assets[grpname]
		for _, unit in pairs(grp.data.units) do
			if unit.name == unitname then
				unit.dct_dead = true
				break
			end
		end
		local goal = self._deathgoals[grpname]
		if goal and goal:checkComplete() then
			self:_removeDeathGoal(grpname, goal)
		end
	else
		self._assets[unitname].data.dct_dead = true
		local goal = self._deathgoals[unitname]
		if goal and goal:checkComplete() then
			self:_removeDeathGoal(unitname, goal)
		end
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

local function __spawn(grp)
	if grp.category == enum.UNIT_CAT_SCENERY then
		return
	end
	if grp.category == Unit.Category.STRUCTURE then
		coalition.addStaticObject(grp.countryid, grp.data)
	else
		coalition.addGroup(grp.countryid, grp.category, grp.data)
	end
end

function StaticAsset:_spawn()
	for _, grp in ipairs(self._tpldata) do
		__spawn(removeDCTKeys(grp))
	end

	self._spawned = true
	for _, goal in pairs(self._deathgoals) do
		goal:onSpawn()
	end
end

function StaticAsset:spawn(ignore)
	if not ignore and self:isSpawned() then
		Logger:error(string.format("runtime bug - %s(%s) already spawned",
			self.__clsname, self.name))
		return
	end
	self:_spawn()
end

function StaticAsset:despawn()
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
	self._spawned = false
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

function StaticAsset:marshal()
	local tbl = AssetBase.marshal(self)
	if tbl == nil then
		return nil
	end
	tbl._tpldata = filterTemplateData(self._tpldata)
	if tbl._tpldata == nil then
		return nil
	end
	return tbl
end

return StaticAsset
