-- SPDX-License-Identifier: LGPL-3.0

require("libs")
local class     = libs.classnamed
local DCTEvents = require("dct.libs.DCTEvents")
local WS        = require("dct.agent.worldstate")

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
--      mission plan handle it?
--
-- Actions:
-- * MissionAssign (mission request event)
-- * MissionLeave (mission leave event)
-- * MissionUpdate (update agent's mission facts)
-- * MissionComplete (delete all agent's mission related facts, don't need to
--     keep mission related facts with the mission)

--- @classmod MissionSensor
-- Manages and monitors any Mission object assigned to the Agent.
local MissionSensor = class("MissionSensor", WS.Sensor, DCTEvents)
function MissionSensor:__init(agent)
	WS.Sensor.__init(self, agent, 20)
	DCTEvents.__init(self)

	self:_overridehandlers({
		[dct.event.ID.DCT_EVENT_MISSION_JOIN]   = self.missionJoin,
		[dct.event.ID.DCT_EVENT_MISSION_UPDATE] = self.missionUpdate,
		[dct.event.ID.DCT_EVENT_MISSION_LEAVE]  = self.missionDone,
		[dct.event.ID.DCT_EVENT_MISSION_DONE]   = self.missionDone,
	})
end

function MissionSensor:missionJoin(event)
	self.agent:setMission(event.initiator)
	self.agent:replan()
end

--- Update mission goal by getting a new goal from the mission,
-- check if current goal was previous msn goal and if so trigger
-- replanning
function MissionSensor:missionUpdate(event)
	if event.initiator ~= self.agent:getMission() then
		return
	end

	self.agent:replan()
end

--- tell agent to dump the mission and replan
function MissionSensor:missionDone(event)
	if event.initiator ~= self.agent:getMission() then
		return
	end

	self.agent:setMission(nil)
	self.agent:replan()
end

return MissionSensor
