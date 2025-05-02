-- SPDX-License-Identifier: LGPL-3.0

--- Agent interface. Provides a common API for interacting with
-- underlying DCS groups.
-- @classmod dct.agent.Agent

require("libs")
local class      = libs.classnamed
local utils      = libs.utils
local check      = libs.check
local dctenum    = require("dct.enum")
local dctutils   = require("dct.libs.utils")
local Logger     = require("dct.libs.Logger")
local vector     = require("dct.libs.vector")
local aitasks    = require("dct.ai.tasks")
local WS         = require("dct.agent.worldstate")
local Marshallable = require("dct.libs.Marshallable")
local Observable = require("dct.libs.Observable")
local Subordinates = require("dct.libs.Subordinates")
local Memory     = require("dct.libs.Memory")
local Template   = require("dct.templates.Template")

-- TODO: remove the idea of a mission being assigned to an Agent and
-- instead add Goal objects to an Agent's memory.
-- TODO: ensure that when a goal object is removed from an Agent and
-- the Goal is the current active goal replanning is triggered.
-- TODO: Instead of missions trying to remember which participants
-- were given which goals have the mission simply set the goal
-- as no longer needed so agents with the goal will remove it from
-- memory. We can do this by using the ageout field.

--- common logging interfaces for the Agent class.
local AgentLogger = class("AgentLogger", Logger)
function AgentLogger:__init(cls, debug)
	Logger.__init(self, cls.__clsname)
	self.cls = cls

	if debug == true then
		self:setLevel(Logger.level.debug)
	end
end

function AgentLogger:error(fmt, ...)
	Logger.error(self, "%s - "..fmt, self.cls.name, ...)
end

function AgentLogger:warn(fmt, ...)
	Logger.warn(self, "%s - "..fmt, self.cls.name, ...)
end

function AgentLogger:info(fmt, ...)
	Logger.info(self, "%s - "..fmt, self.cls.name, ...)
end

function AgentLogger:debug(fmt, ...)
	Logger.debug(self, "%s - "..fmt, self.cls.name, ...)
end

--- runs aitasks.execute() on the Unit/Group passed by name
local function _do_one_obj(obj, tasktbl, push, filter)
	if obj == nil then
		return
	end

	local taskfunc = aitasks.setTask
	if push then
		taskfunc = aitasks.pushTask
	end

	if type(obj.getController) ~= "function" or
	   obj:getController() == nil then
		return
	end

	if type(filter) == "function" and not filter(obj) then
		return
	end

	aitasks.execute(obj:getController(), tasktbl, taskfunc)
end

--- Remove dead Units from the group description table `grp` and store the
-- filtered group into `tbl`.
local function filter_dead_objects(tbl, grp)
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
				table.insert(gcpy.data.units,
					     utils.deepcopy(unit))
			end
		end
		if not next(gcpy.data.units) then
			-- there are no alive units do not add the group
			return
		end
	end
	table.insert(tbl, gcpy)
end

--- Remove Units/Groups from the template data `tpldata`.
local function filter_template_data(tpldata)
	local cpytbl = {}

	for _, grp in ipairs(tpldata) do
		filter_dead_objects(cpytbl, grp)
	end
	if not next(cpytbl) then
		cpytbl = nil
	end
	return cpytbl
end

--- Setup sensors, actions, and goals of an Agent.
--
-- @param agent a dct.agent.Agent instance.
local function setup_ai(agent)
	local agentcomponents = { "sensors", "actions", "goals" }
	local objtbl = dct.agent

	for _, objkind in ipairs(agentcomponents) do
		for _, ctor in pairs(objtbl[objkind]) do
			if ctor.isSuitable(agent) == true then
				table.insert(agent["_"..objkind], ctor(agent))
			end
		end
	end
	table.sort(agent._sensors)
end

local agentmt = {}
function agentmt.__tostring(agent)
	return string.format("N:%s, T:%s, P:%s",
			     agent.name,
			     utils.getkey(dctenum.assetType, agent.type),
			     tostring(agent:getPlan()))
