-- SPDX-License-Identifier: LGPL-3.0

--- DCT hook script
---
--- This script is intended to be put into the hooks directory;
---     <dcs-saved-games>/Scripts/Hooks/
---
--- This script implements a slot blocking system equivalent to
--- Simple Slot Blocker's version of slot blocking.
--- @script dct-slotblock

-- luacheck: read_globals log DCS net
local facility = "[DCT-SLOTBLOCK]"
local sep      = package.config:sub(1,1)

-- Determine if DCT is installed and amend environment as appropriate
local modpath = lfs.writedir()..table.concat({"Mods", "Tech", "DCT"}, sep)
local pkgpath = table.concat({modpath, "lua", "?.lua"}, sep)
if lfs.attributes(modpath) == nil then
	log.write(facility, log.WARNING, "DCT not installed, skipping...")
	return
end
package.path = table.concat({package.path, pkgpath}, ";")

local ok
local class
local DCTHooks

require("os")
require("math")

ok, class = pcall(require, "libs.namedclass")
if not ok then
	log.write(facility, log.ERROR,
		string.format("unable to load class library: %s", class))
	return
end

local dctenum
ok, dctenum = pcall(require, "dct.libs.kickinfo")
if not ok then
	log.write(facility, log.ERROR,
		string.format("unable to require dct.enum: %s", dctenum))
	return
end

ok, DCTHooks = pcall(require, "dcthooks")
if not ok then
	log.write(facility, log.ERROR,
		string.format("unable to load dcthooks: %s", DCTHooks))
	return
end

local special_unit_role_types = {
	["forward_observer"]    = true,
	["instructor"]          = true,
	["artillery_commander"] = true,
	["observer"]            = true,
}

local DCTSlotBlock = class(facility, DCTHooks)
function DCTSlotBlock:__init()
	self.started    = false
	self.info       = {
		["heartbeat"] = {
			["dirty"]    = true,
			["lastsent"] = 0,
			["period"]   = 60,
		},
	}
	self.slotkicktimer = 0
	self.slotkickperiod = 5
	self.mission_start_mt = 0
	self.mission_start_rt = 0
	self.mission_period = self.settings.server.period
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
	self.whitelists = self.settings.server.whitelists
	self.blockspecialslots = (next(self.whitelists) ~= nil)
	self.slot2player = {}  -- indexed by slotid (player.slot / slot.unitId)
	                       -- pointing to player id; [unitId] = playerid
end

function DCTSlotBlock:start()
	self.started = true
end

function DCTSlotBlock:stop()
	self.started = false
end

function DCTSlotBlock:isStarted()
	return self.started
end

-- load the mission's available player slots
function DCTSlotBlock:getslots()
	self.slots = {}
	self.groups = {}

	for coa, _ in pairs(DCS.getAvailableCoalitions()) do
		for _, slot in ipairs(DCS.getAvailableSlots(coa)) do
			if self.slots[slot.unitId] then
				self:log(log.ERROR,
					 "multiple units with unitId: "..
						tostring(slot.unitId))
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

function DCTSlotBlock:onSimulationStop()
	if not self:isStarted() then
		return
	end
	self:stop()
end

function DCTSlotBlock:onSimulationPause()
	if not self:isStarted() then
		return
	end
	self:stop()
end

function DCTSlotBlock:onSimulationResume()
	local dctenabled = self:isMissionEnabled()
	if not DCS.isServer() or not DCS.isMultiplayer() or
	   dctenabled == 0 then
		self:log(log.DEBUG, "not DCT enabled; server(%s), enabled(%s)",
			 tostring(DCS.isServer()), tostring(dctenabled))
		return
	end
	self:start()
end

function DCTSlotBlock:onMissionLoadEnd()
	self.slotkicktimer = 0
	self.mission_start_mt = DCS.getModelTime()

	self:log(log.DEBUG, "mission_start_mt: %f", self.mission_start_mt)
	self:log(log.DEBUG, "mission_period: %f", self.mission_period)

	-- reset warning messages
	for warntime, data in pairs(self.restartwarnings) do
		if self.mission_period <= 0 or
		   warntime <= self.mission_period then
			data.sent = true
		else
			data.sent = false
		end
	end
end

function DCTSlotBlock:onPlayerConnect(id)
	self:log(log.DEBUG, "player connect, id: %d", id)
	local player = self:getPlayerInfo(id)

	if self.players[id] ~= nil then
		self:log(log.WARNING, "player id(%s) already assigned, "..
			 "overwriting", id)
	end

	self.players[id] = player

	if player == nil then
		self:log(log.WARNING, "player id(%s) not found", id)
		return
	end
end

function DCTSlotBlock:onPlayerDisconnect(id, err_code)
	self:log(log.DEBUG, "player disconnect; id(%s), code(%s)",
		 tostring(id), tostring(err_code))
	-- clean up tables from last cached player data
	if self.players[id] and self.players[id].slot then
		self.slot2player[self.players[id].slot] = nil
	end
	-- delete player entry
	self.players[id] = nil
end

function DCTSlotBlock:onPlayerChangeSlot(id)
	self:log(log.DEBUG, "player change slot, id: %d", id)
	local prev_player = self.players[id]
	local new_player  = self:getPlayerInfo(id)

	if prev_player and prev_player.slot then
		self.slot2player[prev_player.slot] = nil
	end
	if new_player and new_player.slot then
		self.slot2player[new_player.slot] = id
	end
	self.players[id] = new_player
end

-- Returns: true - allows slot change, false - denies change
function DCTSlotBlock:onPlayerTryChangeSlot(playerid, _, slotid)
	local pass = nil
	if not self:isStarted() then
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
		rc = self:isSlotEnabled(slot)
	end

	if rc == false then
		net.send_chat_to(
			string.format("***slot(%s) permission denied, "..
				      "choose another***",
				      tostring(slot.unitId)),
			playerid, net.get_server_id())
		net.send_chat_to(string.format("  reason: %s", reason),
			playerid, net.get_server_id())
		return false
	end
	return pass
end

function DCTSlotBlock:sendheartbeat()
	local time_left = (self.mission_start_mt + self.mission_period) -
			  DCS.getModelTime()

	for t, data in pairs(self.restartwarnings) do
		if time_left < t and not data.sent then
			self:rpcSendMsgToAll(data.message, 20, true)
			data.sent = true
		end
	end
	if self.mission_period > 0 and time_left < 0 then
		net.load_next_mission()
		-- TODO: try to initiate an end mission event
	end
end

function DCTSlotBlock:kickPlayersInGroup(grpname, slots)
	local kick = self:rpcGetFlag(grpname.."_kick")

	if kick ~= dctenum.kickCode.NOKICK then
		for slotid, _ in pairs(slots) do
			local pid = self.slot2player[slotid]
			if pid then
				net.force_player_slot(pid, 0, '')
				net.send_chat_to(string.format(
					"*** you have been kicked from "..
					"slot(%s) ***\n  reason: %s",
					slotid, dctenum.kickReason[kick]),
					pid, net.get_server_id())
			end
		end
	end

	self:rpcSetFlag(grpname.."_kick", dctenum.kickCode.NOKICK)
end

function DCTSlotBlock:onSimulationFrame()
	if not self:isStarted() then
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

	local modeltime = os.clock()
	if math.abs(modeltime - self.slotkicktimer) > self.slotkickperiod then
		self.slotkicktimer = modeltime
		for grpname, slots in pairs(self.groups) do
			self:kickPlayersInGroup(grpname, slots)
		end
	end
end

local slotblock = DCTSlotBlock()
slotblock:register()
