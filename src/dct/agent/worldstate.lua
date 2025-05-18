-- SPDX-License-Identifier: LGPL-3.0

--- WorldState describes an Agent's view of the world.

require("libs")

local utils      = libs.utils
local check      = libs.check
local json       = libs.json
local class      = libs.classnamed
local goap       = libs.containers.GOAP
local Observable = require("dct.libs.Observable")

--- Agent states
local id = {
	["IDLE"]           = "idle",           -- <bool>
	["INAIR"]          = "inAir",          -- <bool>
	["ROE"]            = "roe",            -- <enum> AI.Option.Air.val.ROE.*
	["HEALTH"]         = "health",         -- <enum> WS.Health
	["ATNODETYPE"]     = "atNodeType",     -- <enum>
	["STANCE"]         = "stance",         -- <enum>
	["REACTEDTOEVENT"] = "reactedToEvent", -- <event-id>
}

local healthType = {
	["UNKNOWN"]     = 0,
	["DEAD"]        = 1, -- agent is dead
	["DAMAGED"]     = 2, -- combat ineffective, repairs needed
	["OPERATIONAL"] = 3, -- agent is combat effective
}

--- Stance types the agent can have
local stanceType = {
	["DEFAULT"]   = "default",    -- whatever the setting were at spawn
	["REFUELING"] = "refueling",  -- agent is A2A refueling
}

--- Fact types
local factType = {
	["GOAL"]        = 1, -- objref (Goal object)
	["NODE"]        = 2, -- <name>, <type>, [<path>]
	["VALUE"]       = 3, -- Value
	["EVENT"]       = 4,
}

--- Unique fact keys that represents data that should only exist
-- once in the agent's memory
local factKey = {
	["HEALTH"]        = "health",
	["FUEL"]          = "fuel",
	["BINGO"]         = "bingo",
}

local attrmt = {}
function attrmt.__tostring(attr)
	return string.format("%s = %s",
		attr.__clsname or "Attribute",
		json:encode(attr))
end

--- An abstract container generalizing a property of a fact.
local Attribute = utils.override_ops(class("Attribute"), attrmt)
function Attribute:__init(value, confidence)
	self.value = value or 0
	self.confidence = utils.clamp(check.number(confidence or 1), 0, 1)
end

local factmt = {}
function factmt.__tostring(fact)
	return string.format("%s(%s) = %s", fact.__clsname or "Fact",
		utils.getkey(factType, fact.type),
		json:encode(fact))
end

--- A generic data-structure that represents a piece of knowledge the agent
-- has about the world
--
-- @field type of fact object
-- @field updatetime last time the fact was updated
--
-- Attributes a fact can have:
-- @field object     reference to object, confidence is how relevant the
--                   object is to the agent
-- @field objtype    type of object being referenced
-- @field position   vector3D
-- @field direction  vector3D
-- @field owner      which coalition owns the object coalition.side
-- @field event      reference to event object
-- @field value      value representing something
-- @field path       a DCS compatible route table providing a valid path to
--                   the node
local Fact = utils.override_ops(class("Fact"), factmt)
function Fact:__init(t)
	self.type       = check.tblkey(t, factType, "WS.Facts.factType")
	self.updatetime = timer.getTime()
end

--- Goal fact to augment the Agent's basic set of goals. These goals can
-- be used to have the Agent target a specific object.
local GoalFact = class("GoalFact", Fact)
function GoalFact:__init(goal)
	Fact.__init(self, factType.GOAL)
	self.goal = goal
end

--- Represents a point/area in the world the agent knows about. Optionally
-- can have a path to the node.
local NodeFact = class("NodeFact", Fact)
function NodeFact:__init(node, importance, ntype, path)
	Fact.__init(self, factType.NODE)
	self.object    = Attribute(node, importance)
	self.objtype   = Attribute(check.tblkey(ntype, NodeFact.nodeType,
				   "NodeFact.nodeType"))
	self.path      = path
	self.nodeType  = nil
