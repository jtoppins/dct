--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Defines the Theater class.
--]]

require("os")
require("io")
require("lfs")
local utils       = require("libs.utils")
local containers  = require("libs.containers")
local json        = require("libs.json")
local enum        = require("dct.enum")
local dctutils    = require("dct.utils")
local Observable  = require("dct.libs.Observable")
local uicmds      = require("dct.ui.cmds")
local STM         = require("dct.templates.STM")
local Template    = require("dct.templates.Template")
local Region      = require("dct.templates.Region")
local AssetManager= require("dct.assets.AssetManager")
local Commander   = require("dct.ai.Commander")
local Command     = require("dct.Command")
local Logger      = dct.Logger.getByName("Theater")
local settings    = _G.dct.settings.server

local STATE_VERSION = "1"

local function isPlayerGroup(grp, _, _)
	local slotcnt = 0
	for _, unit in ipairs(grp.units) do
		if unit.skill == "Client" then
			slotcnt = slotcnt + 1
		end
	end
	if slotcnt > 0 then
		if slotcnt > 1 then
			Logger:warn(string.format("DCT requires 1 slot groups. Group "..
				"'%s' of type a/c (%s) has more than one player slot.",
				grp.name, grp.units[1].type))
		end
		return true
	end
	return false
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
local Theater = require("libs.namedclass")("Theater", Observable)
function Theater:__init()
	Observable.__init(self, Logger)
	self.savestatefreq = 7*60 -- seconds
	self.cmdmindelay   = 2
	self.uicmddelay    = self.cmdmindelay
	self:setTimings(settings.schedfreq, settings.tgtfps,
		settings.percentTimeAllowed)
	self.statef    = false
	self.regions   = {}
	self.cmdq      = containers.PriorityQueue()
	self.ctime     = timer.getTime()
	self.ltime     = 0
	self.assetmgr  = AssetManager(self)
	self.cmdrs     = {}
	self._systems  = {}
	self.startdate = os.date("!*t")
	self.namecntr  = 1000

	for _, val in pairs(coalition.side) do
		self.cmdrs[val] = Commander(self, val)
	end

	self:loadSystems()
	self:loadRegions()
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

function Theater:getSystem(path)
	return self._systems[path]
end

function Theater:addSystem(path)
	if self._systems[path] ~= nil then
		return
	end
	self._systems[path] = require(path)(self)
	Logger:info("init "..path)
end

function Theater:postinitSystems()
	for _, sys in pairs(self._systems) do
		if type(sys.initpost) == "function" then
			sys:initpost(self)
		end
	end
end

function Theater:loadSystems()
	local systems = {
		"dct.ui.scratchpad",
		"dct.systems.tickets",
		"dct.systems.bldgPersist",
		"dct.systems.weaponstracking",
		"dct.systems.blasteffects",
	}

	for _, syspath in pairs(systems) do
		self:addSystem(syspath)
	end
end

function Theater:loadRegions()
	for filename in lfs.dir(settings.theaterpath) do
		if filename ~= "." and filename ~= ".." and
			filename ~= ".git" and filename ~= "settings" then
			local fpath = settings.theaterpath..utils.sep..filename
			local fattr = lfs.attributes(fpath)
			if fattr.mode == "directory" then
				local r = Region(fpath)
				assert(self.regions[r.name] == nil, "duplicate regions " ..
					"defined for theater: " .. settings.theaterpath)
				self.regions[r.name] = r
			end
		end
	end
end

