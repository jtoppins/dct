--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Defines the Theater class.
--]]

require("os")
require("io")
require("lfs")
local class       = require("libs.namedclass")
local containers  = require("libs.containers")
local json        = require("libs.json")
local enum        = require("dct.enum")
local dctutils    = require("dct.utils")
local Observable  = require("dct.libs.Observable")
local uicmds      = require("dct.ui.cmds")
local Commander   = require("dct.ai.Commander")
local Command     = require("dct.Command")
local Logger      = dct.Logger.getByName("Theater")
local settings    = _G.dct.settings.server
local STATE_VERSION = "3"

--[[--
 Component system. Defines a generic way for initializing components
 of the system without directly tying the two systems together.
 A system can provide the following methods:

 @function __init initialization
 @function marshal all the system's data for serialization
 @function unmarshal initializes the system from the saved data
 @function generate any Assets the system may need
 @function postinit run after __init and generate, thus guarantees all
   assets are generated after all Assets have been created/loaded
--]]
local Systems = class("System")
function Systems:__init()
	self._systemscnt = 0
	self._systems  = {}

	local systems = {
		"dct.assets.AssetManager",
		"dct.ui.scratchpad",
		"dct.systems.tickets",
		"dct.systems.bldgPersist",
		"dct.systems.weaponstracking",
		"dct.systems.blasteffects",
		"dct.systems.playerslots",
		"dct.templates.RegionManager",
	}

	for _, syspath in ipairs(systems) do
		self:addSystem(syspath)
	end
	Logger:info("systems init: "..tostring(self._systemscnt))
end

function Systems:marshal()
	local tbl = {}
	for name, sys in pairs(self._systems) do
		if type(sys.marshal) == "function" then
			tbl[name] = sys:marshal()
		end
	end
	return tbl
end

function Systems:unmarshal(tbl)
	for name, data in pairs(tbl) do
		local sys = self:getSystem(name)
		if sys ~= nil and type(sys.unmarshal) == "function" then
			sys:unmarshal(data)
		end
	end
end

-- runs a system method that can optionally be provided by a system
function Systems:_runsys(methodname, ...)
	for sysname, sys in pairs(self._systems) do
		if type(sys[methodname]) == "function" then
			Logger:info("system calling "..sysname..":"..methodname)
			sys[methodname](sys, ...)
		end
	end
end

function Systems:getSystem(path)
	return self._systems[path]
end

function Systems:addSystem(path)
	if self._systems[path] ~= nil then
		return
	end
	self._systems[path] = require(path)(self)
	Logger:info("init "..path)
	self._systemscnt = self._systemscnt + 1
end

local function isStateValid(state)
	if state == nil then
		Logger:info("isStateValid(); state object nil")
		return false
	end

	if state.complete == true then
		Logger:info("isStateValid(); theater goals were completed")
		return false
	end

	if state.version ~= STATE_VERSION then
		Logger:warn("isStateValid(); invalid state version")
		return false
	end

	if state.theater ~= env.mission.theatre then
		Logger:warn(string.format("isStateValid(); wrong theater; "..
			"state: '%s'; mission: '%s'", state.theater, env.mission.theatre))
		return false
	end

	if state.sortie ~= env.getValueDictByKey(env.mission.sortie) then
		Logger:warn(string.format("isStateValid(); wrong sortie; "..
			"state: '%s'; mission: '%s'", state.sortie,
			env.getValueDictByKey(env.mission.sortie)))
		return false
	end

	return true
end

--[[
--  Theater class
--    base class that reads in all region and template information
--    and provides a base interface for manipulating data at a theater
--    level.
--]]
local Theater = class("Theater", Observable, Systems)
function Theater:__init()
	Observable.__init(self, Logger)
	self.savestatefreq = 7*60 -- seconds
	self.cmdmindelay   = 2
	self.uicmddelay    = self.cmdmindelay
	self:setTimings(settings.schedfreq, settings.tgtfps,
		settings.percentTimeAllowed)
	self.statef    = false
	self.qtimer    = require("dct.libs.Timer")(self.quanta, os.clock)
	self.cmdq      = containers.PriorityQueue()
	self.cmdrs     = {}
	self.startdate = os.date("!*t")
	self.namecntr  = 1000

	Systems.__init(self)
	for _, val in pairs(coalition.side) do
		self.cmdrs[val] = Commander(self, val)
	end

	self:queueCommand(5, Command(self.__clsname..".delayedInit",
		self.delayedInit, self))
	self:queueCommand(100, Command(self.__clsname..".export",
		self.export, self))
	self.singleton = nil
	self.playerRequest = nil
