-- SPDX-License-Identifier: LGPL-3.0

require("math")
require("libs")
local class     = libs.classnamed
local pqueue    = libs.containers.PriorityQueue
local dctutils  = require("dct.libs.utils")
local Timer     = require("dct.libs.Timer")
local DCTEvents = require("dct.libs.DCTEvents")
local Mission   = require("dct.ai.Mission")
local human     = require("dct.ui.human")
local uirequest = require("dct.ui.request")
--local uimenus   = require("dct.ui.menus")
local WS        = require("dct.agent.worldstate")
local UPDATE_TIME = 5

local result_msgs = {
	[Mission.typeResult.ABORT]   = "aborted",
	[Mission.typeResult.TIMEOUT] = "timed out",
	[Mission.typeResult.SUCCESS] = "completed",
}

local function is_player_msg(fact)
	return fact.type == WS.Facts.factType.PLAYERMSG
end

local function display_messages(agent, ctime, maxmsgs)
	local gid = agent:getDescKey("groupId")
	local pq = pqueue()
	local maxdelay = 0

	for key, fact in agent:iterateFacts(is_player_msg) do
		if fact.updatetime < ctime then
			pq:push(fact.value.confidence, key)
		end
	end

	while not pq:empty() and maxmsgs > 0 do
		local key = pq:pop()
		local fact = agent:getFact(key)

		trigger.action.outTextForGroup(gid, fact.value.value,
					       fact.delay, false)
		maxdelay = math.max(maxdelay, fact.delay)
		maxmsgs = maxmsgs - 1
		agent:setFact(key, nil)
	end
	return maxdelay
end

local function ismenu(fact)
	if fact.type == WS.Facts.factType.PLAYERMENU then
		return true
	end
	return false
end

local function reset_menus(agent)
	if not dctutils.isalive(agent.name) then
		return
	end

	for _, fact in agent:iterateFacts(ismenu) do
		fact.object.value:reset()
	end
end

--- @classmod PlayerUISensor
-- Manages drawing UI elements to the player. Be that text messages,
-- F10 map elements, or F10 menu updates. This sensor handles these
-- issues.
--
-- ## Menu Data flow
-- ### Setup
-- Each top level menu is added as a memory fact to the agent. This
-- allows other systems to access the menu fact in a well known way.
-- As an example Actions can access a given menu and add context
-- specific items to a menu.
--
-- ### Player triggers action
-- When a player triggers a menu entry the player object is found
-- and Agent:onDCTEvent(request) is called. Any Sensors listening
-- for the DCT_EVENT_AGENT_REQUEST will have the opportunity to
-- handle the event. Additionally the current active Action will
-- also receive the event if the action implements onDCTEvent method.
--
-- PlayerUISensor:
-- If the agent request is one of the common requests, dispatch a
-- command to be executed later. Set CMDPENDING true and waits for
-- the delayed command to complete. The command will automatically
-- clear the CMDPENDING flag once the command completes.
--
-- This sensor must be executed after the PlayerSensor otherwise
-- the Agent's Mission object will not be set correctly.
--
-- @field timer how often this sensor updates
-- @field lastsent how recently a player message was posted
-- @field menucreated if the player group menu has been created
local PlayerUISensor = class("PlayerUISensor", WS.Sensor, DCTEvents)
function PlayerUISensor:__init(agent)
	WS.Sensor.__init(self, agent, 50)
	DCTEvents.__init(self)
	self.timer         = Timer(UPDATE_TIME)
	self.lastsent      = 0
	self.menucreated   = false

	self:_overridehandlers({
		[world.event.S_EVENT_BIRTH] = self.handleBirth,
		[dct.event.ID.DCT_EVENT_AGENT_REQUEST] =
			self.handleAgentRequest,
		[dct.event.ID.DCT_EVENT_MISSION_JOIN] =
			self.handleMissionJoin,
		[dct.event.ID.DCT_EVENT_MISSION_LEAVE] =
			self.handleMissionLeave,
		[dct.event.ID.DCT_EVENT_MISSION_DONE] =
			self.handleMissionDone,
		[dct.event.ID.DCT_EVENT_MISSION_UPDATE] =
			self.handleMissionUpdate,
	})
end

function PlayerUISensor:handleBirth(event)
	if event.initiator:getName() ~= self.agent.name then
		return
	end

	if self.menucreated == false then
		uimenus(self.agent)
		self.menucreated = true
	end
end

function PlayerUISensor:handleMissionJoin(event)
	if event.member.name ~= self.agent.name or
	   not dctutils.isalive(self.agent.name) then
		return
	end

	uirequest.post_msg(self.agent, WS.Facts.factKey.MSNBRIEFMSG,
		string.format("Mission %s assigned, use F10 menu "..
		"to see this briefing again.\n\n", event.initiator:getID())..
		human.mission_briefing(self.agent), 120)
end

function PlayerUISensor:handleMissionLeave(event)
	if event.member.name ~= self.agent.name or
	   not dctutils.isalive(self.agent.name) then
		return
	end

	uirequest.post_msg(self.agent, WS.Facts.factKey.MSNLEAVEMSG,
		"Leaving mission, select another or RTB", 20)
end

function PlayerUISensor:handleMissionDone(event)
	if not dctutils.isalive(self.agent.name) then
		return
	end

	local msg = string.format("Mission %s",
		result_msgs[event.reason] or "aborted - unknown reason")

	uirequest.post_msg(self.agent, WS.Facts.factKey.MSNDONEMSG, msg, 20)
end

function PlayerUISensor:handleMissionUpdate(event)
	if event.initiator ~= self.agent:getMission() then
		self.agent._logger:error("member of unknown mission: %s",
			event.initiator.__clsname)
	end

	if not dctutils.isalive(self.agent.name) then
		return
	end

	uirequest.post_msg(self.agent, WS.Facts.factKey.MSNUPDATEMSG,
		"standby for mission update ...", 20)
end

function PlayerUISensor:onReplan()
	reset_menus(self.agent)
end

function PlayerUISensor:onActionComplete()
	reset_menus(self.agent)
end

function PlayerUISensor:spawnPost()
	self.timer:reset()
	self.timer:start()
end

function PlayerUISensor:despawnPost()
	self.timer:stop()
end

function PlayerUISensor:update()
	self.timer:update()
	if not self.timer:expired() then
		return false
	end
	self.timer:reset()
	self.timer:start()

	local ctime = timer.getTime()
	if ctime > self.lastsent then
		self.lastsent = ctime + display_messages(self.agent, ctime, 4)
	end

	-- TODO: draw any F10 elements the player has requested and are
	--       pending in memory

	return false
end

return PlayerUISensor
