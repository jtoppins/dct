--- SPDX-License-Identifier: LGPL-3.0

local utils      = require("libs.utils")
local check      = require("libs.check")
local class      = require("libs.namedclass")
local goap       = require("libs.containers.goap")
local dctenum    = require("dct.enum")
local dctutils   = require("dct.libs.utils")
local Observable = require("dct.libs.Observable")

--- Agent states
local id = {
	["IDLE"]        = "idle",        -- <bool>
	["INAIR"]       = "inAir",       -- <bool>
	["DAMAGED"]     = "damaged",     -- <bool>
	["HASAMMO"]     = "hasAmmo",     -- <bool>
	["HASFUEL"]     = "hasFuel",     -- <bool>
	["HASCARGO"]    = "hasCargo",    -- <bool>
	["SENSORSON"]   = "sensorsOn",   -- <bool>
	["ROE"]         = "roe",         -- <enum> AI.Option.Air.val.ROE.*
	["TARGETDEAD"]  = "targetDead",  -- <bool>
	-- TARGETDEAD must be a bool otherwise we cannot reason a target not
	-- being dead, like in the case of protecting a convoy. The "target"
	-- then should not be dead.
	["ATTARGETPOS"] = "atTargetPos", -- <bool>
	["ATNODE"]      = "atNode",      -- <handle>
	["ATNODETYPE"]  = "atNodeType",  -- <enum>
	["STANCE"]      = "stance",      -- <enum>
	["REACTEDTOEVENT"]    = "reactedToEvent",    -- <bool>
	["DISTURBANCEEXISTS"] = "disturbanceExists", -- <stim-type>
}

--- Stance types the agent can have
local stanceType = {
	["DEFAULT"]   = "default",    -- whatever the setting were at spawn
	["FLEEING"]   = "fleeing",    -- running away, weapons hold
	["GUARDING"]  = "guarding",   -- combat ready, weapons engage per tasking
	["SEARCHING"] = "searching",  -- not combat ready, sensors on
	["ATTACKING"] = "attacking",  -- fangs out
}

--- Fact types
local factType = {
	["DISTURBANCE"] = 1, -- ex: a missile being shot or an explosion
	["EVENT"]       = 2,
	["NODE"]        = 3, -- <name>, <type>, [<path>]
	["CHARACTER"]   = 4, -- <position>, <obj-type>, <obj-name>
	["FUEL"]        = 5, -- Value
	["HEALTH"]      = 6, -- Value
	["AMMO"]        = 7, -- Value
	["CARGO"]       = 8, -- objref (SmartObject)
	["PLAYERMSG"]   = 9, -- msg object
	["LOSETICKET"]  = 10, -- Value
	["CMDPENDING"]  = 11, -- Value
	["SCRATCHPAD"]  = 12, -- Value
}

--- Unique fact keys that represents data that should only exist
-- once in the agent's memory
local factKey = {
	["WELCOMMISSION"] = "welcomemission",
	["WELCOME"]       = "welcome",
	["KICK"]          = "kick",
	["BLOCKSLOT"]     = "blockslot",
	["LANDSAFE"]      = "landsafe",
	["CMDPENDING"]    = "cmdpending",
	["SCRATCHPAD"]    = "scratchpad",
	["LOSETICKET"]    = "loseticket",
}

--- @class Attribute
-- An abstract container generalizing a property of a fact.
local Attribute = class("Attribute")
function Attribute:__init(value, confidence)
	self.value = value or 0
	self.confidence = utils.clamp(confidence or 1, 0, 1)
end

--- @class Fact
-- A generic data-structure that represents a piece of knowledge the agent
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
-- @field delay      numeric value
-- @field path       a DCS compatible route table providing a valid path to
--                   the node
local Fact = class("Fact")
function Fact:__init(t)
	self.type       = check.tblkey(t, factType, "WS.Facts.factType")
	self.updatetime = timer.getTime()
end

--- @class CharacterFact
-- Represents either a DCT or DCS agent that this agent knows about.
local CharacterFact = class("CharacterFact", Fact)
function CharacterFact:__init(obj, importance, objtype)
	Fact.__init(self, factType.CHARACTER)
	self.object    = Attribute(obj, importance)
	self.objtype   = Attribute(check.tblkey(objtype, dctenum.objtype,
				   "dctenum.objtype"))
end

--- @class NodeFact
-- Represents a point/area in the world the agents knows about. Optionally
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
	["RALLYPOINT"] = 1, -- a node that can be retreated to
	["STATION"]    = 2, -- a guard position
}

--- @class StimuliFact
-- Some sort of disturbance the Agent detects that can trigger an change
-- in plan/response.
local StimuliFact = class("StimuliFact", Fact)
function StimuliFact:__init(stimtype, intensity)
	Fact.__init(self, factType.DISTURBANCE)
	self.objtype = Attribute(check.tblkey(stimtype, StimuliFact.stimType,
				 "StimuliFact.stimType"), intensity)
	self.stimType = nil
end
StimuliFact.stimType = {
	["INVALID"]   = 0,
	["EXPLOSION"] = 1, -- like a shell impacting close by
	["LAUNCH"]    = 2, -- like a HARM launch, etc
	["CONTACT"]   = 3, -- like a radar contact
}