end

--- Agent interface. Provides a common API for interacting with
-- underlying DCS groups.
--
-- Fields that must be set by the constructing object:
-- @field type [int] asset type
-- @field owner [int] coalition that owns the asset
-- @field name [string] name of the agent, must be globally unique
-- @field desc [table] dumping ground for invariant attributes related
--     to the Agent.
--     Key items are:
--     * tpldata - a list of the DCS objects associated with this Agent
--     * hasDeathGoals - flag, if true, specifies that there are custom
--         death goals defined for the associated groups
-- @field goals list of goals the agent has available to it
-- @field actions list of actions the agent has available to it
-- @field sensors list of sensors the agent uses
--
-- Fields touched by sensors:
-- @field memory [table] list of facts the Agent knows about
--
-- Other fields typically managed internally:
-- @field _ws current world state for the agent
-- @field _spawned [bool] have the DCS objects associated with this been
--     spawned
-- @field _plangraph graph of actions the agent can use, is configured in
--     the setup() method.
local Agent = utils.override_ops(class("Agent", Marshallable, Memory,
				       Observable, Subordinates), agentmt)
function Agent:__init(name, owner, agenttype, debug)
	Marshallable.__init(self)
	Observable.__init(self, AgentLogger(self, debug))
	Subordinates.__init(self)
	Memory.__init(self)
	self.name       = name or "unknown"
	self.type       = agenttype or dctenum.assetType.INVALID
	self.owner      = owner or coalition.side.NEUTRAL
	self.desc       = {}

	self._sensors   = {}
	self._actions   = {}
	self._goals     = {}
	self._factcntr  = 1
	self._ws        = WS.WorldState.createAll()
	self._spawned   = false
	self._plan      = nil
	self._intel     = 0

	self:_addMarshalNames(utils.mergetables({
		"_spawned", "_intel",
		"desc", "name", "type", "owner",
	}, Subordinates.getNames()))

	if debug == true then
		self:setDescKey("debug", 120)
	end

	self.filter_no_controller = nil
	self.fromDCSGroup         = nil
	self.fromTemplate         = nil
end

function Agent.fromDCSGroup(grp, debug)
	local tpl = Template.fromDCSGroup(grp)

	if tpl:isValid() ~= true then
		return
	end

	local name, owner, objtype = tpl:getAgentArgs()
	local agent = Agent(name, owner, objtype, debug)
	for k, v in pairs(tpl:genDesc()) do
		agent:setDescKey(k, v)
	end
	agent:setup(true)
	agent:spawn()
	return agent
end

function Agent.fromTemplate(tpl, debug)
	local name, owner, objtype = tpl:getAgentArgs()
	local agent = Agent(name, owner, objtype, debug)
	tpl:attach(agent)
	return agent
end

local nocontroller = {
	[dctenum.UNIT_CAT_SCENERY] = true,
	[Unit.Category.STRUCTURE]  = true,
}

function Agent.filter_no_controller(grp)
	return nocontroller[grp.category] == nil
end

--- Format a string that contains detailed info about the Agent and its
-- attributes.
function Agent:printDetail()
	local str = tostring(self)

	str = str..string.format("\ndesc: %s",
				 libs.json:encode_pretty(self.desc))
	for _, lst in ipairs({"sensors", "actions", "goals",}) do
		str = str..string.format("\n%s: {", lst)
		for _, obj in ipairs(self["_"..lst]) do
			str = str..string.format("\n\t%s", obj.__clsname)
		end
		str = str..string.format("\n}")
	end
	return str
end

--- Destroys the Agent, deleting all associated DCS objects, without emitting
-- a death event to listeners.
function Agent:destroy()
	self:despawn()
	self:replan()
	self._goals = {}
	self._actions = {}
	self:setHealth(WS.Health.DEAD, false)
	self._sensors = {}
end

