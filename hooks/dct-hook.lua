--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- DCT hook script
--
-- This script is intended to be put into the hooks directory;
--     <dcs-saved-games>/Scripts/Hooks/
--
-- It allows any DCS server to export data via a UDP socket sending
-- information according to a standard data protocol, discussed in this
-- script. The protocol is meant to standardize on a data format for
-- exporting data from a DCS server such that a receiver, for example
-- a discord bot, can consume the data and do with the data whatever the
-- receiver needs.
--
-- In addition this script implements slot blocking system equivalent
-- to Simple Slot Blocker's version of slot blocking.
--]]

-- luacheck: read_globals log DCS net

local facility          = "[DCT-HOOKS]"
local DEBUG_SCRIPT      = false
local RECEIVER_HOSTNAME = "localhost"
local RECEIVER_PORT     = 8095
local SERVER_ID         = net.get_player_info(net.get_server_id(), 'ucid')
local DEFAULT_PERIOD    = 21600 -- 6 hours; set to negative number to disable
local loglevel = log.ALERT + log.ERROR + log.WARNING + log.INFO
if DEBUG_SCRIPT then
	loglevel = loglevel + log.DEBUG + log.TRACE
end
log.set_output('dct-hooks', facility, loglevel,	log.FULL)

-- Add LuaSocket to the environment
package.path  = package.path.. ";.\\LuaSocket\\?.lua"
package.cpath = package.cpath..";.\\LuaSocket\\?.dll"

-- Determine if DCT is installed and amend environment as appropriate
local modpath = lfs.writedir().."Mods\\tech\\DCT"
if lfs.attributes(modpath) == nil then
	log.write(facility, log.WARNING, "DCT not installed, skipping...")
	return
end
package.path = package.path..";"..modpath.."\\lua\\?.lua"

local ok
local socket
local class
local settings = { ["server"] = {},}

require("os")
require("math")
ok, socket = pcall(require, "socket")
if not ok then
	log.write(facility, log.ERROR,
		string.format("unable to load socket library: %s", socket))
	return
end

ok, class = pcall(require, "libs.class")
if not ok then
	log.write(facility, log.ERROR,
		string.format("unable to load class library: %s", class))
	return
end

--[[
-- TODO: uncomment this once DCT supports pulling in settings for only the
-- server config. This code will need to be seperated from other parts
-- of DCT because of the dependency on the mission environment.
local settingsf
ok, settingsf = pcall(require, "dct.settings")
if not ok then
	log.write(facility, log.ERROR,
		string.format("unable to load settings library: %s", settingsf))
	return
end
settings = settingsf()
--]]

local PROTOCOL_VERSION = 1

--[[
-- This defines the message types that will be sent or received by the DCS
-- server. The presentation formation is JSON with an application format
-- of:
--    msg = {
--       "header" = "DCSEXPORT",
--       "id"     = <serverid>, -- a unique server ID to allow the receiver
--                              -- to process data from more than one server
--       "ver"    = <version-number>,
--       "type"   = <msgtype>,
--       "data"   = <message type specific format>,
--    }
--
-- Messages may be summarized together by using a JSON array as the outer
-- most container.
--]]
local msgtypes = {
	HEARTBEAT       = 1, -- lets the receiver know the server is still up,
	                     --    contains: current mission time, time left
						 --    until restart
	MISSIONINFO     = 2, -- mission information including theater, sortie
	                     --    name, and general description (truncated to
						 --    30000 characters)
	PLAYERINFOSTART = 3, -- start of player info; data = { sequence#,
	                     --     eom(T/F), players_table }
	PLAYERINFOCONT  = 4, -- continuation of player info; data = { seq#,
	                     --     eom(T/F), players_table }
	SLOTINFOSTART   = 5, -- detailed player slot info, same format as player
	                     --     info
	SLOTINFOCONT    = 6,
	STATE           = 7, -- states: START = 1, STOP = 2, PAUSE = 3,
}

local serverstates = {
	["START"] = 1,
	["STOP"]  = 2,
	["PAUSE"] = 3,
}

local special_unit_role_types = {
	["forward_observer"]    = true,
	["instructor"]          = true,
	["artillery_commander"] = true,
	["observer"]            = true,
}

-- returns a JSON string conforming to the application format
local function build_message(serverid, msgtype, value)
	local msg = {
		["header"] = "DCSEXPORT",
		["id"]     = serverid,
		["ver"]    = PROTOCOL_VERSION,
		["type"]   = msgtype,
		["data"]   = value,
	}
	local j = net.lua2json(msg)
	log.write(facility, log.DEBUG, "build_message: "..j)
	return j
end

