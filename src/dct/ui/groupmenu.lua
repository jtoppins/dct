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
local Logger  = require("dct.Logger").getByName("UI")
local addmenu = missionCommands.addSubMenuForGroup
local addcmd  = missionCommands.addCommandForGroup

local menus = {}
function menus.createMenu(theater, asset)
	local gid  = asset.groupId
	local name = asset.name

	if asset.uimenus ~= nil then
		Logger:debug("createMenu - group("..name..") already had menu added")
		return
	end

	Logger:debug("createMenu - adding menu for group: "..tostring(name))

	asset.uimenus = {}

	local padmenu = addmenu(gid, "Scratch Pad", nil)
	for k, v in pairs({
		["DISPLAY"] = enum.uiRequestType.SCRATCHPADGET,
		["SET"] = enum.uiRequestType.SCRATCHPADSET}) do
		addcmd(gid, k, padmenu, theater.playerRequest, theater,
			{
				["name"]   = name,
				["type"]   = v,
			})
	end

	addcmd(gid, "Theater Update", nil, theater.playerRequest, theater,
		{
			["name"]   = name,
			["type"]   = enum.uiRequestType.THEATERSTATUS,
		})

	local msnmenu = addmenu(gid, "Mission", nil)
	local rqstmenu = addmenu(gid, "Request", msnmenu)
	-- TODO: I am knowingly not sorting the keys so the order in which
	-- commands are applied could be random, do this later if it seems to
	-- be a problem as lua doesn't provide a default solution.
	for k, v in pairs(theater:getATORestrictions(asset.owner,
		asset.unittype)) do
		addcmd(gid, k, rqstmenu, theater.playerRequest, theater,
			{
				["name"]   = name,
				["type"]   = enum.uiRequestType.MISSIONREQUEST,
				["value"]  = v,
			})
	end

	addcmd(gid, "Briefing", msnmenu, theater.playerRequest, theater,
		{
			["name"]   = name,
			["type"]   = enum.uiRequestType.MISSIONBRIEF,
		})
	addcmd(gid, "Status", msnmenu, theater.playerRequest, theater,
		{
			["name"]   = name,
			["type"]   = enum.uiRequestType.MISSIONSTATUS,
		})
	addcmd(gid, "Abort", msnmenu, theater.playerRequest, theater,
		{
			["name"]   = name,
			["type"]   = enum.uiRequestType.MISSIONABORT,
			["value"]  = "player requested"
		})
	addcmd(gid, "Rolex +30", msnmenu, theater.playerRequest, theater,
		{
			["name"]   = name,
			["type"]   = enum.uiRequestType.MISSIONROLEX,
			["value"]  = 30*60,  -- seconds
		})
	addcmd(gid, "Check-In", msnmenu, theater.playerRequest, theater,
		{
			["name"]   = name,
			["type"]   = enum.uiRequestType.MISSIONCHECKIN,
		})
	addcmd(gid, "Check-Out", msnmenu, theater.playerRequest, theater,
		{
			["name"]   = name,
			["type"]   = enum.uiRequestType.MISSIONCHECKOUT,
		})
end

return menus
