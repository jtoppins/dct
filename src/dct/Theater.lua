--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Defines the Theater class.
--]]

require("lfs")
local class       = require("libs.class")
local utils       = require("libs.utils")
local json        = require("libs.json")
local Region      = require("dct.Region")
local AssetManager= require("dct.AssetManager")
local Logger      = require("dct.Logger").getByName("Theater")
local DebugStats  = require("dct.DebugStats").getDebugStats()
local Profiler    = require("dct.Profiler").getProfiler()

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
	Profiler:profileStart("Theater:init()")
	DebugStats:registerStat("regions", 0, "region(s) loaded")
	self.path      = _G.dct.settings.theaterpath
	self.statepath = _G.dct.settings.statepath
	self.dirty     = false
	self.regions   = {}
	self.assetmgr  = AssetManager(self)

	self:__loadGoals()
	self:__loadRegions()
	self:__loadOrGenerate()
	Profiler:profileStop("Theater:init()")
end

-- a description of the world state that signifies a particular side wins
function Theater:__loadGoals()
	local goalpath = self.path..utils.sep.."theater.goals"
	local rc = pcall(dofile, goalpath)
	assert(rc, "failed to parse: theater goal file, '" ..
			goalpath .. "' path likely doesn't exist")
	assert(theatergoals ~= nil, "no theatergoals structure defined")

	self.goals = {}
	-- TODO: translate goal definitions written in the lua files to any
	-- needed internal state.
	-- Theater goals are goals written in a success format, meaning the
	-- first side to complete all their goals wins
	theatergoals = nil
end

function Theater:__loadRegions()
	for filename in lfs.dir(self.path) do
		if filename ~= "." and filename ~= ".." and
			filename ~= ".git" then
			local fpath = self.path..utils.sep..filename
			local fattr = lfs.attributes(fpath)
			if fattr.mode == "directory" then
				local r = Region(fpath)
				assert(self.regions[r.name] == nil, "duplicate regions " ..
						"defined for theater: " .. self.path)
				self.regions[r.name] = r
				DebugStats:incstat("regions", 1)
			end
		end
	end
end

function Theater:__loadOrGenerate()
	self.objectives = {}
	local statefile = io.open(self.statepath)

	if statefile ~= nil then
		local statetbl = json:decode(statefile:read("*all"))
		statefile:close()
		statefile = nil
		self:__initFromState(statetbl)
	else
		self:generate()
		self:__dirtySet()
	end
end

function Theater:__initFromState(jsontbl)
	-- TODO: use saved state recreate objects
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

function Theater:generate()
	for _, r in pairs(self.regions) do
		r:generate(self.assetmgr)
	end
end

function Theater:exec(time)
	local rescheduletime = nil

	-- TODO: write this

	return rescheduletime
end

function Theater:onEvent(event)
	self.assetmgr:onDCSEvent(event)
end

return Theater