local DCTHooks = class()
function DCTHooks:__init()
	local errmsg
	self.serverid   = settings.server.dctid or SERVER_ID
	self.hostname   = settings.server.statServerHostname or RECEIVER_HOSTNAME
	self.ip, errmsg = socket.dns.toip(self.hostname)
	assert(self.ip, "invalid hostname, must be an IP address or hostname;"..
		" "..tostring(errmsg))
	self.port       = settings.server.statServerPort or RECEIVER_PORT
	self.started    = false
	self.info       = {
		["heartbeat"] = {
			["dirty"]    = true,
			["lastsent"] = 0,
			["period"]   = 60,
		},
		["mission"]   = {
			["dirty"]    = true,
			["lastsent"] = 0,
			["period"]   = 50,
		},
		["players"]   = {
			["dirty"]    = true,
			["lastsent"] = 0,
			["period"]   = 120,
		},
	}
	self.slotkicktimer = 0
	self.slotkickperiod = 5
	self.mission_start_mt = 0
	self.mission_start_rt = 0
	self.mission_period = settings.server.period or DEFAULT_PERIOD
	self.mission_time = 0
	self.restartwarnings = {
		[60*60] = {
			["message"] = "server will restart in 1 hour",
			["sent"]    = false,
		},
		[60*30] = {
			["message"] = "server will restart in 30 minutes",
			["sent"]    = false,
		},
		[60*15] = {
			["message"] = "server will restart in 15 minutes",
			["sent"]    = false,
		},
		[60*5] = {
			["message"] = "server will restart in 5 minutes",
			["sent"]    = false,
		},
	}

	self.players  = {}
	self.slots    = {}
	self.whitelists = {} -- various lists of UCIDs to allow players for
	                     -- various slot types
	self.whitelists.admin = settings.server.admins or {}
end

function DCTHooks:start()
	self.socket = assert(socket.udp())
	log.write(facility, log.DEBUG,
		string.format("binding UDP socket to peer; %s:%d",
			self.ip, self.port))
	self.socket:setpeername(self.ip, self.port)
	self.started = true
end

function DCTHooks:stop()
	self.socket:close()
	self.socket = nil
	self.started = false
end

-- load the mission's available player slots
function DCTHooks:getslots()
	self.slots = {}

	for coa, _ in pairs(DCS.getAvailableCoalitions()) do
		for _, slot in ipairs(DCS.getAvailableSlots(coa)) do
			if self.slots[slot.unitId] then
				log.write(facility, log.ERROR,
					"multiple units with unitId: "..tostring(slot.unitId))
			end
			self.slots[slot.unitId] = slot
		end
	end
end

function DCTHooks:onSimulationStart()
	log.write(facility, log.DEBUG, "onSimulationStart")
end

function DCTHooks:onSimulationStop()
	log.write(facility, log.DEBUG, "onSimulationStop")
	if not self.started then
		return
	end
	local msg = build_message(self.serverid, msgtypes.STATE,
		serverstates.STOP)
	self.socket:send(msg)
	self:stop()
end

function DCTHooks:onSimulationPause()
	log.write(facility, log.DEBUG, "onSimulationPause")
	if not self.started then
		return
	end
	local msg = build_message(self.serverid, msgtypes.STATE,
		serverstates.PAUSE)
	self.socket:send(msg)
	self:stop()
end

function DCTHooks:onSimulationResume()
	log.write(facility, log.DEBUG, "onSimulationResume")
	if not DCS.isServer() then
		return
	end
	self:start()
	local msg = build_message(self.serverid, msgtypes.STATE,
		serverstates.START)
	self.socket:send(msg)
end

function DCTHooks:onMissionLoadEnd()
	log.write(facility, log.DEBUG, "onMissionLoadEnd")
	local mission = DCS.getCurrentMission().mission
	self.mission_time = os.time({
		["year"]  = mission.date.Year,
		["month"] = mission.date.Month,
		["day"]   = mission.date.Day,
		["hour"]  = 0,
		["min"]   = 0,
		["sec"]   = 0,
		["isdst"] = false,
	}) + mission.start_time
	self.mission_start_mt = DCS.getModelTime()
	self.mission_start_rt = DCS.getRealTime()
	log.write(facility, log.DEBUG, string.format("mission_time: %f, %s",
		tostring(self.mission_time), os.date("!%F %R", self.mission_time)))
	log.write(facility, log.DEBUG, "mission_start_mt: "..
		tostring(self.mission_start_mt))
	log.write(facility, log.DEBUG, "mission_start_rt: "..
		tostring(self.mission_start_rt))
	log.write(facility, log.DEBUG, "mission_period: "..
		tostring(self.mission_period))
	for _, data in pairs(self.restartwarnings) do
		data.sent = false
	end
	self.info.mission.dirty = true
