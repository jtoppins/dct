-- SPDX-License-Identifier: LGPL-3.0

--- UI Requests

--local utils    = require("libs.utils")
--local dctenum  = require("dct.enum")
local dctutils = require("dct.libs.utils")
local Command  = require("dct.libs.Command")
local Mission  = require("dct.libs.Mission")
local WS       = require("dct.assets.worldstate")
local uidraw   = require("dct.ui.draw")
local human    = require("dct.ui.human")
local loadout  = require("dct.ui.loadouts")

local function post_msg(agent, key, msg, displaytime)
	displaytime = displaytime or 30
	agent:setFact(key, WS.Facts.PlayerMsg(msg, displaytime))
end

local function print_have_msn(agent, msn)
	post_msg(agent, "mission_msg",
		string.format("You have mission %s already assigned, "..
			      "use the F10 Menu to leave first.",
			      msn:getID()))
end

local function print_no_mission(agent, erequest)
	local msg = "You do not have a mission assigned"
	erequest = erequest or true

	if erequest == true then
		msg = msg .. ", use the F10 menu to request one first."
	else
		msg = msg .. "."
	end
	post_msg(agent, "mission_msg", msg)
end

local function run_deferred_request(agent, data)
	local result

	agent:setFact(WS.Facts.factType.CMDPENDING, nil)

	if type(data.callback) == "function" and
	   dctutils.isalive(agent.name) then
		local ok
		ok, result = pcall(data.callback, agent, data)

		if not ok then
			agent:setFact("cmdfailed_msg", WS.Facts.PlayerMsg(
				"F10 menu command failed to execute, please "..
				"report a bug", 20))
			dctutils.errhandler(result, agent._logger, 2)
			result = nil
		end
	end
	return result
end

local function defer_request(agent, data)
	local theater = dct.Theater.singleton()
	theater:queueCommand(theater.uicmddelay,
			     Command("player request",
				     run_deferred_request,
				     agent, data))
	agent:setFact(WS.Facts.factKey.CMDPENDING,
		      WS.Facts.Value(WS.Facts.factType.CMDPENDING, true))
end

local function scratchpad_get(agent)
	if not dctutils.isalive(agent.name) then
		return
	end

	local fact = agent:getFact(WS.Facts.factKey.SCRATCHPAD)
	local msg = "Scratch Pad: "

	if fact then
		msg = msg .. tostring(fact.value.value)
	else
		msg = msg .. "nil"
	end
	post_msg(agent, "scratchpad_msg", msg)
end

local function scratchpad_set(agent)
	local theater = dct.Theater.singleton()
	local gid = agent:getDescKey("groupId")
	local pos = Group.getByName(agent.name):getUnit(1):getPoint()
	local scratchpad = theater:getSystem("dct.systems.scratchpad")
	local mark = uidraw.Mark("edit me", pos, false,
				 uidraw.Mark.scopeType.GROUP, gid)

	scratchpad:set(mark.id, {
		["name"] = agent.name,
		["mark"] = mark,
	})
	mark:draw()
	local msg = "Look on F10 MAP for user mark with contents \""..
		"edit me\"\n Edit body with your scratchpad "..
		"information. Click off the mark when finished. "..
		"The mark will automatically be deleted."
	post_msg(agent, "scratchpad_msg", msg)
end

