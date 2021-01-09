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
local uiscratchpad= require("dct.ui.scratchpad")
local bldgPersist = require("dct.systems.bldgPersist")
local STM         = require("dct.templates.STM")
local Template    = require("dct.templates.Template")
local Region      = require("dct.templates.Region")
local AssetManager= require("dct.assets.AssetManager")
local Commander   = require("dct.ai.Commander")
local Command     = require("dct.Command")
local Tickets     = require("dct.systems.tickets")
local Logger      = dct.Logger.getByName("Theater")
local settings    = _G.dct.settings.server

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
	Observable.__init(self)
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
	self.tickets   = Tickets(self,
		settings.theaterpath..utils.sep.."theater.goals")
	self.cmdrs     = {}
	self.scratchpad= {}
	self.startdate = os.date("!*t")
	self.bldgPersist= bldgPersist(self)
	self.namecntr  = 1000

	for _, val in pairs(coalition.side) do
		self.cmdrs[val] = Commander(self, val)
	end

	self:loadRegions()
	self:queueCommand(5, Command("delayedInit", self.delayedInit, self))
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
				["coalition"] = side,
				["cost"]      = self.tickets:getPlayerCost(side),
				["desc"]      = "Player group",
				["tpldata"]   = grp,
			}), {["name"] = "theater", ["priority"] = 1000,})
			self:getAssetMgr():add(asset)
			asset:spawn()
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
		self:getAssetMgr():unmarshal(self.statetbl.assetmgr)
		self.tickets:unmarshal(self.statetbl.tickets)
		self.bldgPersist:restoreState(self.statetbl.bldgDest)
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
			if not asset:isSpawned() then
				asset:spawn()
			end
		end
	end
	self.statetbl = nil
end

function Theater:delayedInit()
	uiscratchpad(self)
	self:loadPlayerSlots()
	self:loadOrGenerate()
	self:queueCommand(100, Command("Theater.export", self.export, self))
end

-- DCS looks for this function in any table we register with the world
-- event handler
function Theater:onEvent(event)
	self:notify(event)
	if event.id == world.event.S_EVENT_MISSION_END then
		local ok, err = os.remove(settings.statepath)
		if not ok then
			Logger:error("unable to remove statepath; "..err)
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
		["complete"] = self.tickets:isComplete(),
		["date"]     = os.date("!*t", dctutils.zulutime(timer.getAbsTime())),
		["theater"]  = env.mission.theatre,
		["sortie"]   = env.getValueDictByKey(env.mission.sortie),
		["tickets"]  = self.tickets:marshal(),
		["assetmgr"] = self:getAssetMgr():marshal(),
		["bldgDest"]  = self.bldgPersist:returnList(),
		["startdate"] = self.startdate,
		["namecntr"]  = self.namecntr,
	}

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
	return self.tickets
end

function Theater:playerRequest(data)
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
	Logger:debug("queueCommand(); cmdq size: "..self.cmdq:size())
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
			Logger:debug("exec(); quanta reached, quanta: "..
				tostring(self.quanta))
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