function Theater:loadPlayerSlots()
	local cnt = 0
	for _, coa_data in pairs(env.mission.coalition) do
		local grps = STM.processCoalition(coa_data,
			env.getValueDictByKey,
			isPlayerGroup,
			nil)
		for _, grp in ipairs(grps) do
			local side = coalition.getCountryCoalition(grp.countryid)
			local asset =
			self:getAssetMgr():factory(enum.assetType.PLAYERGROUP)(Template({
				["objtype"]   = "playergroup",
				["name"]      = grp.data.name,
				["regionname"]= "theater",
				["regionprio"]= 1000,
				["coalition"] = side,
				["cost"]      = self:getTickets():getPlayerCost(side),
				["desc"]      = "Player group",
				["tpldata"]   = grp,
			}))
			self:getAssetMgr():add(asset)
			cnt = cnt + 1
		end
	end
	Logger:info(string.format("loadPlayerSlots(); found %d slots", cnt))
end

function Theater:loadOrGenerate()
	local statefile = io.open(settings.statepath)

	if statefile ~= nil then
		self.statetbl = json:decode(statefile:read("*all"))
		statefile:close()
	end

	if isStateValid(self.statetbl) then
		Logger:info("restoring saved state")
		self.statef = true
		self.startdate = self.statetbl.startdate
		self.namecntr  = self.statetbl.namecntr
		for name, data in pairs(self.statetbl.systems) do
			local sys = self:getSystem(name)
			if sys ~= nil and type(sys.unmarshal) == "function" then
				sys:unmarshal(data)
			end
		end
		self:getAssetMgr():unmarshal(self.statetbl.assetmgr)
	else
		Logger:info("generating new theater")
		for _, r in pairs(self.regions) do
			r:generate(self.assetmgr)
		end
		-- TODO: temperary, spawn all generated assets
		-- eventually we will want to spawn only a set of assets
		local assetnames = self.assetmgr:filterAssets(function()
			return true
		end)
		for name, _ in pairs(assetnames) do
			local asset = self.assetmgr:getAsset(name)
			if asset.type ~= enum.assetType.PLAYERGROUP and
			   not asset:isSpawned() then
				asset:spawn()
			end
		end
	end
	self.statetbl = nil
end

function Theater:delayedInit()
	self:loadPlayerSlots()
	self:loadOrGenerate()
	self:postinitSystems()
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
		["systems"]  = {},
		["assetmgr"] = self:getAssetMgr():marshal(),
		["startdate"] = self.startdate,
		["namecntr"]  = self.namecntr,
	}
	for name, sys in pairs(self._systems) do
		if type(sys.marshal) == "function" then
			exporttbl.systems[name] = sys:marshal()
		end
	end

	statefile:write(json:encode(exporttbl))
	statefile:flush()
	statefile:close()
	return self.savestatefreq
end

function Theater:getAssetMgr()
	return self.assetmgr
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
	self.cmdq:push(self.ctime + delay, cmd)
	Logger:debug(string.format("queueCommand(); cmd(%s) cmdq size: %d",
		cmd.name, self.cmdq:size()))
end

function Theater:_exec(time)
	self.ltime = self.ctime
	self.ctime = time

	local tstart = os.clock()
	local tdiff = 0
	local cmdctr = 0
	while not self.cmdq:empty() do
		local _, prio = self.cmdq:peek()
		if time < prio then
			break
		end

		local cmd = self.cmdq:pop()
		local requeue = cmd:execute(time)
		if requeue ~= nil and type(requeue) == "number" then
			self:queueCommand(requeue, cmd)
		end
		cmdctr = cmdctr + 1

		tdiff = os.clock() - tstart
		if tdiff >= self.quanta then
			Logger:debug(
				string.format("exec(); quanta reached, quanta: %5.2fms",
					self.quanta*1000))
			break
		end
	end
	Logger:debug(string.format("exec(); time taken: %4.2fms;"..
		" cmds executed: %d", tdiff*1000, cmdctr))
end

function Theater:exec(time)
	local errhandler = function(err)
		Logger:error("protected call - "..tostring(err).."\n"..
			debug.traceback())
	end
	local pcallfunc = function()
		self:_exec(time)
	end

	xpcall(pcallfunc, errhandler)
	return time + self.cmdqdelay
end

return Theater