end

NodeFact.nodeType = {
	["INVALID"]    = 0,
	["HOMEBASE"]   = 1,
}

--- Normalized value [0,1] representing something.
local ValueFact = class("ValueFact", Fact)
function ValueFact:__init(val, conf)
	Fact.__init(self, factType.VALUE)
	self.value = Attribute(val, conf)
end

--- Agent received an event from the world and needs to react to it.
local EventFact = class("EventFact", Fact)
function EventFact:__init(event)
	Fact.__init(self, factType.EVENT)
	self.event = event
end

local wsmt = {}
function wsmt.__tostring(ws)
	local tbl = {}

	for _, v in ws:iterate() do
		tbl[v.id] = v.value
	end

	return libs.json:encode(tbl)
end

--- Represents an abstract symbol state relative to the agent
local WorldState = utils.override_ops(class("dct-worldstate",
					    goap.WorldState), wsmt)
function WorldState.createAll()
	local ws = WorldState()
	for _, v in pairs(id) do
		local val = false
		if v == id.STANCE then
			val = stanceType.DEFAULT
		elseif v == id.HEALTH then
			val = healthType.OPERATIONAL
		elseif v == id.ROE then
			val = -1
		elseif v == id.ATNODETYPE then
			val = NodeFact.nodeType.INVALID
		end
		ws:add(goap.Property(v, val))
	end
	ws.createAll = nil
	return ws
end

local function isSuitableStub(--[[agent]])
	return false
end

--- add __lt handler for Actions so they can be ordered correctly,
-- higher order numbers will cause the action to execute later in
-- the plan
local actionmt = {}
function actionmt.__lt(self, other)
	return self.order < other.order
end

function actionmt.__tostring(action)
	return string.format("%s(%d)", action.__clsname or "__unknown__",
			     action.order)
end

--- A simple Action interface. Represents a discrete set of tasks
-- to be done that achieve a given state.
--
-- @field agent [obj] reference to owning agent object
-- @field order [int] defines the sort order the action will appear in the
--   plan, a higher number means later in the plan. The default is 1.
--
-- lua-libs Action object for descriptions of fields cost, precond,
-- effects, and methods.
local Action = utils.override_ops(class("Action", goap.Action),
	actionmt)
function Action:__init(agent, cost, precond, effects, order)
	goap.Action.__init(self, cost, precond, effects)
	self.order = order or 1
	self.agent = agent
	self.isSuitable = nil
	self.Result = nil
end

Action.isSuitable = isSuitableStub

Action.Result = {
	["SUCCESS"]  = 1,  -- action completed successfully
	["CONTINUE"] = 0,  -- action is still running
	["FAIL"]     = -1, -- action can no longer be completed
}

--- Called when this action becomes the active action
-- @return none
function Action:enter()
end

--- Determine if the action is complete.
-- @return 1 if action was completed successfully
-- @return 0 if action is still working
-- @return -1 if action can not longer be completed
function Action:isComplete()
	return Action.Result.FAIL
end

local goalmt = {}
function goalmt.__tostring(tbl)
	return tbl.__clsname or "__unknown__"
end

-- A simple Goal interface that represents a desired world state.
local Goal = utils.override_ops(class("Goal", Observable), goalmt)
function Goal:__init(desiredws, weight, iaus)
	Observable.__init(self)
	self.desiredws = desiredws
	self.iaus = iaus
	self.weight = weight or 1
	self.isSuitable = nil
end

Goal.isSuitable = isSuitableStub

function Goal:WS()
	return self.desiredws
end

function Goal:complete()
	self:notify(dct.event.build.goalComplete(self))
end

--- Calculates the relevance of a goal for a particular agent's
-- current state.
--
-- @return number the priority at which this goal should be
--  considered, higher is more important. Zero disables the goal.
function Goal:relevance(agent)
	local score = self.weight

	if self.iaus then
		score = score * self.iaus:score(agent)
	end
	return score
