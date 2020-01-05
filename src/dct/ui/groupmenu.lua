--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Handles applying a F10 menu UI to player groups
--]]

--[[
-- Assumptions:
-- It is assumed each player group consists of a single player
-- aircraft due to issues with the game.
--
-- Notes:
--   Once a menu is added to a group it does not need to be added
--   again, which is why we need to track which group ids have had
--   a menu added. The reason why this cannot be done up front on
--   mission start is because the the group does not exist until at
--   least one player occupies a slot. We must add the menu upon
--   object creation.
--]]

local enum    = require("dct.enum")
local Logger  = require("dct.Logger").getByName("UIMenu")
local addmenu = missionCommands.addSubMenuForGroup
local addcmd  = missionCommands.addCommandForGroup

local function createMenu(theater, grp)
	local gid = grp:getID()

	if theater.playergps[gid] ~= nil then
		Logger:debug("createMenu - group("..gid..") already had menu added")
		return
	end

	local name     = grp:getName()
	local side     = grp:getCoalition()
	local unit     = grp:getUnit(1)
	local unitType = "invalid-type"
	if unit ~= nil then
		unitType = unit:getTypeName()
	end

	Logger:debug("createMenu - adding menu for group: "..tostring(gid))

	addcmd(gid, "Theater Update", nil, theater.playerRequest, theater,
		{
			["id"]     = gid,
			["name"]   = name,
			["side"]   = side,
			["actype"] = unitType,
			["type"]   = enum.uiRequestType.THEATERSTATUS,
		})

	local msnmenu = addmenu(gid, "Mission", nil)
	local rqstmenu = addmenu(gid, "Request", msnmenu)
	-- TODO: I am knowingly not sorting the keys so the order in which
	-- commands are applied could be random, do this later if it seems to
	-- be a problem as lua doesn't provide a default solution.
	for k, v in pairs(theater:getATORestrictions(side, unitType)) do
		addcmd(gid, k, rqstmenu, theater.playerRequest, theater,
			{
				["id"]     = gid,
				["name"]   = name,
				["side"]   = side,
				["actype"] = unitType,
				["type"]   = enum.uiRequestType.MISSIONREQUEST,
				["value"]  = v,
			})
	end

	addcmd(gid, "Briefing", msnmenu, theater.playerRequest, theater,
		{
			["id"]     = gid,
			["name"]   = name,
			["side"]   = side,
			["actype"] = unitType,
			["type"]   = enum.uiRequestType.MISSIONBRIEF,
		})
	addcmd(gid, "Status", msnmenu, theater.playerRequest, theater,
		{
			["id"]     = gid,
			["name"]   = name,
			["side"]   = side,
			["actype"] = unitType,
			["type"]   = enum.uiRequestType.MISSIONSTATUS,
		})
	addcmd(gid, "Abort", msnmenu, theater.playerRequest, theater,
		{
			["id"]     = gid,
			["name"]   = name,
			["side"]   = side,
			["actype"] = unitType,
			["type"]   = enum.uiRequestType.MISSIONABORT,
			["value"]  = "player requested"
		})
	addcmd(gid, "Rolex +30", msnmenu, theater.playerRequest, theater,
		{
			["id"]     = gid,
			["name"]   = name,
			["side"]   = side,
			["actype"] = unitType,
			["type"]   = enum.uiRequestType.MISSIONROLEX,
			["value"]  = 30*60,  -- seconds
		})
	addcmd(gid, "Check-In", msnmenu, theater.playerRequest, theater,
		{
			["id"]     = gid,
			["name"]   = name,
			["side"]   = side,
			["actype"] = unitType,
			["type"]   = enum.uiRequestType.MISSIONCHECKIN,
		})
	addcmd(gid, "Check-Out", msnmenu, theater.playerRequest, theater,
		{
			["id"]     = gid,
			["name"]   = name,
			["side"]   = side,
			["actype"] = unitType,
			["type"]   = enum.uiRequestType.MISSIONCHECKOUT,
		})

	theater.playergps[gid] = false
end

local function uiDCSEventHandler(theater, event)
	if not (event.id == world.event.S_EVENT_BIRTH and
		event.initiator and
		event.initiator.getGroup) then
		Logger:debug("uiDCSEventHandler - not handling event: "..
			tostring(event.id))
		return
	end

	local pname = event.initiator:getPlayerName()
	local grp = event.initiator:getGroup()
	if not grp or not pname or pname == "" then
		Logger:debug("uiDCSEventHandler - bad player name ("..
			tostring(pname)..") or group ("..tostring(grp)..")")
		return
	end

	createMenu(theater, grp)
	-- TODO: eventually the code below should be converted to a command
	-- as all communication to the player(s) should not be done in event
	-- handlers. So we should queue a command to send this message to
	-- the group. For now it should be ok.
	local cmdr = theater:getCommander(grp:getCoalition())
	local msn  = cmdr:getAssigned(grp:getName())

	if msn then
		trigger.action.outTextForGroup(grp:getID(),
			"mission already assigned, manage in F10 mission menu",
			20, true)
	else
		trigger.action.outTextForGroup(grp:getID(),
			"theater status and mission management available in F10 menu",
			20, true)
	end
end

local function init(theater)
	assert(theater ~= nil, "value error: theater must be a non-nil value")
	Logger:debug("init UI Menu event handler")
	theater:registerHandler(uiDCSEventHandler, theater)
end

return init
