--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides functions for defining a region.
--]]

require("io")
require("lfs")
local class    = require("libs.class")
local utils    = require("libs.utils")
local region   = require("dct.region")


--[[
--  Theater class
--    base class that reads in all region and template information
--    and provides a base interface for manipulating data at a theater
--    level.
--
--  Storage of theater:
--		goals = {
--			<goalname> = State(),
--		},
--		regions = {
--			<regionname> = Region(),
--		},
--]]
local Theater = class()
function Theater:__init(theaterpath)
	self.path = theaterpath
	self:__loadGoals()
	self:__loadRegions()

	-- TODO: [maybe] if a theater state exists load this previous state
end

-- a description of the world state that signafies a particular side wins
function Theater:__loadGoals()
	local goalpath = self.path .. "/theater.goals"
	local rc = false

	rc = pcall(dofile, goalpath)
	assert(rc, "failed to parse: theater goal file, '" ..
			goalpath .. "' path likely doesn't exist")
	assert(theatergoals ~= nil, "no theatergoals structure defined")

	self.goals = createGoalStates(theatergoals)
	theatergoals = nil
end

function Theater:__loadRegions()
	self.regions = {}

	for filename in lfs.dir(self.path) do
		if filename ~= "." and filename ~= ".." then
			local fpath = self.path .. "/" .. filename
			local fattr = lfs.attributes(fpath)
			if fattr.mode == "directory" then
				local r = Region(fpath)
				assert(self.regions[r.name] == nil, "duplicate regions " ..
						"defined for theater: " .. self.path)
				self.regions[r.name] = r
			end
		end
	end
end

-- generate a new theater
function Theater:generate()
	-- TODO: [maybe] foreach region determine which facilities will spawn

	-- 
end