--[[
local function addAirbases(allAirbases, outList, side, ownerFilter)
	for _, airbase in utils.sortedpairs(allAirbases) do
		if airbase.owner == ownerFilter then
			table.insert(outList, string.format("%s: %s",
				human.relationship(side, airbase.owner),
				airbase.name))
		end
	end
end

function TheaterUpdateCmd:_execute()
	local cmdr = self.theater:getCommander(self.asset.owner)
	local update = cmdr:getTheaterUpdate()
	--local available = cmdr:getAvailableMissions(self.asset.ato)
	--local recommended = cmdr:recommendMissionType(self.asset.ato)
	local airbases = self.theater:getAssetMgr():filterAssets(
		function(asset) return asset.type == enum.assetType.AIRBASE end)

	local airbaseList = {}
	if cmdr.owner ~= coalition.side.NEUTRAL then
		addAirbases(airbases, airbaseList, cmdr.owner, cmdr.owner)
	end
	addAirbases(airbases, airbaseList, cmdr.owner, coalition.side.NEUTRAL)
	addAirbases(airbases, airbaseList, cmdr.owner,
		    dctutils.getenemy(cmdr.owner))

	local activeMsnList = {}
	if next(update.missions) ~= nil then
		for msntype, count in utils.sortedpairs(update.missions) do
			table.insert(activeMsnList,
				     string.format("%s:  %d", msntype, count))
		end
	else
		table.insert(activeMsnList, "None")
	end

	local availableMsnList = {}
	if next(available) ~= nil then
		for msntype, count in utils.sortedpairs(available) do
			table.insert(availableMsnList,
				     string.format("%s:  %d", msntype, count))
		end
	else
		table.insert(availableMsnList, "None")
	end

	local msg = "== Theater Status ==\n"..
		string.format("Friendly Force Str: %s\n",
			human.strength(update.friendly.str))..
		string.format("Enemy Force Str: %s\n",
			human.strength(update.enemy.str))..
		string.format("\nAirbases:\n  %s\n",
			table.concat(airbaseList, "\n  "))..
		string.format("\nCurrent Active Air Missions:\n  %s\n",
			table.concat(activeMsnList, "\n  "))..
		string.format("\nAvailable missions:\n  %s\n",
			table.concat(availableMsnList, "\n  "))..
		string.format("\nRecommended Mission Type: %s",
			utils.getkey(enum.missionType, recommended) or "None")

	self:_print(msg)
end
--]]

local function checkpayload(agent)
	local key = "checkpayload_msg"
	if agent:WS():get(WS.ID.INAIR).value == true then
		post_msg(agent, key,
			"Payload check is only allowed when landed at "..
			"a friendly airbase")
		return
	end

	local ok, totals = loadout.check(agent)
	local msg = loadout.summary(totals)
	local header

	if ok then
		header = "Valid loadout, you may depart. Good luck!\n\n"
	else
		header = "You are over budget! Re-arm before departing, "..
			 "or you will be punished!\n\n"
	end
	post_msg(agent, key, header..msg)
end

local function mission_join(agent, data)
	local theater = dct.Theater.singleton()
	local cmdr = theater:getCommander(agent.owner)
	local fact = agent:getFact(WS.Facts.factKey.SCRATCHPAD)
	local msn = agent:getMission()
	local scratchpad

	if msn then
		print_have_msn(agent, msn)
		return
	end

	if fact then
		scratchpad = fact.value.value
	else
		scratchpad = 0
	end
	local missioncode = data.value or scratchpad

	msn = cmdr:getMission(missioncode)
	if msn == nil then
		post_msg(agent, "mission_msg", string.format(
			"No mission of ID(%s) available",
			tostring(missioncode)))
		return
	end

	msn:assign(agent)
end

local function mission_request(agent, data)
	local theater = dct.Theater.singleton()
	local cmdr = theater:getCommander(agent.owner)
	local msn = agent:getMission()
	local missiontype = data.value

	if msn then
		print_have_msn(agent, msn)
		return
	end

	msn = cmdr:requestMission(agent, missiontype)
	if msn == nil then
		local msg = string.format("No %s missions available.",
			Mission.typeData[missiontype].name)
		post_msg(agent, "mission_msg", msg)
		agent._logger:debug(msg)
		return
	end

	msn:assign(agent)
end

local function mission_brief(agent)
	if agent:getMission() == nil then
		print_no_mission(agent)
		return
	end

	post_msg(agent, WS.Facts.factKey.MSNBRIEFMSG,
		 human.mission_briefing(agent), 120)
end

local function mission_status(agent)
	if agent:getMission() == nil then
		print_no_mission(agent)
		return
	end

	local msg = human.mission_overview(agent)..
		"Assigned Assets:\n"..
		human.mission_assigned(agent:getMission())
	post_msg(agent, WS.Facts.factKey.MSNSTATUSMSG, msg, 120)
end


local function mission_leave(agent)
	if agent:getMission() == nil then
		print_no_mission(agent, false)
		return
	end

	local msn = agent:getMission()
	msn:remove(agent)
end

local _request = {}
_request.post_msg        = post_msg
_request.defer_request   = defer_request
_request.scratchpad_get  = scratchpad_get
_request.scratchpad_set  = scratchpad_set
_request.checkpayload    = checkpayload
_request.mission_join    = mission_join
_request.mission_request = mission_request
_request.mission_brief   = mission_brief
_request.mission_status  = mission_status
_request.mission_leave   = mission_leave

return _request
