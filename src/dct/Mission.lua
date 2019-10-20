--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Represents a Mission within the game and this associates and
-- Objective to as assigned group of units responsible for
-- completing the Objective.
--]]

-- TODO: a mission consists of
--  * a target asset
--  * an owner - which AI commander initiated the mission and whom's assets
--    will be assigned to complete the mission
--  * a list of assigned assets to accomplish this mission
--  * 'success' critera for each side, so which ever side's success
--    critera is met first is the one that 'wins' that mission.
--
--    This means each AI (and humans) are competiting at multiple locations
--    at the same time. This leads into the question of how to prioritize
--    responses, such as CAP flights. Probably concentration is a good
--    start. An example, the Blue AI has two strike missions occuring 35nm
--    apart from eachother (determined by the 2d euclidian distance between
--    the centroid of each mission's target location) so the Blue AI would
--    then need to schedule a CAP location over/near/in-the-path-of those
--    strike missions from which the enemy would likely come from.
--
--    At the same time Red AI would schedule an intercept, assuming it
--    did not have CAP already in the area.
--
--    Going back to Blue AI, if Blue deteted Red CAP in the area Blue AI
--    should not release those strike missions until a CAP mission was
--    assigned and started. If it were a human assigned mission there
--    could be an option to override the release and go without CAP.
--    This I think would engourage teamwork without forcing it.

local class = require("libs.class")
local Observable = require("observable")

local Mission = class(Observable)
function Mission:__init(groupName, objective)
	Observable.__init(self)
end

function Mission:getID()
end

function Mission:abort()
end

function Mission:join(groupName)
end

function Mission:update()
	-- update the state of the mission
end

function Mission:isComplete()
end

--[[
-- API used by Missions assigned to humans
--]]

function Mission:reportBriefing()
end

function Mission:reportStatus()
end

function Mission:reportAssigned()
end
