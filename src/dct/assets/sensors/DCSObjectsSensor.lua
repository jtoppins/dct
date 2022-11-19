-- SPDX-License-Identifier: LGPL-3.0

require("math")
local utils        = require("libs.utils")
local dctenum      = require("dct.enum")
local DCTEvents    = require("dct.libs.DCTEvents")
local Timer        = require("dct.libs.Timer")
local Goal         = require("dct.assets.DeathGoals")
local WS           = require("dct.assets.worldstate")
local UPDATE_TIME  = 300

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
local function remove_dct_keys(grp)
	local g = utils.deepcopy(grp)
	removekeys(g.data, dctkeys)
	for _, unit in ipairs(g.data.units or {}) do
		removekeys(unit, dctkeys)
	end
	return g
end

local function _spawn(grp)
	if grp.category == dctenum.UNIT_CAT_SCENERY then
		return
	end
	if grp.category == Unit.Category.STRUCTURE then
		coalition.addStaticObject(grp.countryid, grp.data)
	else
		coalition.addGroup(grp.countryid, grp.category, grp.data)
	end
end

-- ignore all but primary targets when it comes to determining
-- if we are dead
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

-- This function needs to do three things:
--   mark the object(unit/static/group) in the template dead,
--      dct_dead == true
--   remove deathgoal entry
--   upon no more deathgoals set dead
local function remove_death_goal(self, name, goal)
	assert(name ~= nil and type(name) == "string",
		"value error: name must be provided")
	assert(goal ~= nil, "value error: goal must be provided")

	self.agent._logger:debug("remove_death_goal() - obj name: %s", name)
	if self.agent:isDead() then
		self.agent._logger:error("remove_death_goal() called "..
			"'%s' marked as dead", self.agent.name)
		return
	end

	local grpdata = self._assets[goal:getGroupName()].data
	if grpdata.name == name then
		grpdata.dct_dead = true
		self.agent._logger:debug("remove_death_goal() marking "..
			"group dead '%s'", name)
	else
		assert(grpdata.units ~= nil, "no units found, this is a problem")
		for _, unit in ipairs(grpdata.units) do
			if unit.name == name then
				unit.dct_dead = true
				self.agent._logger:debug(
					"remove_death_goal() marking "..
					"unit dead '%s'", name)
				break
			end
		end
	end

	self._deathgoals[name] = nil
	self._curdeathgoals = self._curdeathgoals - 1
	if next(self._deathgoals) == nil then
		-- TODO: may not be able to set dead right here as if there
		-- is a pending set of events, like ejections, the Agent
		-- could be deleted before all the ejections are processed.
		-- Instead post death event to agent memory.
		self.agent:setDead(true)
	end
end

-- Adds a death goal, which determines when the Asset is dead.
-- If no death goals have been defined a default of 90%
-- damaged for all objects in the Asset is used.
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
		        Goal.defaultgoal(
				category == Unit.Category.STRUCTURE or
				category == dctenum.UNIT_CAT_SCENERY))
	end
end

local function mark_unit_dead(sensor, grpname, unitname)
	local grp = sensor._assets[grpname]
	for _, unit in pairs(grp.data.units) do
		if unit.name == unitname then
			unit.dct_dead = true
			break
		end
	end
end

local function checkgoal(sensor, name)
	local goal = sensor._deathgoals[name]
	if goal and goal:checkComplete() then
		remove_death_goal(sensor, name, goal)
	end
end

--- @classmod DCSObjectsSensor
-- Provides a common API for interacting with underlying DCS groups.
--
-- @field agent reference to owning agent
-- @field _maxdeathgoals maximum death goals ever had by the asset
-- @field _curdeathgoals current active death goals
-- @field _deathgoals list of current death goals
-- @field _assets list of asset groups composing the asset
--
-- @event S_EVENT_DEAD removes dead units from the tracked list and
--     recalculates the Agent's overall health
--
-- @modifies Agent.memory
-- @modifies Agent.desc.tpldata
local DCSObjectsSensor = require("libs.namedclass")("DCSObjectsSensor",
	WS.Sensor, DCTEvents)