--- Finalizes the Agent and  the setup function for all sensors
function Agent:setup(fromgroup)
	-- Agents created from a DCS group object should not be able to be
	-- marshallable because we have no template to recreate the group
	-- from.
	if fromgroup == true then
		self.marshal   = nil
		self.unmarshal = nil
		self.getTemplate = nil
	end

	setup_ai(self)
	dctutils.foreach_call(self._sensors, ipairs, "setup", fromgroup)
	self._plangraph = WS.Graph(self, self._actions)
end

--- Marshals the Agent to a lua table which can be serialized later
function Agent:marshal()
	if self:isDead() then
		return nil
	end

	dctutils.foreach_call(self._sensors, ipairs, "marshal")
	local tbl = Marshallable.marshal(self)

	if tbl.desc.tpldata then
		if not self:getDescKey("regenerate") then
			tbl.desc.tpldata = filter_template_data(
				self:getDescKey("tpldata"))
		end

		if tbl.desc.tpldata == nil then
			return nil
		end
	end
	return tbl
end

--- Reads a marshaled Agent from the provided table(data)
--
-- @param data the marshalled table of the Agent
function Agent:unmarshal(data)
	Marshallable.unmarshal(self, data)
	self:setup()
end

--- get the world state of the Agent
--
-- @return WorldState object
function Agent:WS()
	return self._ws
end

--- get the Action graph for the Agent
--
-- @return worldstate.Graph
function Agent:graph()
	return self._plangraph
end

local function goalfacts(fact)
	if fact.type == WS.Facts.factType.GOAL then
		return true
	end
	return false
end

--- get the list of Goals the Agent wants to achieve, it includes
-- the current goal desired by the assigned Mission as well.
--
-- @return list of worldstate.Goal objects
function Agent:goals()
	local goals = utils.shallowclone(self._goals)

	for _, fact in self:iterateFacts(goalfacts) do
		table.insert(goals, fact.goal)
	end
	return goals
end

--- Trigger the Agent to replan, set the idle state to false as
-- we are doing something.
function Agent:replan()
	self:WS():get(WS.ID.IDLE).value = false
	self:setPlan(nil)
	dctutils.foreach_call(self._sensors, ipairs, "onReplan")
end

--- Set the current plan the Agent needs to execute.
--
-- @param plan the plan to execute.
function Agent:setPlan(plan)
	self._plan = plan
end

--- Get the plan the agent is currently attempting to execute.
--
-- @return worldstate.Plan
function Agent:getPlan()
	return self._plan
end

--- Required by the AssetManager, returns the list of DCS group/static names
-- the Agent is composed of.
--
-- @return list of DCS group/static names
function Agent:getObjectNames()
	local names = {}

	for _, grp in self:iterateGroups() do
		table.insert(names, grp.data.name)
	end
	return names
end

--- Get a reference to the backing Template object that created this Agent
function Agent:getTemplate()
	local tpldb = dct.Theater.singleton():getSystem(
				dct.libs.System.SYSTEMALIAS.TEMPLATEDB)

	if tpldb == nil then
		return nil
	end

	local T = tpldb:get(self.desc.template)

	if T == nil then
		self._logger:error("No Template found (%s)",
			self.desc.template)
	end

	return T
end

--- Get access to the Agent's description table.
function Agent:getDesc()
	return self.desc
end

--- Get the entry defined by key in the description table for this Agent.
-- If the key doesn't exist in the Agent's desc table, this function
-- will proxy the request to the Template object that created the Agent.
--
-- @return value in either the Agent's desc table or the backing Template
--    nil will be returned if the key doesn't exist
function Agent:getDescKey(key)
	local val = self.desc[key]

	if val == nil and type(self.getTemplate) == "function" then
		local T = self:getTemplate()

		if T == nil then
			return nil
		end

		val = T[key]
	end
	return val
end

--- Set a description table entry in the Agent's entry. This key will be
-- persisted.
function Agent:setDescKey(key, val)
	self.desc[key] = val
end

--- Get the intel level that the opposing side is supposed to know about
-- this agent. An intel level of zero implies the opposing side has no
-- idea about the asset.
--
-- @return number, intel level [0-5]
function Agent:getIntel()
	return self._intel
