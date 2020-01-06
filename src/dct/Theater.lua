--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Defines the Theater class.
--]]

require("lfs")
local class       = require("libs.class")
local utils       = require("libs.utils")
local containers  = require("libs.containers")
local json        = require("libs.json")
local enum        = require("dct.enum")
local uicmds      = require("dct.ui.cmds")
local uimenu      = require("dct.ui.groupmenu")
local Observable  = require("dct.Observable")
local Region      = require("dct.Region")
local AssetManager= require("dct.AssetManager")
local Commander   = require("dct.ai.Commander")
local Logger      = require("dct.Logger").getByName("Theater")
local DebugStats  = require("dct.DebugStats").getDebugStats()
local Profiler    = require("dct.Profiler").getProfiler()
local settings    = _G.dct.settings

local RESCHEDULE_FREQ = 0.5 -- seconds
local UI_CMD_DELAY    = 2

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
local Theater = class(Observable)
function Theater:__init()
	Observable.__init(self)
	Profiler:profileStart("Theater:init()")
	DebugStats:registerStat("regions", 0, "region(s) loaded")
	self.path      = _G.dct.settings.theaterpath
	self.statepath = _G.dct.settings.statepath
	self.regions   = {}
	self.cmdq      = containers.PriorityQueue()
	self.ctime     = timer.getTime()
	self.ltime     = 0
	self.assetmgr  = AssetManager(self)
	self.cmdrs     = {}
	self.playergps = {}

	for _, val in pairs(coalition.side) do
		self.cmdrs[val] = Commander(self, val)
	end

	self:_loadGoals()
	self:_loadRegions()
	self:_loadOrGenerate()
	uimenu(self)
	Profiler:profileStop("Theater:init()")
end

-- a description of the world state that signifies a particular side wins
-- TODO: create a common function that will read in a lua file like below
-- verify it was read correctly, contains the token expected, returns the
-- token on the stack and clears the global token space
function Theater:_loadGoals()
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

function Theater:_loadRegions()
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

function Theater:_loadOrGenerate()
	self.objectives = {}
	local statefile = io.open(self.statepath)

	if statefile ~= nil then
		local statetbl = json:decode(statefile:read("*all"))
		statefile:close()
		self:_initFromState(statetbl)
	else
		self:generate()
	end
end

function Theater:_initFromState(jsontbl)
	-- TODO: use saved state recreate objects
	return
end

function Theater:export()
	-- TODO: export a copy of the game state in a
	-- flat table representation
end

function Theater:generate()
	for _, r in pairs(self.regions) do
		r:generate(self.assetmgr)
	end
end

function Theater:getAssetMgr()
	return self.assetmgr
end

function Theater:getCommander(side)
	return self.cmdrs[side]
end

function Theater:playerRequest(data)
	Logger:debug("playerRequest(); Received player request: "..
		json:encode_pretty(data))

	if self.playergps[data.name].cmdpending == true then
		Logger:debug("playerRequest(); request pending, ignoring")
		trigger.action.outTextForGroup(data.id,
			"F10 request already pending, please wait.", 20, true)
		return
	end

	local cmd = uicmds[data.type](self, data)
	self:queueCommand(UI_CMD_DELAY, cmd)
	self.playergps[data.name].cmdpending = true
end

function Theater:getATORestrictions(side, unittype)
	local unitATO = settings.atorestrictions[side][unittype]

	if unitATO == nil then
		unitATO = enum.missionType
	end
	return unitATO
end

--[[
-- do not worry about command priority right now
-- command queue discussion,
--  * central Q
--  * priority ordered in both priority and time
--     priority = time * 128 + P
--     time = (priority - P) / 128
--
--    This allows things of higher priority to be executed first
--    but things that need to be executed at around the same time
--    to also occur.
--
-- delay - amount of delay in seconds before the command is run
-- cmd   - the command to be run
--]]
function Theater:queueCommand(delay, cmd)
	self.cmdq:push(self.ctime + delay, cmd)
	Logger:debug("queueCommand(); cmdq size: "..self.cmdq:size())
end

function Theater:_exec(time)
	-- TODO: insert profiling hooks to count the moving average of
	-- 10 samples for how long it takes to execute a command
	self.ltime = self.ctime
	self.ctime = time
	local rescheduletime = time + RESCHEDULE_FREQ

	if self.cmdq:empty() then
		return rescheduletime
	end

	local _, prio = self.cmdq:peek()
	if time < prio then
		return rescheduletime
	end

	Logger:debug("exec() - execute command")
	local cmd = self.cmdq:pop()
	local requeue = cmd:execute(time)
	if requeue ~= nil and type(requeue) == "number" then
		self:queueCommand(requeue, cmd)
	end
	return rescheduletime
end

function Theater:exec(time)
	local retval
	local errhandler = function(err)
		Logger:error("protected call - "..tostring(err).."\n"..
			debug.traceback())
	end
	local pcallfunc = function()
		retval = self:_exec(time)
	end

	xpcall(pcallfunc, errhandler)
	return retval
end

return Theater
