--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Defines the Theater class.
--]]

require("lfs")
local class      = require("libs.class")
local Region     = require("dct.region")
local GameState  = require("dct.gamestate")
local Logger     = require("dct.logger")
local DebugStats = require("dct.debugstats")
local Profiler   = require("dct.profiling")

local function createGoalStates(goals)
	local states = {}

	-- TODO: translate goal definitions written in the lua files to any
	-- needed internal state.

	return states
end

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
function Theater:__init()
	local prof = Profiler.getProfiler()
	prof:profileStart("Theater:init()")
	self.logger    = Logger.getByName("theater")
	self.dbgstats  = DebugStats.getDebugStats()
	self.dbgstats:registerStat("regions", 0, "region(s) loaded")
	self.path      = _G.dct.settings.theaterpath
	self.pathstate = lfs.writedir() .. env.mission.theatre ..
		env.getValueDictByKey(env.mission.sortie) .. ".state"
	self.state     = GameState(self, self.pathstate)

	self:__loadGoals()
	self:__loadRegions()

	if self.state:shouldGenerate() then
		-- generate a new theater
		for name, r in pairs(self.regions) do
			self.state:addObjectives(name, r:generate())
		end
	end

	self.state:spawnActive()
	prof:profileStop("Theater:init()")
end

-- a description of the world state that signifies a particular side wins
function Theater:__loadGoals()
	local goalpath = self.path .. "/theater.goals"
	local rc = pcall(dofile, goalpath)
	assert(rc, "failed to parse: theater goal file, '" ..
			goalpath .. "' path likely doesn't exist")
	assert(theatergoals ~= nil, "no theatergoals structure defined")

	self.goals = createGoalStates(theatergoals)
	theatergoals = nil
end

function Theater:__loadRegions()
	self.regions = {}

	for filename in lfs.dir(self.path) do
		if filename ~= "." and filename ~= ".." and
			filename ~= ".git" then
			local fpath = self.path .. "/" .. filename
			local fattr = lfs.attributes(fpath)
			if fattr.mode == "directory" then
				local r = Region(fpath)
				assert(self.regions[r.name] == nil, "duplicate regions " ..
						"defined for theater: " .. self.path)
				self.regions[r.name] = r
				self.dbgstats:incstat("regions", 1)
			end
		end
	end
end

function Theater:onEvent(event)
	-- TODO: write this
	--	probably best to support a registration system where other objects
	--	can register a function for a specific event; which receives two
	--	arguments: context, event
end

function Theater:exec(time)
	local rescheduletime = nil

	-- TODO: write this

	return rescheduletime
end

return Theater

--[[
world state
	* <side>
		- pilot losses
		- objective type stats
		- bool primary_objectives_left()


	Theater has a state
		a state consists of:
			* objectives
			* ??
--]]
