-- SPDX-License-Identifier: LGPL-3.0

local class      = require("libs.namedclass")
local containers = require("libs.containers")
local dctenum    = require("dct.enum")
local Mission    = require("dct.libs.Mission")
local WS         = require("dct.assets.worldstate")
local Guard      = require("dct.assets.goals.Guard")

local IADS = class("Integrated Air Defense", Mission)
function IADS:__init(cmdr)
	local Q = containers.Queue()
	local guard = Guard()

	guard:WS():add(WS.Property(WS.ID.ROE,
				   AI.Option.Air.val.ROE.OPEN_FIRE))
	Q:pushtail(guard)
	Mission.__init(cmdr, Q)
	self._eventhandlers[dctenum.event.DCT_EVENT_GOAL_COMPLETE] = nil
end

-- TODO: could update this mission to where it kinda drives itself.
-- First by monitoring the status of the region the mission is assigned to.
-- Second by writing a goal() method that issues a customized goal to
-- the requesting agent. Can be used to issue search goals to EWR sites and
-- guard/hide goals to SAM sites.
-- Third can force agents participating in the mission to replan by
-- issuing a missionUpdate event as underlying region state changes. Also
-- by monitoring the underlying state of the region and the facts added by
-- searching EWRs the mission itself could request additional resources;
--    air cover, awacs, etc
--
-- Missing features:
-- * how to terminate the mission to simulate loss of corrdination in the
--   region; this could be done a couple of ways
--   1) by terminating the mission once all the EWRs are destroyed
--   2) once a specific "command center" in the region dies
--   3) always be connected (the mission never terminates) "god-eye" mode
