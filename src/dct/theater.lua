--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Defines the Theater class.
--]]

require("lfs")
local class      = require("libs.class")
local Region     = require("dct.region")
local Logger     = require("dct.logger")
local DebugStats = require("dct.debugstats")
local Profiler   = require("dct.profiling")

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
	self.dbgstats:registerStat("obj", 0, "objective(s) loaded")
	self.dbgstats:registerStat("spawn", 0, "objectives spawned")
	self.path      = _G.dct.settings.theaterpath
	self.statepath = _G.dct.settings.statepath
	self.dirty     = false

	self:__loadGoals()
	self:__loadRegions()
	self:__loadOrGenerate()
	self:spawnActive()
	prof:profileStop("Theater:init()")
end

-- a description of the world state that signifies a particular side wins
function Theater:__loadGoals()
	local goalpath = self.path .. "/theater.goals"
	local rc = pcall(dofile, goalpath)
	assert(rc, "failed to parse: theater goal file, '" ..
			goalpath .. "' path likely doesn't exist")
	assert(theatergoals ~= nil, "no theatergoals structure defined")

	self.goals = {}
	-- TODO: translate goal definitions written in the lua files to any
	-- needed internal state.
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

function Theater:__loadOrGenerate()
	self.objectives = {}
	local statefile = io.open(self.statepath)

	if statefile then
		local jsonstate = statefile:read("*all")
		statefile:close()
		statefile = nil
		self:__initFromState(json:decode(jsonstate))
	else
		self:generate()
		self:__dirtySet()
	end
end

function Theater:__initFromState(jsontbl)
	return
end

function Theater:__dirtySet()
    self.dirty = true
end

function Theater:dirtyClear()
    self.dirty = false
end

function Theater:export()
	-- TODO: export a copy of the game state in a
	-- flat table representation
	self:dirtyClear()
end

-- generate a new theater
function Theater:generate()
	-- generate static objectives
	for name, r in pairs(self.regions) do
		r:generate(self)
	end
end

function Theater:addObjective(side, obj)
	-- TODO: for now do a simple storage of the objectives, it is assumed
	-- all objective names are unique
	self.objectives[obj.name] = obj
	self.dbgstats:incstat("obj", 1)
end

function Theater:spawnActive()
    -- TODO: for now we are just going to spawn everything
	for name, obj in pairs(self.objectives) do
		obj:spawn()
		self.logger:debug("Spawning: '"..name.."'")
		self.dbgstats:incstat("spawn", 1)
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