end

function Theater.singleton()
	if _G.dct.theater ~= nil then
		return _G.dct.theater
	end
	_G.dct.theater = Theater()
	return _G.dct.theater
end

function Theater:setTimings(cmdfreq, tgtfps, percent)
	self._cmdqfreq    = cmdfreq
	self._targetfps   = tgtfps
	self._tallowed    = percent
	self.cmdqdelay    = 1/self._cmdqfreq
	self.quanta       = self._tallowed * ((1 / self._targetfps) *
		self.cmdqdelay)
end

function Theater:loadOrGenerate()
	local statetbl
	local statefile = io.open(settings.statepath)

	if statefile ~= nil then
		statetbl = json:decode(statefile:read("*all"))
		statefile:close()
	end

	if isStateValid(statetbl) then
		Logger:info("restoring saved state")
		self.statef = true
		self.startdate = statetbl.startdate
		self.namecntr  = statetbl.namecntr
		self:unmarshal(statetbl.systems)
	else
		Logger:info("generating new theater")
		self:_runsys("generate", self)
	end
end

function Theater:delayedInit()
	self:loadOrGenerate()
	self:_runsys("postinit", self)

	-- TODO: temporary, spawn all generated assets
	-- eventually we will want to spawn only a set of assets
	for _, asset in self:getAssetMgr():iterate() do
		if asset.type ~= enum.assetType.PLAYERGROUP and
		   not asset:isSpawned() then
			asset:spawn()
		end
	end
end

local airbase_cats = {
	[Airbase.Category.HELIPAD] = true,
	[Airbase.Category.SHIP]    = true,
}

local function handlefarps(airbase, event)
	if event.place ~= nil or
	   airbase:getCategory() ~= Object.Category.BASE or
	   airbase_cats[airbase:getDesc().category] == nil then
		return
	end
	event.place = airbase
end

local airbase_events = {
	[world.event.S_EVENT_TAKEOFF] = true,
	[world.event.S_EVENT_LAND]    = true,
}

-- some airbases (invisible FARPs seems to be the only one currently)
-- do not trigger takeoff and land events, this function figured out
-- if there is a FARP near the event and if so uses that FARP as the
-- place for the event.
local function fixup_airbase(event)
	if airbase_events[event.id] == nil or event.place ~= nil then
		return
	end
	local vol = {
		id = world.VolumeType.SPHERE,
		params = {
			point  = event.initiator:getPoint(),
			radius = 700, -- meters
		},
	}
	world.searchObjects(Object.Category.BASE, vol, handlefarps, event)
end

-- ignore unnecessary events from DCS
local irrelevants = {
	[world.event.S_EVENT_BASE_CAPTURED]                = true,
	[world.event.S_EVENT_TOOK_CONTROL]                 = true,
	[world.event.S_EVENT_HUMAN_FAILURE]                = true,
	[world.event.S_EVENT_DETAILED_FAILURE]             = true,
	[world.event.S_EVENT_PLAYER_ENTER_UNIT]            = true,
	[world.event.S_EVENT_PLAYER_LEAVE_UNIT]            = true,
	[world.event.S_EVENT_PLAYER_COMMENT]               = true,
	[world.event.S_EVENT_SCORE]                        = true,
	[world.event.S_EVENT_DISCARD_CHAIR_AFTER_EJECTION] = true,
	[world.event.S_EVENT_WEAPON_ADD]                   = true,
	[world.event.S_EVENT_TRIGGER_ZONE]                 = true,
	[world.event.S_EVENT_LANDING_QUALITY_MARK]         = true,
	[world.event.S_EVENT_BDA]                          = true,
}

