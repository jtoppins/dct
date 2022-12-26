-- SPDX-License-Identifier: LGPL-3.0

--- @classmod Agent
-- Agent interface. Provides a common API for interacting with
-- underlying DCS groups.

local class      = require("libs.namedclass")
local utils      = require("libs.utils")
local check      = require("libs.check")
local dctenum    = require("dct.enum")
local dctutils   = require("dct.libs.utils")
local Logger     = require("dct.libs.Logger")
local aitasks    = require("dct.ai.tasks")
local WS         = require("dct.assets.worldstate")
local Marshallable = require("dct.libs.Marshallable")
local Observable = require("dct.libs.Observable")
local Subordinates = require("dct.libs.Subordinates")
local INVALID_OWNER = -1
local agentcomponents = { "sensors", "actions", "goals" }

--- common logging interfaces for the Agent class.
local AgentLogger = class("AgentLogger", Logger)
function AgentLogger:__init(cls)
	Logger.__init(self, cls.__clsname)
	self.cls = cls
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


local function load_module(subpath, objtype)
	Logger.getByName("Agent"):debug("init - load_module: %s",
		tostring("dct.assets."..subpath.."."..objtype))
	return require("dct.assets."..subpath.."."..objtype)
end

local objecttypes = {}
local objtbl = {}
local basepath = table.concat({dct.modpath, "lua", "dct", "assets"},
			      utils.sep)
Logger.getByName("Agent"):debug("init - basepath: %s", tostring(basepath))
for _, subpath in ipairs(agentcomponents) do
	objtbl[subpath] = {}
	objecttypes[subpath] = {}
	for file in lfs.dir(basepath..utils.sep..subpath) do
		local st, _, cap1 = string.find(file, "([^.]+)%.lua$")

		if st then
			local obj = load_module(subpath, cap1)
			local objtype = string.upper(obj.__clsname)

			assert(objtbl[subpath][objtype] == nil, "type taken")
			objtbl[subpath][objtype] = obj
			objecttypes[subpath][objtype] = objtype
		end
	end
end

--- Designers can specify what set of actions an Agent can have,
-- this is done by defining a list where the index is the name of the
-- action and the value is the cost of the action.
-- example:
--    ["Attack"] = 5,
--
-- Designers can also specify the personality of an Agent by defining
-- which goals an asset can attempt to do.
-- example:
--    ["KillTarget"] = 5,
--
-- By changing the relative weighting of a given goal the asset
-- will attempt to do that goal more or less often.
local function set_ai_objects(agent, template)
	for _, objkind in ipairs(agentcomponents) do
		local t = {}
		for objtype, val in pairs(template[objkind] or {}) do
			local ctor = objtbl[objkind][string.upper(objtype)]

			if ctor then
				table.insert(t, ctor(agent, val))
			else
				agent._logger:error("invalid %s: %s",
					tostring(objkind), tostring(objtype))
			end
		end

		if objkind == "sensors" then
			table.sort(t)
		end
		agent["_"..objkind] = t
	end
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
-- @field _setup [bool] has the Agent been setup?
-- @field _spawned [bool] have the DCS objects associated with this been
--     spawned
-- @field _dead [bool] is the Agent dead?
-- @field _plangraph graph of actions the agent can use, is configured in
--     the setup() method.
local Agent = class("Agent", Marshallable, Observable, Subordinates)
function Agent:__init()
	Marshallable.__init(self)
	Observable.__init(self, AgentLogger(self))
	Subordinates.__init(self)
	self.memory     = {}
	self.desc       = {}
	self.name       = "unknown"
	self.type       = dctenum.assetType.INVALID
	self.owner      = INVALID_OWNER
	self._sensors    = {}
	self._actions    = {}
	self._goals      = {}
	self._factcntr  = 1
	self._ws        = WS.WorldState.createAll()
	self._setup     = false
	self._spawned   = false
	self._dead      = false
	self._plan      = nil
	self._msn       = nil
	self._intel     = {}
	for _, side in pairs(coalition.side) do
		self._intel[side]    = 0
	end

	self:_addMarshalNames(utils.mergetables({
		"_spawned", "_dead", "_intel",
		"desc", "name", "type", "owner",
	}, Subordinates.getNames()))

	self.filter_no_controller = nil
	self.create               = nil
	self.objectType           = nil
end

--- Create a new Agent object
-- @param name name of the Agent, must be globally unique
-- @param typev type of template that the Agent was composed from
-- @param owner which coalition the Agent belongs to
-- @param desc description table for the Agent, stores invariants about
--          the Agent
-- @param tpl [optional] reference to Template object the Agent was
--          composed from
function Agent.create(name, typev, owner, desc)
	local agent = Agent()

	agent.name  = check.string(name)
	agent.type  = check.tblkey(typev, dctenum.assetType,
				   "dctenum.assetType")
	agent.owner = check.tblkey(owner, coalition.side, "coalition.side")
	agent.desc  = check.table(desc)
	agent:setIntel(agent.owner, dctutils.INTELMAX)
	agent:setup()
	return agent