--- @class EventFact
-- Agent received an event from the world and needs to react to it.
local EventFact = class("EventFact", Fact)
function EventFact:__init(event)
	Fact.__init(self, factType.EVENT)
	self.event = Attribute(event)
end

--- @class ValueFact
-- Normalized value [0,1] representing something.
local ValueFact = class("ValueFact", Fact)
function ValueFact:__init(t, val, conf, delay)
	Fact.__init(self, t)
	self.value = Attribute(val, conf)
	self.delay = delay
end

--- @class PlayerMsgFact
-- Message fact that needs to be displayed to the player.
local PlayerMsgFact = class("PlayerMsgFact", ValueFact)
function PlayerMsgFact:__init(msg, delay)
	ValueFact.__init(self, factType.PLAYERMSG, msg, nil, delay)
end

--- @class WorldState
-- Represents an abstract symbol state relative to the agent
local WorldState = class("dct-worldstate", goap.WorldState)
function WorldState.createAll()
	local ws = WorldState()
	for _, v in pairs(id) do
		local val = false
		if v == id.STANCE then
			val = stanceType.DEFAULT
		elseif v == id.ROE then
			val = -1
		elseif v == id.HASFUEL or v == id.IDLE or
		       v == id.HASAMMO then
			val = true
		elseif v == id.ATNODETYPE then
			val = NodeFact.nodeType.INVALID
		elseif v == id.DISTURBANCEEXISTS then
			val = StimuliFact.stimType.INVALID
		end
		ws:add(goap.Property(v, val))
	end
	ws.createAll = nil
	return ws
end

--- add __lt handler for Actions so they can be ordered correctly,
-- higher order numbers will cause the action to execute later in
-- the plan
local actionmt = {}
function actionmt.__lt(self, other)
	return self.order < other.order
end

--- @class Action
-- A simple Action interface. Represents a discrete set of tasks
-- to be done that achieve a given state.
--
-- @field agent [obj] reference to owning agent object
-- @field order [int] defines the sort order the action will appear in the
--   plan, a higher number means later in the plan. The default is 1.
--
-- @note See lua-libs Action object for descriptions of fields
--   cost, precond, effects, and methods.
local Action = utils.override_ops(class("Action", goap.Action),
	actionmt)
function Action:__init(agent, cost, precond, effects, order)
	goap.Action.__init(self, cost, precond, effects)
	self.order = order or 1
	self.agent = agent
end

--- Called when this action becomes the active action
-- @return none
function Action:enter()
end

--- Determine if the action is complete.
-- @return <bool>, true action is complete
function Action:isComplete()
	return true
end

--- @class Goal
-- A simple Goal interface that represents a desired world state.
local Goal = class("Goal", Observable)
function Goal:__init(desiredws, weight, iaus)
	Observable.__init(self)
	self.desiredws = desiredws
	self.iaus = iaus
	self.weight = weight or 1
end

function Goal:WS()
	return self.desiredws
end

function Goal:complete()
	self:notify(dctutils.buildevent.goalComplete(self))
end

--- Calculates the relevance of a goal for a particular agent's
-- current state.
--
-- @return <number> the priority at which this goal should be
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

--- @class Sensor
-- Defines the Sensor interface.
--
-- @field agent [ref] reference to owning agent
-- @field order [int] defines the order of execution of the sensor's update
--     function, a larger number means the sensor will be updated later
--
-- @method __init(agent, order)
-- @optionalmethod void  setup()
--    Does any setup needed, called to finalize an Agent's construction.
--    Also, is called when unmarshalling an Agent object.
-- @optionalmethod table marshal()
--    Called when Agent:marshal() is called. Is called before the Agent's
--    data is marshalled. This gives the Sensor the opportunity to "fixup"
--    any Agent data. The Sensor can store additional data in the agent.
-- @optionalmethod void  onDCTEvent(event)
--    Called when the Agent receives an event
-- @optionalmethod bool  update()
--    Called periodically by the Agent. If the function returns true this
--    terminates further processing of sensors that have update functions.
-- @optionalmethod void  spawn()
--    Spawn any DCS object the sensor may need. The Agent's spawned flag is
--    still false and Sensor should not relying on anything external to it.
-- @optionalmethod void  spawnPost()
--    Take any post spawning actions. The Agent's spawned flag is true and
--    Sensor can rely on data obtained from the Agent object.
-- @optionalmethod void  despawn()
--    Same as spawn() except in reverse.
-- @optionalmethod void  despawnPost()
--    Same as spawnPost().
local Sensor = utils.override_ops(class("Sensor"), sensormt)
function Sensor:__init(agent, order)
	self.agent = agent
	self.order = order
end

local _ws = {}
_ws.Attribute = Attribute
_ws.Facts = {
	["factType"]  = factType,
	["factKey"]   = factKey,
	["Node"]      = NodeFact,
	["Character"] = CharacterFact,
	["Stimuli"]   = StimuliFact,
	["Event"]     = EventFact,
	["Value"]     = ValueFact,
	["PlayerMsg"] = PlayerMsgFact,
}
_ws.ID = id
_ws.Stance = stanceType
_ws.Property = goap.Property
_ws.WorldState = WorldState
_ws.Action = Action
_ws.Node = goap.StateNode
_ws.Graph = goap.Graph
_ws.find_plan = goap.find_plan
_ws.Goal = Goal
_ws.Sensor = Sensor

return _ws
