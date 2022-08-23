--- SPDX-License-Identifier: LGPL-3.0

local class     = require("libs.namedclass")
local dctenum   = require("dct.enum")
local DCTEvents = require("dct.libs.DCTEvents")
local WS        = require("dct.assets.worldstate")

-- TODO: need to work out how Missions get assigned to an Agent and what
-- the final set of events are from a Mission. Should probably follow
-- the PlayerSensor architecture in that the event is posted to the
-- Agent's memory (fact list) and then the planner is tasked with handling
-- the mission Fact.
--
-- Events:
-- * mission assign (was assigned a mission generate a plan to complete)
-- * mission leave (left mission, replan)
-- * mission update (mission updated, replan)
-- * mission complete (mission complete, replan)
-- * mission specific action (check-in/check-out/pickup/dropoff)
--    - can post these player initiated events as facts and let the current
--      misstion plan handle it?
--
-- Actions:
-- * MissionAssign (mission request event)
-- * MissionLeave (mission leave event)
-- * MissionUpdate (update agent's mission facts)
-- * MissionComplete (delete all agent's mission related facts, don't need to
--     keep mission related facts with the mission)

--- @class MissionSensor
-- Manages and monitors any Mission object assigned to the Agent.
local MissionSensor = class("MissionSensor", WS.Sensor, DCTEvents)
function MissionSensor:__init(agent)
	WS.Sensor.__init(self, agent, 20)
	DCTEvents.__init(self)

	self:_overridehandlers({
		[dctenum.event.DCT_EVENT_MISSION_DONE]   = self.missionDone,
		[dctenum.event.DCT_EVENT_MISSION_UPDATE] = self.missionUpdate,
	})
end

--- tell agent to dump the mission and replan
function MissionSensor:missionDone(event)
	if event.initiator ~= self.agent:getMission() then
		self.agent._logger:error("unknown mission: %s",
			event.initiator.__clsname)
		return
	end

	self.agent:setMission(nil)
	event.initiator:remove(self.agent)
	self.agent:replan()
end

--- Update mission goal by getting a new goal from the mission,
-- check if current goal was previous msn goal and if so trigger
-- replanning
function MissionSensor:missionUpdate(event)
	if event.initiator ~= self.agent:getMission() then
		self.agent._logger:error("unknown mission: %s",
			event.initiator.__clsname)
		return
	end

	self.agent:replan()
end

return MissionSensor