end

local nocontroller = {
	[dctenum.UNIT_CAT_SCENERY] = true,
	[Unit.Category.STRUCTURE]  = true,
}

function Agent.filter_no_controller(grp)
	return nocontroller[grp.category] == nil
end

Agent.objectType = objecttypes

--- Destroys the Agent, deleting all associated DCS object, without emitting
-- a death event to listeners.
function Agent:destroy()
	self:despawn()
	self._sensors = nil
	self._goals = nil
	self._actions = nil
end

--- Finalizes the Agent and runs the setup function for all sensors
function Agent:setup()
	local tpl = self:getTemplate()
	if tpl == nil then
		return
	end

	self:setIntel(dctutils.getenemy(self.owner), tpl.intel)
	set_ai_objects(self, tpl)

	if next(self._sensors) == nil or next(self._goals) == nil or
	   next(self._actions) == nil then
		self._logger:warn("sensors, goals & actions tables should "..
				  "not be empty")
	end

	self._plangraph = WS.Graph(self, self._actions)
	dctutils.foreach_call(self._sensors, ipairs, "setup")
	self._setup = true
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

-- Magic function used by the Marshallable class.
-- Handle the intel table special because even though its keys
-- were numbers when the state was serialized in json's wisdom
-- it decided to convert them to strings. So we need to convert
-- back so we can access the data in our lookups.
function Agent:_unmarshalpost(data)
	for _, tbl in ipairs({"_intel", }) do
		self[tbl] = {}
		for k, v in pairs(data[tbl]) do
			self[tbl][tonumber(k)] = v
		end
	end
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

--- get the list of Goals the Agent wants to achieve, it includes
-- the current goal desired by the assigned Mission as well.
--
-- @return list of worldstate.Goal objects
function Agent:goals()
	local goals = utils.shallowclone(self._goals)

	if self._msn then
		table.insert(goals, self._msn:goal())
	end
	return goals
end

--- Trigger the Agent to replan, set the idle state to false as
-- we are doing something.
function Agent:replan()
	self:WS():get(WS.ID.IDLE).value = false
	self._plan = nil
end

--- Set the current plan the Agent needs to execute.
--
-- @param goal worldstate.Goal that the Agent is trying to achieve
-- @param plan a Queue of worldstate.Action objects the Agent should execute
function Agent:setPlan(goal, plan)
	self._plan = {}
	self._plan.goal = goal
	self._plan.plan = plan
end

--- Return the plan Goal the Agent is attempting to achieve.
--
-- @return worldstate.Goal
function Agent:getGoal()
	if self._plan == nil then
		return nil
	end
	return self._plan.goal
end

--- Required by the AssetManager, returns the list of DCS groups/static the
-- Agent is composed of.
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
	local rgnmgr = dct.Theater.singleton():getRegionMgr()
	local region = rgnmgr:getRegion(self.desc.regionname)

	if region == nil then
		self._logger:error("Cannot find Region(%s)",
				   self.desc.regionname)
		return nil
	end

	local T = region:getTemplateByName(self.desc.name)

	if T == nil then
		self._logger:error("No Template found (%s)",
			self.desc.regionname.."."..self.desc.name)
	end

	return T
end

--- Get a copy of the Agent's description table.
-- TODO: get the total description table for the Agent including the
-- backing Template items.
function Agent:getDesc()
	return utils.deepcopy(self.desc)
end

--- Get the entry defined by key in the description table for this Agent.
-- If the key doesn't exist in the Agent's desc table, this function
-- will proxy the request to the Template object that created the Agent.
--
-- @return value in either the Agent's desc table or the backing Template
--    nil will be returned if the key doesn't exist
function Agent:getDescKey(key)
	local val = self.desc[key]

	if val == nil then
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

--- An intel level of zero implies the given side has no idea about
-- the asset.
--
-- @param side get the intel level the specified side has on this asset
-- @return number, intel level [0-5]
function Agent:getIntel(side)
	return self._intel[side]
end

--- Set the intel level for the given side.
--
-- @param side side to modify level for
-- @param val the new intel level
-- @return none
function Agent:setIntel(side, val)
	assert(type(val) == "number", "value error: must be a number")
	self._intel[side] = val
end

-- Is the asset considered dead yet?
-- Returns: boolean
function Agent:isDead()
	return self._dead
end

