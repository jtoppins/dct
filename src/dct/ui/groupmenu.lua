--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Handles applying a F10 menu UI to player groups
--]]

--[[
-- Assumptions:
-- It is assumed each player group consists of a single player
-- aircraft due to issues with the game.
--]]

Theater = require("dct.Theater")
dctenum = require("dct.enum")
Logger  = require("dct.Logger").getByName("UIMenu")
local addmenu = missionCommands.addSubMenuForGroup
local addcmd  = missionCommands.addCommandForGroup


local function sendRequest(data)
	Theater.getInstance():playerRequest(data)
end

local function createMenu(grp)
	local gid = grp:getID()

	Logger:debug("adding menu for group: "..tostring(gid))

	addcmd(gid, "Theater Update", nil, sendRequest,
		{
		 ["id"] = gid,
		 ["type"] = dctenum.uiRequestType.THEATERSTATUS,
		})
	local msnmenu = addmenu(gid, "Mission", nil)
	local rqstmenu = addmenu(gid, "Request", msnmenu)
	-- TODO: I am knowingly not sorting the keys so the order in which
	-- commands are applied could be random, do this later if it seems to
	-- be a problem as lua doesn't provide a default solution.
	for k, v in pairs(dctenum.missionType) do
		addcmd(gid, k, rqstmenu, sendRequest,
			{
			 ["id"] = gid,
			 ["type"] = dctenum.uiRequestType.MISSIONREQUEST,
			 ["value"] = v,
			})
	end

	addcmd(gid, "Briefing", msnmenu, sendRequest,
		{
		 ["id"] = gid,
		 ["type"] = dctenum.uiRequestType.MISSIONBRIEF,
		})
	addcmd(gid, "Status", msnmenu, sendRequest,
		{
		 ["id"] = gid,
		 ["type"] = dctenum.uiRequestType.MISSIONSTATUS,
		})
	addcmd(gid, "Abort", msnmenu, sendRequest,
		{
		 ["id"] = gid,
		 ["type"] = dctenum.uiRequestType.MISSIONABORT,
		})
	addcmd(gid, "Rolex +30", msnmenu, sendRequest,
		{
		 ["id"] = gid,
		 ["type"] = dctenum.uiRequestType.MISSIONROLEX,
		 ["value"] = 30,
		})
	addcmd(gid, "Check-In", msnmenu, sendRequest,
		{
		 ["id"] = gid,
		 ["type"] = dctenum.uiRequestType.MISSIONCHECKIN,
		})
	addcmd(gid, "Check-Out", msnmenu, sendRequest,
		{
		 ["id"] = gid,
		 ["type"] = dctenum.uiRequestType.MISSIONCHECKOUT,
		})
end

local function uiDCSEventHandler(ctx, event)
	if not (event.id == world.event.S_EVENT_BIRTH and
		event.initiator and
		event.initiator.getGroup) then
		Logger:debug("not handling event: "..tostring(event.id))
		return
	end

	local pname = event.initiator:getPlayerName()
	local grp = event.initiator:getGroup()
	if not grp or not pname or pname == "" then
		Logger:debug("bad player name or group")
		return
	end

	createMenu(grp)
end

local function init()
	Logger:debug("init UI Menu event handler")
	Theater.getInstance():registerHandler(uiDCSEventHandler, 0)
end

return init
