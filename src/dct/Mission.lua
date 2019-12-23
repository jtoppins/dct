--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Represents a Mission within the game and this associates an
-- Objective to as assigned group of units responsible for
-- completing the Objective.
--]]

-- TODO: a mission consists of
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

-- TODO: issues
--  * how does a mission access the global asset manager?
--	  - give a reference
--  * what stats does a mission need to track?
--    - timeout
--    - world state of mission
--  * does a mission need to "listen" to events from a target
--    or assigned assets?
--    - probably not, just makes things complicated instead
--      periodically check missions in a commander

local class = require("libs.class")

local MISSION_LIMIT = 60*60*3  -- 3 hours in seconds

local function gen_mission_id()
	return "A1234"
end

local Mission = class()
function Mission:__init(cmdr, missiontype, grpname, tgtname)
	-- reference to owning commander
	self.cmdr      = cmdr
	self.id        = gen_mission_id()
	self.type      = missiontype
	self.target    = tgtname
	self.assigned  = grpname
	self.timestart = timer.getTime()
	self.timeend   = self.timestart + MISSION_LIMIT
	self.breifing  = ""

	--local tgt = self.cmdr:getAsset(self.target)
	-- TODO: setup remaining mission parameters
end

function Mission:getID()
	return self.id
end

--[[
-- Abort - aborts a mission putting the targeted asset back into
--   the pool.
--
-- Things that need to be managed;
--  * removing the mission from the owning commander's mission
--    list(s)
--  * releasing the targeted asset by resetting the asset's targeted
--    bit
--]]
function Mission:abort()
	self.cmdr:removeMission(self.id)
	local tgt = self.cmdr:getAsset(self.target)
	if tgt then
		tgt:setTargeted(false)
	end
	return self.id
end

function Mission:update()
	-- update the state of the mission
end

function Mission:isComplete()
end

-- provides target info information
-- Data supplied:
--   * target location - centroid of the asset
--   * target callsign
--   * target description - not the mission description, a short two word
--       description of the individual target like;
--       factory, ammo bunker, etc.
--   * target status - a numercal value from 0 to 100 representing
--       percentage completion
function Mission:getTargetInfo()
	local tgtinfo = {}
	tgtinfo.location = { ["x"] = 100, ["z"] = 100 }
	tgtinfo.callsign = "test-callsign"
	tgtinfo.status = 50
	return tgtinfo
end

function Mission:getTimeout()
	return self.timeend
end

function Mission:addTime(time)
	self.timeend = self.timeend + time
	return time
end

function Mission:checkin(time)
end

function Mission:checkout(time)
end

function Mission:getDescription()
	return "TODO description"
end

return Mission