function DCSObjectsSensor:__init(agent)
	WS.Sensor.__init(self, agent, 10)
	DCTEvents.__init(self)
	self._maxdeathgoals = agent:getDescKey("maxdeathgoals") or 0
	self._curdeathgoals = 0
	self._deathgoals    = {}
	self._hasDeathGoals = agent:getDescKey("hasDeathGoals") or false
	self._tpldata       = agent.desc.tpldata
	self.timer          = Timer(UPDATE_TIME)
	self.healthkey      = self.__clsname..".health"

	self:_overridehandlers({
		[world.event.S_EVENT_DEAD] = self.handleDead,
		[world.event.S_EVENT_CRASH] = self.handleDead,
	})
end

-- Adds an object (group or static) to the monitored list for this
-- asset. This list will be needed later to save state.
function DCSObjectsSensor:setup()
	self._assets = {}

	for _, grp in ipairs(self._tpldata) do
		setup_death_goal(self, grp.data, grp.category)
		self._assets[grp.data.name] = grp
	end
	if next(self._deathgoals) == nil then
		self.agent._logger:error(
			"runtime error: must have a deathgoal, deleting")
		self.agent:setDead(true)
	end
end

function DCSObjectsSensor:handleDead(event)
	local obj = event.initiator

	-- mark the unit/group/static as dead in the template, dct_dead
	local unitname = tostring(obj:getName())
	if obj:getCategory() == Object.Category.UNIT then
		local grpname = obj:getGroup():getName()
		mark_unit_dead(self, grpname, unitname)
		checkgoal(self, grpname)
	else
		self._assets[unitname].data.dct_dead = true
		checkgoal(self, unitname)
	end

	-- delete any deathgoal related to the unit notified as dead,
	-- this may work around any bug in DCS where the object is still
	-- kept and its health reports a non-zero value
	local goal = self._deathgoals[unitname]
	if goal ~= nil then
		remove_death_goal(self, unitname, goal)
	end

	self.agent:setFact(self, self.healthkey, WS.Facts.Value(
		WS.Facts.factType.HEALTH,
		self._curdeathgoals / self._maxdeathgoals,
		1.0))
end

function DCSObjectsSensor:checkGoals()
	local cnt = 0
	for name, goal in pairs(self._deathgoals) do
		cnt = cnt + 1
		if goal:checkComplete() then
			remove_death_goal(self, name, goal)
		end
	end

	self.agent:setFact(self, self.healthkey, WS.Facts.Value(
		WS.Facts.factType.HEALTH,
		self._curdeathgoals / self._maxdeathgoals,
		1.0))

	self.agent._logger:debug("update() - max goals: %d; cur goals: %d; "..
		"checked: %d", self._maxdeathgoals, self._curdeathgoals, cnt)
end

function DCSObjectsSensor:update()
	self.timer:update()
	if not self.timer:expired() then
		return false
	end
	self:checkGoals()
	self.timer:reset()
	return false
end

function DCSObjectsSensor:marshal()
	self:checkGoals()
	self.agent:setDescKey("maxdeathgoals", self._maxdeathgoals)
	self.agent:setDescKey("hasDeathGoals", self._hasDeathGoals)
end

function DCSObjectsSensor:spawn()
	for _, grp in pairs(self._assets) do
		_spawn(remove_dct_keys(grp))
	end

	for name, goal in pairs(self._deathgoals) do
		goal:onSpawn()
		if goal:isComplete() then
			remove_death_goal(self, name, goal)
		end
	end
	self.timer:reset()
	self.timer:start()
end

function DCSObjectsSensor:despawn()
	self.timer:stop()
	self:checkGoals()
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
end

return DCSObjectsSensor