end

--- Set the intel level for the agent.
--
-- @param val the new intel level
-- @return none
function Agent:setIntel(val)
	self._intel = tonumber(val)
end

--- Update the location of all individual units and the overall agent's
-- location. Assume agents running this function do not have groups that
-- consist of static objects. The "center" of the Agent is simply the
-- first unit.
function Agent:updateLocation()
	local agentloc = nil
	local speed = self:getDescKey("speedMax") or 0

	if speed <= 0 then
		return
	end

	for _, grp in ipairs(self.desc.tpldata or {}) do
		for _, unit in ipairs(grp.data.units) do
			local U = Unit.getByName(unit.name)

			if U then
				local pt = vector.Vector3D(U:getPoint())

				unit.x = pt.x
				unit.y = pt.y

				if agentloc == nil then
					agentloc = pt
				end

				-- update azimuth of where the unit is pointing
				local pos = U:getPosition()
				unit.heading = math.atan2(pos.x.z, pos.x.x)
			end
		end
	end

	if agentloc ~= nil then
		self:setDescKey("location", agentloc:raw())
	end
end

--- Is the asset considered dead yet?
-- @return boolean
function Agent:isDead()
	return self:WS():get(WS.ID.HEALTH).value == WS.Health.DEAD
end

--- Sets the health state of the Agent.
-- Will call any Sensor objects that define an `onHealthChange` function
-- providing the previous and current health states.
--
-- @return none
function Agent:setHealth(val, donotify)
	check.tblkey(val, WS.Health, "WS.Health")
	donotify = donotify or true
	local prev = self:WS():get(WS.ID.HEALTH).value

	self:WS():get(WS.ID.HEALTH).value = val

	if prev ~= val then
		dctutils.foreach_call(self._sensors, ipairs, "onHealthChange",
				      prev, val)
		if donotify and val == WS.Health.DEAD then
			self._logger:debug("notifying asset death for "..
					   self.name)
			self:notify(dct.event.build.dead(self))
		end
	end
end

--- Handle DCS and DCT events sent to the Agent
function Agent:onDCTEvent(event)
	dctutils.foreach_call(self._sensors, ipairs, "onDCTEvent", event)
	if self:getPlan() ~= nil then
		self:getPlan():onDCTEvent(event)
	end
end

--- Update function is run periodically.
function Agent:update()
	if not self:isSpawned() or self:isDead() then
		return
	end

	for _, sensor in ipairs(self._sensors) do
		if type(sensor.update) == "function" and
		   sensor:update() then
			break
		end
	end

	if self:getPlan() ~= nil then
		self:getPlan():execute(self)
	end
end

--- Have the DCS objects associated with this asset been spawned?
-- @return true if DCS objects spawned
function Agent:isSpawned()
	return self._spawned
end

local actions = {
	["spawn"] = function (self, asset, ignore)
		self:addObserver(asset.onDCTEvent, asset, asset.name)
		if not asset:isSpawned() then
			asset:spawn(ignore)
		end
	end,

	["despawn"] = function (self, asset)
		self:removeObserver(asset)
		asset:despawn()
	end
}

local function spawn_despawn(self, action, ignore)
	local assetmgr = dct.Theater.singleton():getSystem(
				dct.libs.System.ASSETMGR)

	for name, _ in self:iterateSubordinates() do
		local asset = assetmgr:getAsset(name)

		if asset then
			actions[action](self, asset, ignore)
		else
			self:removeSubordinate(name)
		end
	end
end

--- Spawn any DCS objects associated with this asset.
function Agent:spawn(ignore)
	if not ignore and self:isSpawned() then
		self._logger:error("runtime bug - already spawned")
		return
	end

	dctutils.foreach_call(self._sensors, ipairs, "spawn", ignore)
	spawn_despawn(self, "spawn", ignore)
	self._spawned = true
	dctutils.foreach_call(self._sensors, ipairs, "spawnPost")
	-- TODO: set Agent's world state based on the states of the
	-- underlying DCS objects, should mainly be handled by the sensors