end

--- add __lt handler for Sensors so they can be ordered correctly,
-- larger numbers will cause the sensor to appear later in the list.
local sensormt = {}
function sensormt.__lt(self, other)
	return self.order < other.order
end

-- Defines the Sensor interface.
--
-- @field agent [ref] reference to owning agent
-- @field order [int] defines the order of execution of the sensor's update
--     function, a larger number means the sensor will be updated later
--
-- __init(agent, order)
-- void  setup()
--    Does any setup needed, called to finalize an Agent's construction.
--    Also, is called when unmarshalling an Agent object.
-- table marshal()
--    Called when Agent:marshal() is called. Is called before the Agent's
--    data is marshalled. This gives the Sensor the opportunity to "fixup"
--    any Agent data. The Sensor can store additional data in the agent.
-- void  onDCTEvent(event)
--    Called when the Agent receives an event
-- bool  update()
--    Called periodically by the Agent. If the function returns true this
--    terminates further processing of sensors that have update functions.
-- void  spawn()
--    Spawn any DCS object the sensor may need. The Agent's spawned flag is
--    still false and Sensor should not relying on anything external to it.
-- void  spawnPost()
--    Take any post spawning actions. The Agent's spawned flag is true and
--    Sensor can rely on data obtained from the Agent object.
-- void  despawn()
--    Same as spawn() except in reverse.
-- void  despawnPost()
--    Same as spawnPost().
local Sensor = utils.override_ops(class("Sensor"), sensormt)
function Sensor:__init(agent, order)
	self.agent = agent
	self.order = order
	self.isSuitable = nil
end

Sensor.isSuitable = isSuitableStub

local planmt = {}
function planmt.__tostring(tbl)
	return string.format("(G:%s, A:%s, sz:%d)",
		tostring(tbl.goal), tostring(tbl.curaction),
		tbl.actionq:size())
end

local Plan = utils.override_ops(class("Plan"), planmt)

--- Constructor.
--
-- @param actions a Queue of worldstate.Action objects the Agent should
--                execute.
-- @param goal worldstate.Goal that the Agent is trying to achieve
function Plan:__init(actions, goal)
	self.actionq   = actions
	self.goal      = goal
	self.curaction = nil
end

--- Return the plan Goal.
--
-- @return worldstate.Goal
function Plan:getGoal()
	return self.goal
end

function Plan:onDCTEvent(event)
	if self.curaction ~= nil and
	   type(self.curaction.onDCTEvent) == "function" then
		self.curaction:onDCTEvent(event)
	end
end

--- Execute plan.
function Plan:execute(agent)
	local action = self.curaction

	if self.actionq:empty() then
		self.goal:complete()
		agent:replan()
		return
	end

	if action == nil then
		self.curaction = self.actionq:peekhead()
		action = self.curaction
		action:enter(agent)
	end

	local rc = action:isComplete(self)
	if rc ~= Action.Result.CONTINUE then
		self.actionq:pophead()
		self.curaction = nil
		if rc == Action.Result.FAIL then
			agent:replan()
		end
	end
end

local _ws = {}
_ws.Attribute = Attribute
_ws.Facts = {
	["factType"]  = factType,
	["factKey"]   = factKey,
	["Goal"]      = GoalFact,
	["Node"]      = NodeFact,
	["Value"]     = ValueFact,
	["Event"]     = EventFact,
}
_ws.ID = id
_ws.Stance = stanceType
_ws.Health = healthType
_ws.Property = goap.Property
_ws.WorldState = WorldState
_ws.Action = Action
_ws.Node = goap.StateNode
_ws.Graph = goap.Graph
_ws.find_plan = goap.find_plan
_ws.Plan = Plan
_ws.Goal = Goal
_ws.Sensor = Sensor

return _ws
