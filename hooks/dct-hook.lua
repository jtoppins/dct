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

local dctflag           = "DCTFLAG"
local facility          = "[DCT-HOOKS]"
local DEBUG_SCRIPT      = false
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

local settingsf
ok, settingsf = pcall(require, "dct.settings.server")
if not ok or type(settingsf) ~= "function" then
	log.write(facility, log.ERROR,
		string.format("unable to require server settings: %s", settingsf))
	return
end

local settings
ok, settings = pcall(settingsf, {})
if not ok then
	log.write(facility, log.ERROR,
		string.format("unable to load server settings: %s", settings))
	return
end

local dctenum
ok, dctenum = pcall(require, "dct.libs.kickinfo")
if not ok then
	log.write(facility, log.ERROR,
		string.format("unable to require dct.enum: %s", dctenum))
	return
end

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

local function get_player_info(id)
	local player = net.get_player_info(id)
	if player and player.slot == '' then
		player.slot = nil
	end
	return player
end

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

local function rpc_send_msg_to_all(msg, dtime, clear)
	local cmd = [[
		trigger.action.outText("]]..tostring(msg)..
			[[", ]]..tostring(dtime)..[[, ]]..tostring(clear)..[[);
		return "true"
	]]
	return cmd
end

local function rpc_slot_enabled(grpname)
	local cmd = [[
		local name = "]]..tostring(grpname)..[["
		local en = trigger.misc.getUserFlag(name)
		local kick = trigger.misc.getUserFlag(name.."_kick")
		local result = (en == 1 and kick ~= 1)
		env.info(string.format(
			"DCT slot(%s) check - slot: %s; kick: %s; result: %s",
			tostring(name), tostring(en), tostring(kick),
			tostring(result)), false)
		return tostring(result)
	]]
	return cmd
end

local function rpc_get_flag(flagname)
	local cmd = [[
		local flag = trigger.misc.getUserFlag("]]..
			tostring(flagname)..[[") or 0
		return tostring(flag)
	]]
	return cmd
end

local function rpc_set_flag(flagname, value)
	local cmd = [[
		trigger.action.setUserFlag("]]..tostring(flagname)..
			[[",]]..tostring(value)..[[);
		return "true"
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
	if valtype == "number" then
		val = tonumber(status)
	elseif valtype == "boolean" then
		local t = {
			["true"] = true,
			["false"] = false,
		}
		val = t[string.lower(status)]
	elseif valtype == "string" then
		val = status
	elseif valtype == "table" then
		local rc, result = pcall(net.json2lua, status)
		if not rc then
			log.write(facility, log.ERROR,
				"rpc json decode failed: "..tostring(result))
			log.write(facility, log.DEBUG,
				"rpc json decode input: "..tostring(status))
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

	local flag = do_rpc("server", rpc_slot_enabled(slot.groupName),
		"boolean")
	log.write(facility, log.DEBUG,
		string.format("slot(%s) enabled: %s",
			slot.groupName, tostring(flag)))
	if flag == nil then
		flag = true
	end
	return flag
end

local DCTHooks = class()
function DCTHooks:__init()
	local errmsg
	self.serverid   = settings.server.dctid
	self.hostname   = settings.server.statServerHostname
	self.ip, errmsg = socket.dns.toip(self.hostname)
	if self.ip == nil then
		log.write(facility, log.ALERT,
			"invalid hostname, must be an IP address or hostname;"..
			" "..tostring(errmsg))
	end
	self.port       = settings.server.statServerPort
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
	self.mission_period = settings.server.period
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

	self.players  = {} -- indexed by player id
	self.slots    = {} -- indexed by unitId
	self.groups   = {} -- maps group names to slot ids, indexed by
	                   -- slot.groupName - a 1-to-many relation
	self.blockspecialslots = (next(settings.server.whitelists) ~= nil)
	self.whitelists = settings.server.whitelists
	self.slot2player = {}  -- indexed by slotid (player.slot / slot.unitId)
	                       -- pointing to player id; [unitId] = playerid
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
	self.groups = {}

	for coa, _ in pairs(DCS.getAvailableCoalitions()) do
		for _, slot in ipairs(DCS.getAvailableSlots(coa)) do
			if self.slots[slot.unitId] then
				log.write(facility, log.ERROR,
					"multiple units with unitId: "..tostring(slot.unitId))
			end
			self.slots[slot.unitId] = slot
			if slot.groupName then
				if self.groups[slot.groupName] == nil then
					self.groups[slot.groupName] = {}
				end
				self.groups[slot.groupName][slot.unitId] = true
			end
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
	local dctenabled = do_rpc("server", rpc_get_flag(dctflag), "number")
	if not DCS.isServer() or dctenabled == 0 then
		log.write(facility, log.DEBUG,
			string.format("not DCT enabled; server(%s), enabled(%s)",
				tostring(DCS.isServer()), tostring(dctenabled)))
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
	self.slotkicktimer = 0
	self.mission_start_mt = DCS.getModelTime()
	self.mission_start_rt = DCS.getRealTime()
	log.write(facility, log.DEBUG, string.format("mission_time: %f, %s",
		tostring(self.mission_time), os.date("%F %R", self.mission_time)))
	log.write(facility, log.DEBUG, "mission_start_mt: "..
		tostring(self.mission_start_mt))
	log.write(facility, log.DEBUG, "mission_start_rt: "..
		tostring(self.mission_start_rt))
	log.write(facility, log.DEBUG, "mission_period: "..
		tostring(self.mission_period))
	for _, data in pairs(self.restartwarnings) do
		if settings.server.period < 0 then
			data.sent = true
		else
			data.sent = false
		end
	end
	self.info.mission.dirty = true
end

function DCTHooks:onPlayerConnect(id)
	log.write(facility, log.DEBUG, "player connect, id: "..tostring(id))
	local player = get_player_info(id)
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
	-- clean up tables from last cached player data
	if self.players[id] and self.players[id].slot then
		self.slot2player[self.players[id].slot] = nil
	end
	-- delete player entry
	self.players[id] = nil
	self.info.players.dirty = true
end

function DCTHooks:onPlayerChangeSlot(id)
	log.write(facility, log.DEBUG, "player change slot, id: "..tostring(id))
	local prev_player = self.players[id]
	local new_player  = get_player_info(id)
	if prev_player and prev_player.slot then
		self.slot2player[prev_player.slot] = nil
	end
	if new_player and new_player.slot then
		self.slot2player[new_player.slot] = id
	end
	self.players[id] = new_player
	self.info.players.dirty = true
end

function DCTHooks:isEnabled()
	return self.started
end

-- Returns: true - allows slot change, false - denies change
function DCTHooks:onPlayerTryChangeSlot(playerid, _, slotid)
	local pass = nil
	if not self:isEnabled() then
		return pass
	end

	local slot   = self.slots[slotid]
	local player = self.players[playerid]
	local rc = false
	local reason

	if slot == nil then
		return pass
	end

	if special_unit_role_types[slot.role] ~= nil then
		reason = "not allowed in special role slot"
		for _, list in ipairs({slot.role, "admin"}) do
			if self.whitelists[list] ~= nil and
			   self.whitelists[list][player.ucid] ~= nil then
			   rc = true
			   break
		   end
		end

		-- do not block special slots if there are no whitelists defined
		if self.blockspecialslots == false then
			rc = true
		end
	else
		reason = "plane slot is disabled"
		rc = isSlotEnabled(slot)
	end

	if rc == false then
		net.send_chat_to(
			string.format("***slot(%s) permission denied, choose another***",
				tostring(slot.unitId)),
			playerid, net.get_server_id())
		net.send_chat_to(string.format("  reason: %s", reason),
			playerid, net.get_server_id())
		return false
	end
	return pass
end

function DCTHooks:sendheartbeat()
	local info = {
		["time"] = os.date("*t", self.mission_time +
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

function DCTHooks:kickPlayersInGroup(grpname, slots)
	local kick = do_rpc("server", rpc_get_flag(grpname.."_kick"), "number")
	if kick ~= dctenum.kickCode.NOKICK then
		for slotid, _ in pairs(slots) do
			local pid = self.slot2player[slotid]
			if pid then
				net.force_player_slot(pid, 0, '')
				net.send_chat_to(string.format(
						"*** you have been kicked from slot(%s) ***\n"..
						"  reason: %s", slotid, dctenum.kickReason[kick]),
					pid, net.get_server_id())
			end
		end
	end
	do_rpc("server",
		rpc_set_flag(grpname.."_kick", dctenum.kickCode.NOKICK),
		"number")
end

function DCTHooks:onSimulationFrame()
	if not self:isEnabled() then
		return
	end

	local realtime = DCS.getRealTime()
	for t, info in pairs(self.info) do
		if info.dirty and realtime - info.lastsent > info.period then
			log.write(facility, log.DEBUG, "time check - starting")
			self.info[t].lastsent = realtime
			self["send"..t](self)
			log.write(facility, log.DEBUG,
				string.format("Model time is: %f", DCS.getModelTime()))
			log.write(facility, log.DEBUG, "time check - complete")
			break
		end
	end

	local modeltime = os.clock()
	if math.abs(modeltime - self.slotkicktimer) > self.slotkickperiod then
		log.write(facility, log.DEBUG, "kick check - starting")
		self.slotkicktimer = modeltime
		for grpname, slots in pairs(self.groups) do
			self:kickPlayersInGroup(grpname, slots)
		end
		log.write(facility, log.DEBUG, "kick check - complete")
	end
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
