-- SPDX-License-Identifier: LGPL-3.0

--- UI Menus

local utils     = require("libs.utils")
--local vector    = require("dct.libs.vector")
local Mission   = require("dct.libs.Mission")
local PlayerMenu= require("dct.ui.PlayerMenu")
local msncodes  = require("dct.ui.missioncodes")
local uirequest = require("dct.ui.request")
local WS        = require("dct.assets.worldstate")

local function empty() end

--- Manage Scratch Pad menu items
-- F1: Scratch Pad
--   F1: Display
--   F2: Set
local function create_scratchpad(menu)
	menu:addRqstCmd("Display", uirequest.scratchpad_get)
	menu:addRqstCmd("Set", uirequest.scratchpad_set)
end

--- Manage Intel menu items
-- F2: Intel
--   F1: Theater
local function create_intel(menu)
	menu:addRqstCmd("Theater Update", uirequest.theater_update)
end

--- Manage various ground crew tasks
-- F3: Ground Crew
--   F1: Check Payload
--   F2: Homebase Status
local function create_groundcrew(menu)
	menu:addRqstCmd("Check Payload", uirequest.checkpayload)
	menu:addRqstCmd("Homebase Status", uirequest.checkhomeplate)
end

--- When mission assigned
-- F1: Briefing
-- F2: Status
-- F3: Clear Mark
-- F4: Leave
-- FX: <mission specific>
local function _active_mission(menu)
	menu:addRqstCmd("Briefing", uirequest.mission_brief)
	menu:addRqstCmd("Status", uirequest.mission_status)
	menu:addRqstCmd("Clear Mark", uirequest.mission_clear_mark)
	menu:addRqstCmd("Leave", uirequest.mission_leave)
end

--- No mission assigned
-- F1: Request (Type)
--       <ATO mission types listed>
-- F2: Request (List)
--       <top 10 missions>
-- F3: Join (Scratchpad)
-- F4: Join (Input Code)
--       ...
local function _get_mission(menu, agent)
	local rqstTypeMenu = menu:addMenu("Request (Type)")
	local cnt = 1
	for msntype, _ in utils.sortedpairs(agent:getDescKey("ato")) do
		cnt = cnt + 1
		local typename = Mission.typeData[msntype].short
		rqstTypeMenu:addRqstCmd(typename, uirequest.mission_request,
					msntype)
		if cnt >= 10 then
			break
		end
	end

	--[[
	local cmdr = dct.theater:getCommander(agent.owner)
	local location = vector.Vector2D(agent:getDescKey("location"))
	local msnList = cmdr:getTopMissions(agent, 10, true)
	local rqstListMenu = menu:addMenu("Request (List)")

	for _, msn in pairs(msnList) do
		local distance = vector.distance(location,
			vector.Vector2D(msninfo.position.value))

		local title = string.format("%s: %s - %d",
			tostring(msn), msninfo.codename.value,
			distance)

		rqstListMenu:addRqstCmd(title,
			dctenum.requestType.MISSION_REQUEST,
			msn.type, { mission = msn:getID() })
	end
	--]]

	menu:addRqstCmd("Join (Scratchpad)", uirequest.mission_join)
	msncodes(menu:addMenu("Join (Input Code)"))
end

--- Manage Mission menu items
-- F4: Mission
local function create_mission(menu, agent)
	local mission = agent:getMission()

	if mission then
		_active_mission(menu, agent)
	else
		_get_mission(menu, agent)
	end
end

--[[
--- Manage Mission menu items
-- F5: Air Refueling
--   F1: Request Rescue Tkr
--   FX: <Tanker ...>
--      F1: Status
--        <give: fuel state (#receivers), navaid freq, current altitude, speed>
--      F2: Request Rejoin
--        <request: put into refuel queue>
local function create_tanker(menu, agent)
	-- TODO: refresh tankers periodically
end
--]]

local function menu_entry(title, id, handler, iscmd)
	iscmd = iscmd or false
	local _entry = {}
	_entry.handler = handler
	_entry.title   = title
	_entry.id      = id
	_entry.iscmd   = iscmd

	return _entry
end

--- MENUS list of top level other menus that can be modified based on the
-- state of the player agent.
local MENUS = {
	menu_entry("Scratch Pad",
		   WS.Facts.PlayerMenu.menuType.SCRATCHPAD,
		   create_scratchpad),
	menu_entry("Intel",
		   WS.Facts.PlayerMenu.menuType.INTEL,
		   create_intel),
	menu_entry("Ground Crew",
		   WS.Facts.PlayerMenu.menuType.GROUNDCREW,
		   create_groundcrew),
	menu_entry("Mission",
		   WS.Facts.PlayerMenu.menuType.MISSION,
		   create_mission),
	menu_entry("Tanker (not implemented)",
		   WS.Facts.PlayerMenu.menuType.TANKER,
		   empty, true),
}

local function create_menus(agent)
	for _, data in ipairs(MENUS) do
		if data.iscmd == true then
			PlayerMenu.Cmd(data.title, data.handler,
				       nil, nil, agent)
		else
			local menu = PlayerMenu.Menu(
				data.title, nil, agent, data.handler)
			local fact = WS.Facts.PlayerMenu(menu, data.factid)
			agent:setFact(
				WS.Facts.PlayerMenu.buildKey(data.factid),
				fact)
		end
	end
end

return create_menus