--- Sets if the object should be thought of as dead or not
-- @return none
function Agent:setDead(val)
	assert(type(val) == "boolean", "value error: val must be of type bool")
	local prev = self._dead
	local assetmgr = dct.Theater.singleton():getAssetMgr()

	for name, _ in self:iterateSubordinates() do
		local asset = assetmgr:getAsset(name)
		if asset then
			asset:setDead(val)
		end
	end

	self._dead = val
	if self._dead and prev ~= self._dead then
		self._logger:debug("notifying asset death for "..self.name)
		self:notify(dctutils.buildevent.dead(self))
	end
end

--- get the Mission object currently assigned to the Agent
--
--- @return Mission or nil is no mission assigned
function Agent:getMission()
	return self._msn
end

--- assign Mission object to Agent
--
-- @param msn Mission object reference
function Agent:setMission(msn)
	self._msn = msn
end

--- Handle DCS and DCT objects sent to the Agent
function Agent:onDCTEvent(event)
	dctutils.foreach_call(self._sensors, ipairs, "onDCTEvent", event)
end

local function execute_plan(agent)
	if agent._plan == nil then
		return
	end

	local plan = agent._plan.plan
	local goal = agent._plan.goal
	local action = agent._plan.action

	if plan:empty() then
		goal:complete()
		agent:replan()
		return
	end

	if action == nil then
		agent._plan.action = plan:peekhead()
		action = agent._plan.action
		action:enter(agent)
	end

	if action:isComplete(agent) then
		plan:pophead()
		agent._plan.action = nil
	end
end

--- Update function run periodically
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

	execute_plan(self)
end

-- Have the DCS objects associated with this asset been spawned?
-- Returns: boolean
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

	["despawn"] = function (_, asset)
		asset:despawn()
	end
}

local function spawn_despawn(self, action, ignore)
	local assetmgr = dct.Theater.singleton():getAssetMgr()

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
-- @return none
function Agent:spawn(ignore)
	if not ignore and self:isSpawned() then
		self._logger:error("runtime bug - already spawned")
		return
	end

	dctutils.foreach_call(self._sensors, ipairs, "spawn", ignore)
	spawn_despawn(self, "spawn", ignore)
	self._spawned = true
	dctutils.foreach_call(self._sensors, ipairs, "spawnPost")
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

--- Looks for a fact in the agent's memory
--
-- @param test a test function of the form, <bool> test(key, fact),
--   where a true result means the fact we are looking for exists in
--   the table
-- @return true, key or false
function Agent:hasFact(test)
	for key, fact in pairs(self.memory) do
		if test(key, fact) then
			return true, key
		end
	end
	return false
end

--- get a known fact from Agent's memory
--
-- @param key [any] get the fact indexed by key
-- @return [table] return the fact
function Agent:getFact(key)
	return self.memory[key]
end

--- add or overwrite a fact in the Agent's memory
--
-- @param key [any] value, if nil a key is generated
-- @param fact [table] the fact object to store
-- @return [any] the key where the fact was stored
function Agent:setFact(key, fact)
	local incctr = false

	if key == nil then
		incctr = true
		key = self._factcntr
	end
	self.memory[key] = fact

	if incctr then
		self._factcntr = self._factcntr + 1
	end
	return key
end

--- Deletes all facts where test returns true
--
-- @param test a test function of the form, <bool> test(key, fact),
--   where a true result causes the fact to be deleted
-- @return table of deleted facts
function Agent:deleteFacts(test)
	local deletedfacts = {}
	for key, fact in pairs(self.memory) do
		if test(key, fact) then
			self.memory[key] = nil
			deletedfacts[key] = fact
		end
	end
	return deletedfacts
end

--- Delete all facts in the Agent
function Agent:deleteAllFacts()
	self.memory = {}
end

local function no_filter()
	return true
end

--- Iterate over facts the Agent knows about.
--
-- @param filter a function of the form, <bool> func(obj), used to filter
--   facts returned by the iterator, filter must return true to include
--   the fact in the iteration.
-- @return an iterator to be used in a for loop
function Agent:iterateFacts(filter)
	filter = filter or no_filter
	local function fnext(state, index)
		local idx = index
		local fact
		repeat
			idx, fact = next(state, idx)
			if fact == nil then
				return nil
			end
		until(filter(fact))
		return idx, fact
	end
	return fnext, self.memory, nil
end

--- Iterate over DCS groups associated with this agent.
--
-- @param filter a function of the form, <bool> func(obj), used to filter
--   groups returned by the iterator, filter must return true to include
--   the group in the iteration.
-- @return an iterator to be used in a for loop
function Agent:iterateGroups(filter)
	filter = filter or no_filter
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
	filter = filter or no_filter
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

	for _, grp in self:iterateGroups(Agent.filter_no_controller) do
		for _, unit in ipairs(grp.data.units or {}) do
			_do_one_obj(Unit.getByName(unit.name), tasktbl,
				    push, filter)
		end
	end
end

return Agent