end

-- Remove any DCS objects associated with this asset from the game world.
-- The method used should result in no DCS events being triggered.
-- Returns: none
function Agent:despawn()
	dctutils.foreach_call(self._sensors, ipairs, "despawn")
	spawn_despawn(self, "despawn")
	self._spawned = false
	dctutils.foreach_call(self._sensors, ipairs, "despawnPost")
end

--- Like DCS Unit.hasAttribute, returns true if attr is contained by
-- any DCS object tracked by the agent.
--
-- @param attr the attribute to test for
-- @return bool, true the attribute exists
function Agent:hasAttribute(attr)
	local attrs = self:getDescKey("attributes")
	if next(attrs) == nil then
		return false
	end
	return attrs[attr] ~= nil
end

--- Iterate over DCS groups associated with this agent.
--
-- @param filter a function of the form, <bool> func(obj), used to filter
--   groups returned by the iterator, filter must return true to include
--   the group in the iteration.
-- @return an iterator to be used in a for loop
function Agent:iterateGroups(filter)
	filter = filter or dctutils.no_filter
	local function fnext(state, index)
		local idx = index
		local grp
		repeat
			idx, grp = next(state, idx)
			if grp == nil then
				return nil
			end
		until(filter(grp))
		return idx, grp
	end
	return fnext, self:getDescKey("tpldata") or {}, nil
end

--- Interate over DCS units associated with this agent.
--
-- @param filter a function of the form, <bool> func(obj), used to filter
--   units returned by the iterator, filter must return true to include
--   the unit in the iteration.
-- @return an iterator to be used in a for loop
function Agent:iterateUnits(filter)
	filter = filter or dctutils.no_filter
	local units = {}
	local function fnext(state, index)
		local idx = index
		local unit
		repeat
			idx, unit = next(state, idx)
			if unit == nil then
				return nil
			end
		until(filter(unit))
		return idx, unit
	end

	for _, grp in self:iterateGroups() do
		for _, unit in ipairs(grp.data.units or {}) do
			table.insert(units, unit)
		end
	end
	return fnext, units or {}, nil
end

--- Use the Controller object and for each DCS group apply tasktbl
-- to the group. If a group no longer exists it will be silently
-- skipped.
--
-- @param tasktbl list of tasks needing to be passed to the Controller
-- @param push bool, when true will push additional tasks instead of
--  overwriting.
-- @param filter a filter function of the form <bool> func(obj) where
--  obj is a DCS Object, return true for each obj you wish to have the
--  tasktbl applied.
function Agent:doTasksForeachGroup(tasktbl, push, filter)
	if not self:isSpawned() then
		return
	end

	self._logger:debug("applying tasktbl to groups: %s",
		libs.json:encode_pretty(tasktbl))
	for _, grp in self:iterateGroups(Agent.filter_no_controller) do
		_do_one_obj(Group.getByName(grp.data.name), tasktbl,
			    push, filter)
	end
end

--- Use the Controller object and for each DCS unit apply tasktbl
-- to the unit. If a unit no longer exists it will be silenty
-- skipped.
--
-- @param tasktbl list of tasks needing to be passed to the Controller
-- @param push bool, when true will push additional tasks instead of
--  overwriting.
-- @param filter a filter function of the form <bool> func(obj) where
--  obj is a DCS Object, return true for each obj you wish to have to
--  tasktbl applied.
function Agent:doTasksForeachUnit(tasktbl, push, filter)
	if not self:isSpawned() then
		return
	end

	self._logger:debug("applying tasktbl to units: %s",
		libs.json:encode_pretty(tasktbl))
	for _, grp in self:iterateGroups(Agent.filter_no_controller) do
		for _, unit in ipairs(grp.data.units or {}) do
			_do_one_obj(Unit.getByName(unit.name), tasktbl,
				    push, filter)
		end
	end
end

return Agent
