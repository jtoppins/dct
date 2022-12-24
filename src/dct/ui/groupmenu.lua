-- SPDX-License-Identifier: LGPL-3.0
--
-- Handles applying a F10 menu UI to player groups
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

local utils    = require("libs.utils")
local json     = require("libs.json")
local dctenum  = require("dct.enum")
local loadout  = require("dct.ui.loadouts")
local msncodes = require("dct.ui.missioncodes")
local uicmds   = require("dct.ui.cmds")
local WS       = require("dct.assets.worldstate")
local Theater  = dct.Theater
local Logger   = dct.Logger.getByName("UI")
local addmenu  = missionCommands.addSubMenuForGroup
local addcmd   = missionCommands.addCommandForGroup

local menus = {}

function menus.playerRequest(theater, data)
	Logger:debug("playerRequest(); Received player request: %s",
		     json:encode_pretty(data))

	if data == nil then
		Logger:debug("playerRequest(); nil data, ignoring")
		return
	end

	local player = theater:getAssetMgr():getAsset(data.name)

	if player == nil then
		return
	end

	if player:getFact(WS.Facts.factKey.CMDPENDING) ~= nil then
		Logger:debug("playerRequest(); request pending, ignoring")
		WS.Facts.PlayerMsg("F10 request already pending, please wait.",
				   20)
		return
	end

	local cmd = uicmds[data.type](theater, data)
	theater:queueCommand(theater.uicmddelay, cmd)
	player:setFact(WS.Facts.factKey.CMDPENDING,
		       WS.Facts.Value(WS.Facts.factType.CMDPENDING, true))
end

function menus.createMenu(asset)
	local gid  = asset.groupId
	local name = asset.name

	if asset.uimenus ~= nil then
		Logger:debug("createMenu - group(%s) already had menu added", name)
		return
	end

	Logger:debug("createMenu - adding menu for group: %s", name)

	asset.uimenus = {}

	local padmenu = addmenu(gid, "Scratch Pad", nil)
	for k, v in pairs({
		["DISPLAY"] = dctenum.uiRequestType.SCRATCHPADGET,
		["SET"] = dctenum.uiRequestType.SCRATCHPADSET}) do
		addcmd(gid, k, padmenu, Theater.playerRequest,
			{
				["name"]   = name,
				["type"]   = v,
			})
	end

	addcmd(gid, "Theater Update", nil, Theater.playerRequest,
		{
			["name"]   = name,
			["type"]   = dctenum.uiRequestType.THEATERSTATUS,
		})

	local msnmenu = addmenu(gid, "Mission", nil)
	local rqstmenu = addmenu(gid, "Request", msnmenu)
	for k, v in utils.sortedpairs(asset.ato) do
		addcmd(gid, k, rqstmenu, Theater.playerRequest,
			{
				["name"]   = name,
				["type"]   =
					dctenum.uiRequestType.MISSIONREQUEST,
				["value"]  = v,
			})
	end

	local joinmenu = addmenu(gid, "Join", msnmenu)
	addcmd(gid, "Use Scratch Pad Value", joinmenu, Theater.playerRequest,
		{
			["name"]   = name,
			["type"]   = dctenum.uiRequestType.MISSIONJOIN,
			["value"]  = nil,
		})

	local codemenu = addmenu(gid, "Input Code (F1-F10)", joinmenu)
	msncodes.addMissionCodes(gid, name, codemenu)

	addcmd(gid, "Briefing", msnmenu, Theater.playerRequest,
		{
			["name"]   = name,
			["type"]   = dctenum.uiRequestType.MISSIONBRIEF,
		})
	addcmd(gid, "Status", msnmenu, Theater.playerRequest,
		{
			["name"]   = name,
			["type"]   = dctenum.uiRequestType.MISSIONSTATUS,
		})
	addcmd(gid, "Abort", msnmenu, Theater.playerRequest,
		{
			["name"]   = name,
			["type"]   = dctenum.uiRequestType.MISSIONABORT,
			["value"]  = dctenum.missionAbortType.ABORT,
		})
	addcmd(gid, "Rolex +30", msnmenu, Theater.playerRequest,
		{
			["name"]   = name,
			["type"]   = dctenum.uiRequestType.MISSIONROLEX,
			["value"]  = 30*60,  -- seconds
		})
	loadout.addmenu(gid, asset.name, nil, Theater.playerRequest)
end

return menus