end

function DCTHooks:onPlayerConnect(id)
	log.write(facility, log.DEBUG, "player connect, id: "..tostring(id))
	local player = net.get_player_info(id)
	if player.slot == '' then
		player.slot = nil
	end
	if self.players[id] ~= nil then
		log.write(facility, log.WARNING,
			string.format("player id(%s) already assigned, overwriting", id))
	end
	self.players[id] = player
	if player == nil then
		log.write(facility, log.WARNING,
			string.format("player id(%s) not found", id))
		return
	end
	self.info.players.dirty = true
end

function DCTHooks:onPlayerDisconnect(id, err_code)
	log.write(facility, log.DEBUG,
		string.format("player disconnect; id(%s), code(%s)",
			tostring(id), tostring(err_code)))
	local player = self.players[id]
	if player == nil then
		log.write(facility, log.WARNING,
			string.format(
				"received disconnect for non-existent player id(%s)", id))
		return
	end
	self.players[id] = nil
	self.info.players.dirty = true
end

function DCTHooks:onPlayerChangeSlot(id)
	log.write(facility, log.DEBUG, "player change slot, id: "..tostring(id))
	self.players[id] = net.get_player_info(id)
	self.info.players.dirty = true
end

local function rpc_send_msg_to_all(msg, dtime, clear)
	local cmd = [[
		trigger.action.outText("]]..tostring(msg)..
			[[", ]]..tostring(dtime)..[[, ]]..tostring(clear)..[[);
		return true;
	]]
	return cmd
end

local function rpc_get_flag(flagname)
	local cmd = [[
		return trigger.misc.getUserFlag("]]..tostring(flagname)..[[);
	]]
	return cmd
end

local function rpc_set_flag(flagname, value)
	local cmd = [[
		trigger.misc.setUserFlag("]]..tostring(flagname)..
			[[,]]..tostring(value)..[[);
		return true;
	]]
	return cmd
end

-- Returns: nil on error otherwise data in the requested type
local function do_rpc(ctx, cmd, valtype)
	local status, errmsg = net.dostring_in(ctx, cmd)
	if not status then
		log.write(facility, log.ERROR,
			string.format("rpc failed in context(%s): %s", ctx, errmsg))
		return
	end

	local val
	if valtype == "number" or valtype == "boolean" then
		val = tonumber(status)
	elseif valtype == "string" then
		val = status
	elseif valtype == "table" then
		local result
		status, result = pcall(net.json2lua, status)
		if not status then
			log.write(facility, log.ERROR,
				"rpc json decode failed: "..tostring(result))
			val = nil
		else
			val = result
		end
	else
		log.write(facility, log.ERROR,
			string.format("rpc unsupported type(%s)", valtype))
		val = nil
	end
	return val
end

local function isSlotEnabled(slot)
	if slot == nil then
		return false
	end

	local flag = do_rpc("server", rpc_get_flag(slot.groupName), "number")
	log.write(facility, log.DEBUG, "flag: "..tostring(flag))
	if flag == nil then
		flag = 0
	end
	return flag == 0
end

-- Returns: true - allows slot change, false - denies change
function DCTHooks:onPlayerTryChangeSlot(playerid, _, slotid)
	if not self.started then
		return
	end

	local slot   = self.slots[slotid]
	local player = self.players[playerid]
	local rc = false

	if special_unit_role_types[slot.role] ~= nil then
		for _, list in ipairs({slot.role, "admin"}) do
			if self.whitelists[list] ~= nil and
			   self.whitelists[list][player.ucid] ~= nil then
			   rc = true
			   break
		   end
		end
	else
		rc = isSlotEnabled(slot)
	end

	if rc == false then
		net.send_chat_to(
			string.format("***slot(%s) permission denied, choose another***",
				tostring(slot.unitId)),
			playerid, net.get_server_id())
	end
	return rc
end

function DCTHooks:sendheartbeat()
	local info = {
		["time"] = os.date("!*t", self.mission_time +
			DCS.getRealTime() - self.mission_start_rt),
		["time_left"] = (self.mission_start_mt + self.mission_period) -
			DCS.getModelTime()
	}
	local msg = build_message(self.serverid, msgtypes.HEARTBEAT, info)
	self.socket:send(msg)
	for t, data in pairs(self.restartwarnings) do
		if info.time_left < t and not data.sent then
			do_rpc('server', rpc_send_msg_to_all(data.message, 20, true),
				"boolean")
			data.sent = true
		end
	end
	if self.mission_period > 0 and info.time_left < 0 then
		net.load_next_mission()
	end
end

function DCTHooks:sendmission()
	local theater = DCS.getCurrentMission().mission.theatre or "unknown"
	local info = {
		["theater"]  = theater,
		["mission"]  = DCS.getMissionName(),
		["filename"] = DCS.getMissionFilename(),
		["description"] = string.sub(DCS.getMissionDescription(),1,30000),
		["restart_period"] = self.mission_period
	}
	local msg = build_message(self.serverid, msgtypes.MISSIONINFO, info)
	self.socket:send(msg)

	self:getslots()
	local seqnum = math.random(20,50000)
	info = {
		["seqnum"] = seqnum,
		["eom"]    = true,
		["slots"]  = self.slots
	}
	msg = build_message(self.serverid, msgtypes.SLOTINFOSTART, info)
	if string.len(msg) > 65000 then
		log.write(facility, log.WARNING, "message length exceeds 65000,"..
			" fragmentation needed, not sending slot info")
		return
	end
	self.socket:send(msg)
	self.info.mission.dirty = false
end

function DCTHooks:sendplayers()
	local seqnum = math.random(20,50000)
	local info = {
		["seqnum"] = seqnum,
		["eom"]    = true,
		["players"]  = self.players
	}
	local msg = build_message(self.serverid, msgtypes.PLAYERINFOSTART, info)
	if string.len(msg) > 65000 then
		log.write(facility, log.WARNING, "message length exceeds 65000,"..
			" fragmentation needed, not sending player info")
		return
	end
	self.socket:send(msg)
	self.info.players.dirty = false
end

function DCTHooks:kickPlayerFromSlot(p)
	if p.slot == nil or isSlotEnabled(self.slots[p.slot]) then
		return
	end
	net.force_player_slot(p.id, 0, '')
	net.send_chat_to("*** you have been removed from slot ***", p.id)
	do_rpc("server", rpc_set_flag(self.slots[p.slot].groupName, 0), "boolean")
end

function DCTHooks:onSimulationFrame()
	if not self.started then
		return
	end

	local realtime = DCS.getRealTime()
	for t, info in pairs(self.info) do
		if info.dirty and realtime - info.lastsent > info.period then
			self.info[t].lastsent = realtime
			self["send"..t](self)
			break
		end
	end

	local modeltime = DCS.getModelTime()
	if (modeltime - self.slotkicktimer) > self.slotkickperiod then
		self.slotkicktimer = modeltime
		for _, p in pairs(self.players) do
			self:kickPlayerFromSlot(p)
		end
	end

	-- This is where we could process commands received
	-- TODO: a better approach would be to do a select type thing between
	--   sending data
	--   receiving data
	--   and processing commands
	-- an even further simplification would be to turn this into a generic
	-- command processor like the Theater class. Then everything just
	-- becomes about processing commands from a command queue. The limitation
	-- with that is what happens when the server is paused?
end

local function dct_call_hook(hook, ...)
	local status, result = pcall(hook, ...)
	if not status then
		log.write(facility, log.ERROR,
			string.format("call to hook failed; %s\n%s",
				result, debug.traceback()))
		return
	end
	return result
end

local function dct_load(hooks)
	local handler = {}
	function handler.onSimulationStart()
		dct_call_hook(hooks.onSimulationStart, hooks)
	end
	function handler.onSimulationStop()
		dct_call_hook(hooks.onSimulationStop, hooks)
	end
	function handler.onSimulationPause()
		dct_call_hook(hooks.onSimulationPause, hooks)
	end
	function handler.onSimulationResume()
		dct_call_hook(hooks.onSimulationResume, hooks)
	end
	function handler.onMissionLoadEnd()
		dct_call_hook(hooks.onMissionLoadEnd, hooks)
	end
	function handler.onPlayerConnect(id)
		dct_call_hook(hooks.onPlayerConnect, hooks, id)
	end
	function handler.onPlayerDisconnect(id, err_code)
		dct_call_hook(hooks.onPlayerDisconnect, hooks, id, err_code)
	end
	function handler.onPlayerChangeSlot(id)
		dct_call_hook(hooks.onPlayerChangeSlot, hooks, id)
	end
	function handler.onPlayerTryChangeSlot(playerid, side, slotid)
		return dct_call_hook(hooks.onPlayerTryChangeSlot, hooks,
			playerid, side, slotid)
	end
	function handler.onSimulationFrame()
		dct_call_hook(hooks.onSimulationFrame, hooks)
	end
	DCS.setUserCallbacks(handler)
	log.write(facility, log.INFO, "Hooks Loaded")
end

local status, errmsg = pcall(dct_load, DCTHooks())
if not status then
	log.write(facility, log.ERROR, "Load Error: "..tostring(errmsg))
end

--[[
-- set the name of the server player
net.set_name(net.get_server_id(), "ServerBOT")
--]]