-- DCS looks for this function in any table we register with the world
-- event handler
function Theater:onEvent(event)
	if irrelevants[event.id] ~= nil then
		return
	end
	fixup_airbase(event)
	self:notify(event)
	if event.id == world.event.S_EVENT_MISSION_END then
		-- Only delete the state if there is an end mission event
		-- and tickets are complete, otherwise when a server is
		-- shutdown gracefully the state will be deleted.
		if self:getTickets():isComplete() then
			local ok, err = os.remove(settings.statepath)
			if not ok then
				Logger:error("unable to remove statefile; "..err)
			end
		end
	end
end

function Theater:export(_)
	local statefile
	local msg

	statefile, msg = io.open(settings.statepath, "w+")

	if statefile == nil then
		Logger:error("export(); unable to open '"..
			settings.statepath.."'; msg: "..tostring(msg))
		return self.savestatefreq
	end

	local exporttbl = {
		["version"]  = STATE_VERSION,
		["complete"] = self:getTickets():isComplete(),
		["date"]     = os.date("*t", dctutils.zulutime(timer.getAbsTime())),
		["theater"]  = env.mission.theatre,
		["sortie"]   = env.getValueDictByKey(env.mission.sortie),
		["systems"]  = self:marshal(),
		["startdate"] = self.startdate,
		["namecntr"]  = self.namecntr,
	}

	statefile:write(json:encode(exporttbl))
	statefile:flush()
	statefile:close()
	return self.savestatefreq
end

function Theater:getRegionMgr()
	return self:getSystem("dct.templates.RegionManager")
end

function Theater:getAssetMgr()
	return self:getSystem("dct.assets.AssetManager")
end

function Theater:getCommander(side)
	return self.cmdrs[side]
end

function Theater:getcntr()
	self.namecntr = self.namecntr + 1
	return self.namecntr
end

function Theater:getTickets()
	return self:getSystem("dct.systems.tickets")
end

function Theater.playerRequest(data)
	local self = Theater.singleton()
	if data == nil then
		Logger:error("playerRequest(); value error: data must be "..
			"provided; "..debug.traceback())
		return
	end

	Logger:debug("playerRequest(); Received player request: "..
		json:encode_pretty(data))

	local playerasset = self:getAssetMgr():getAsset(data.name)

	if playerasset.cmdpending == true then
		Logger:debug("playerRequest(); request pending, ignoring")
		trigger.action.outTextForGroup(playerasset.groupId,
			"F10 request already pending, please wait.", 20, true)
		return
	end

	local cmd = uicmds[data.type](self, data)
	self:queueCommand(self.uicmddelay, cmd)
	playerasset.cmdpending = true
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
	if delay < self.cmdmindelay then
		Logger:warn(string.format("queueCommand(); delay(%2.2f) less than "..
			"schedular minimum(%2.2f), setting to schedular minumum",
			delay, self.cmdmindelay))
		delay = self.cmdmindelay
	end
	self.cmdq:push(timer.getTime() + delay, cmd)
	Logger:debug(string.format("queueCommand(); cmd(%s) cmdq size: %d",
		cmd.name, self.cmdq:size()))
end

function Theater:exec(time)
	self.qtimer:reset()
	local cmdctr = 0
	while not self.cmdq:empty() do
		local _, prio = self.cmdq:peek()
		if time < prio then
			break
		end

		local cmd = self.cmdq:pop()
		local ok, requeue = pcall(cmd.execute, cmd, time)
		if ok then
			if requeue ~= nil and type(requeue) == "number" then
				self:queueCommand(requeue, cmd)
			end
		else
			Logger:error("protected call - "..tostring(requeue))
		end
		cmdctr = cmdctr + 1
		self.qtimer:update()
		if self.qtimer:expired() then
			Logger:debug(
				string.format("exec(); quanta reached, quanta: %5.2fms",
					self.quanta*1000))
			break
		end
	end
	self.qtimer:update()
	Logger:debug(string.format("exec(); time taken: %4.2fms;"..
		" cmds executed: %d", self.qtimer.timeout*1000, cmdctr))
	return time + self.cmdqdelay
end

return Theater
