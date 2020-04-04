--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides functions for handling Assets.
-- An Asset is a group of objects in the game world
-- that can be destroyed by the opposing side.
--]]

require("math")
local class    = require("libs.class")
local utils    = require("libs.utils")
local dctutils = require("dct.utils")
local STM      = require("dct.STM")
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

local function generateCodename(objtype)
	local codenamedb = settings.codenamedb
	local typetbl = codenamedb[objtype]

	if typetbl == nil then
		typetbl = codenamedb.default
	end

	local idx = math.random(1, #typetbl)
	local codename = typetbl[idx]

	return codename
end

local Asset = class()
function Asset:__init(template, region)
	self._initcomplete = false
	self._spawned    = false
	self._dead       = false
	self._targeted   = false
	self._maxdeathgoals = 0
	self._curdeathgoals = 0
	self._deathgoals = {}
	self._assets     = {}

	if template ~= nil and region ~= nil then
		self._hasDeathGoals = template.hasDeathGoals
		self._tpldata   = template:copyData()
		self._briefing  = template.desc
		self.owner      = template.coalition
		self.type       = template.objtype
		self.name       = region.name.."_"..self.owner.."_"..template.name
		self.regionname = region.name
		self.codename   = generateCodename(self.type)
		self.priority   = region.priority * 65536 + template.priority
		self:_setupmaps()
		self._initcomplete = true
		assert(next(self._deathgoals) ~= nil,
			"runtime error: Asset must have a deathgoal")
	end
end

--[[
-- ignore all but primary targets when it comes to determining
-- if an Asset is "dead"
--]]
function Asset:_addDeathGoal(name, goalspec)
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
function Asset:_removeDeathGoal(name, goal)
	assert(name ~= nil and type(name) == "string",
		"value error: name must be provided")
	assert(goal ~= nil, "value error: goal must be provided")

	Logger:debug("_removeDeathGoal() - obj name: "..name)
	if self:isDead() then
		Logger:error("_removeDeathGoal() called and Asset("..
			self:getName()..") marked as dead")
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

-- TODO: if this is a movable asset we should not calculate
-- the centroid, not sure what location we should return -
-- the starting position or something else? We shouldn't return
-- the current position I do not think.
function Asset:getLocation()
	if self.centroid == nil then
		local points = {}
		for k,v in pairs(self._assets) do
			points[k] = {
				["x"] = v.x, ["y"] = 0, ["z"] = v.y,
			}
		end

		self.centroid = dctutils.centroid(points)
	end
	return self.centroid
end

function Asset:getCallsign()
	return self.codename
end

function Asset:getIntelLevel()
	return 4
	-- TODO: base this on a value related to the asset type
end

--[[
-- getStatus - percentage remaining of the asset from 0 - 100
--]]
function Asset:getStatus()
	return math.floor((1 - (self._curdeathgoals / self._maxdeathgoals)) * 100)
end

function Asset:getBriefing()
	return self._briefing
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

function Asset:getName()
	return self.name
end

function Asset:getPriority()
	return self.priority
end

function Asset:_setDead()
	self._dead = true
end

function Asset:isDead()
	return self._dead
end

function Asset:checkDead()
	assert(self:isSpawned() == true, "runtime error: asset must be spawned")

	local cnt = 0
	for name, goal in pairs(self._deathgoals) do
		cnt = cnt + 1
		if goal:checkComplete() then
			self:_removeDeathGoal(name, goal)
		end
	end
	Logger:debug(string.format("checkDead(%s) - max goals: %d; "..
		"cur goals: %d; checked: %d", self:getName(),
		self._maxdeathgoals, self._curdeathgoals, cnt))
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
	-- only handle DEAD events
	if event.id ~= world.event.S_EVENT_DEAD then
		Logger:debug(string.format("onDCSEvent() - Asset(%s) not DEAD "..
			"event, ignoring", self:getName()))
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

function Asset:_spawn()
	for cat_idx, cat_data in pairs(self._tpldata) do
		for _, grp in ipairs(cat_data) do
			local gcpy = removeDCTKeys(grp)
			if cat_idx == 'static' then
				coalition.addStaticObject(gcpy.countryid, gcpy.data)
			else
				coalition.addGroup(gcpy.countryid,
					Unit.Category[STM.categorymap[string.upper(cat_idx)]],
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

function Asset:marshal()
	assert(self._initcomplete == true, "runtime error: init not complete")
	local tbl = {}

	tbl._tpldata       = filterTemplateData(self._tpldata)
	if next(tbl._tpldata) == nil then
		return nil
	end
	tbl._dead          = self._dead
	tbl._spawned       = self._spawned
	tbl._maxdeathgoals = self._maxdeathgoals
	tbl._hasDeathGoals = self._hasDeathGoals
	tbl._briefing      = self._briefing
	tbl.name           = self.name
	tbl.regionname     = self.regionname
	tbl.codename       = self.codename
	tbl.owner          = self.owner
	tbl.type           = self.type
	tbl.priority       = self.priority
	return tbl
end

function Asset:unmarshal(data)
	assert(self._initcomplete == false,
		"runtime error: init completed already")
	utils.mergetables(self, data)
	self:_setupmaps()
	if self:isSpawned() then
		self:_spawn()
	end
	self._initcomplete = true
end

return Asset
