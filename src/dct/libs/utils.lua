--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- common utility functions
--]]

require("os")
require("math")
local libsutils = require("libs.utils")
local check = require("libs.check")
local enum  = require("dct.enum")
local vector = require("dct.libs.vector")
local utils = {}

utils.INTELMAX = 5
utils.coalition = {
	["ALL"]       = -1,
	["NEUTRAL"]   = coalition.side.NEUTRAL,
	["RED"]       = coalition.side.RED,
	["BLUE"]      = coalition.side.BLUE,
	["CONTESTED"] = 3,
}

local enemymap = {
	[coalition.side.NEUTRAL] = false,
	[coalition.side.BLUE]    = coalition.side.RED,
	[coalition.side.RED]     = coalition.side.BLUE,
}

function utils.getenemy(side)
	return enemymap[side]
end

function utils.isenemy(side1, side2)
	if side1 == side2 then
		return false
	end
	if utils.getenemy(side1) ~= side2 then
		return false
	end
	return true
end

function utils.isalive(grpname)
	local grp = Group.getByName(grpname)
	return (grp ~= nil and grp:isExist() and grp:getSize() > 0)
end

function utils.errtraceback(err, lvl)
	lvl = lvl or 0
	return "\n---[ cut here ]---\n"..
	       string.format("ERROR DCT(%s): ", dct._VERSION)..
	       debug.traceback(err, lvl+1)..
	       "\n---[ end trace ]---"
end

--- Logs an error message as a result of a failed pcall context
function utils.errhandler(err, logger, lvl)
	local str = utils.errtraceback(err, lvl or 1)
	logger:error("%s", str)

	if _G.DCT_TEST == true then
		print(str)
	end
end

--- Calls an optional function for a set of objects defined in tbl.
--
-- @param tbl the table of objects whos keys do not matter and whos values
-- are the objects to be checked if the object implements the optional
-- `func` function.
-- @param func the function to check for and execute if exists
function utils.foreach_call(tbl, iterator, func, ...)
	check.table(tbl)
	check.func(iterator)

	for _, obj in iterator(tbl) do
		if type(obj[func]) == "function" then
			obj[func](obj, ...)
		end
	end
end

function utils.interp(s, tab)
	return (s:gsub('(%b%%)', function(w) return tab[w:sub(2,-2)] or w end))
end

function utils.no_filter()
	return true
end

function utils.assettype2mission(assettype)
	for k, v in pairs(enum.missionTypeMap) do
		if v[assettype] then
			return k
		end
	end
	return nil
end

local airbase_id2name_map = false
function utils.airbase_id2name(id)
	if id == nil then
		return nil
	end

	if airbase_id2name_map == false then
		airbase_id2name_map = {}
		for _, ab in pairs(world.getAirbases()) do
			airbase_id2name_map[tonumber(ab:getID())] =
				ab:getName()
		end
	end
	return airbase_id2name_map[id]
end

function utils.isplayergroup(grp)
	local slotcnt = 0
	for _, unit in ipairs(grp.units) do
		if unit.skill == "Client" then
			slotcnt = slotcnt + 1
		end
	end
	if slotcnt > 0 then
		return true, slotcnt
	end
	return false
end

function utils.not_playergroup(grp)
	local isplayer = utils.isplayergroup(grp)
	return not isplayer
end

function utils.check_ato(mlist)
	local ntbl = {}

	for _, v in pairs(mlist) do
		local mtype  = enum.missionType[string.upper(v)]

		if mtype == nil then
			return false, string.format(
				"invalid mission type: %s", v)
		end
		ntbl[mtype] = true
	end
	return true, ntbl
end

function utils.set_ato(sqdn, flight)
	local sqdnato = sqdn:getDescKey("ato")
	-- mixed flights are not allowed in DCS
	local actype = next(flight:getDescKey("unitTypeCnt"))
	local globalato = dct.settings.ato[actype]

	if next(sqdnato) ~= nil then
		flight:setDescKey("ato", libsutils.shallowclone(sqdnato))
		return
	end

	if next(globalato) ~= nil then
		flight:setDescKey("ato", libsutils.shallowclone(globalato))
		return
	end

	local allmsns = {}
	for _, val in pairs(enum.missionType) do
		allmsns[val] = true
	end
	flight:setDescKey("ato", allmsns)
end

function utils.get_miz_groups()
	local STM = require("dct.templates.STM")
	local groups = {}
	for _, coa_data in pairs(env.mission.coalition) do
		local grps = STM.processCoalition(coa_data,
			nil, utils.not_playergroup, nil)
		for _, grp in ipairs(grps) do
			groups[grp.data.name] = grp
		end
	end
	return groups
end

function utils.get_miz_units(logger)
	local units = {}
	local groups = utils.get_miz_groups()

	for _, grp in pairs(groups) do
		for _, unit in ipairs(grp.data.units or {}) do
			local u = {}
			u.name = unit.name
			u.category = grp.category
			u.dead = false

			if units[u.name] ~= nil then
				logger:error("multiple same named miz placed"..
					" objects exist: "..u.name)
			end
			units[u.name] = u
		end
	end
	return units
end

function utils.time(dcsabstime)
	-- timer.getAbsTime() returns local time of day, but we still need
	-- to calculate the day
	dcsabstime = dcsabstime or timer.getAbsTime()
	local time = os.time({
		["year"]  = env.mission.date.Year,
		["month"] = env.mission.date.Month,
		["day"]   = env.mission.date.Day,
		["hour"]  = 0,
		["min"]   = 0,
		["sec"]   = 0,
	})
	return time + dcsabstime
end

local offsettbl = {
	["Test Theater"] =  6*3600, -- simulate US Central TZ
	["PersianGulf"]  = -4*3600,
	["Nevada"]       =  8*3600,
	["Caucasus"]     = -4*3600,
	["Normandy"]     = -1*3600,
	["Syria"]        = -3*3600, -- EEST according to sunrise times
}

function utils.zulutime(abstime)
	local correction = offsettbl[env.mission.theatre] or 0
	return (utils.time(abstime) + correction)
end

function utils.centroid2D(point, pcentroid, n)
	if pcentroid == nil or n == nil then
		return vector.Vector2D(point), 1
	end

	local n1 = n + 1
	local p = vector.Vector2D(point)
	local pc = vector.Vector2D(pcentroid)
	local c = {}
	c.x = (p.x + (n * pc.x))/n1
	c.y = (p.y + (n * pc.y))/n1
	return vector.Vector2D(c), n1
end

function utils.trimTypeName(typename)
	if typename ~= nil then
		return string.match(typename, "[^.]-$")
	end
end

function utils.build_kick_flagname(name)
	return name.."_kick"
end

utils.notifymsg =
	"Please read the loadout limits in the briefing and "..
	"use the F10 Menu to validate your loadout before departing."

utils.buildevent = {}
--- DEAD definition:
--   id = id of this event
--   initiator = asset sending the death notification
function utils.buildevent.dead(obj)
	check.table(obj)
	local event = {}
	event.id = enum.event.DCT_EVENT_DEAD
	event.initiator = obj
	return event
end

--- OPERATIONAL definition:
--   id = id of this event
--   initiator = base sending the operational notification
--   state = of the base, true == operational
function utils.buildevent.operational(base, state)
	check.table(base)
	check.bool(state)
	local event = {}
	event.id = enum.event.DCT_EVENT_OPERATIONAL
	event.initiator = base
	event.state = state
	return event
end

--- CAPTURED definition:
--   id = id of this event
--   initiator = object that initiated the capture
--   target = the base that has been captured
-- Doesn't exist right now

--- IMPACT definition:
--   id = id of the event
--   initiator = DCTWeapon class causing the impact
--   point = impact point
function utils.buildevent.impact(wpn)
	check.table(wpn)
	local event = {}
	event.id = enum.event.DCT_EVENT_IMPACT
	event.initiator = wpn
	event.point = wpn:getImpactPoint()
	return event
end

--- ADD_ASSET definition:
--  A new asset was added to the asset manager.
--   id = id of this event
--   initiator = asset being added
function utils.buildevent.addasset(asset)
	check.table(asset)
	local event = {}
	event.id = enum.event.DCT_EVENT_ADD_ASSET
	event.initiator = asset
	return event
end

--- Goal event definition:
--   id = id of this event
--   initiator = goal
function utils.buildevent.goalComplete(goal)
	check.table(goal)
	local event = {}
	event.id = enum.event.DCT_EVENT_GOAL_COMPLETE
	event.initiator = goal
	return event
end

-- Mission event definitions:
--   id = id of this event
--   initiator = mission object
function utils.buildevent.missionStart(msn)
	check.table(msn)
	local event = {}
	event.id = enum.event.DCT_EVENT_MISSION_START
	event.initiator = msn
	return event
end

function utils.buildevent.missionUpdate(msn)
	check.table(msn)
	local event = {}
	event.id = enum.event.DCT_EVENT_MISSION_UPDATE
	event.initiator = msn
	return event
end

-- Mission event definitions:
--   id = id of this event
--   initiator = mission object
--   result = result of the mission; success, abort, timeout
function utils.buildevent.missionDone(msn, result)
	check.table(msn)
	check.number(result)
	local event = {}
	event.id = enum.event.DCT_EVENT_MISSION_DONE
	event.initiator = msn
	event.result = result
	return event
end

--- Mission event definitions:
--   id = id of this event
--   member = member that joined or left
--   initiator = mission object
function utils.buildevent.missionJoin(msn, member)
	local event = {}
	event.id = enum.event.DCT_EVENT_MISSION_JOIN
	event.initiator = msn
	event.member = member
	return event
end

function utils.buildevent.missionLeave(msn, member)
	local event = {}
	event.id = enum.event.DCT_EVENT_MISSION_LEAVE
	event.initiator = msn
	event.member = member
	return event
end

function utils.buildevent.playerKick(code, sensor)
	local event = {}
	event.id = enum.event.DCT_EVENT_PLAYER_KICK
	event.code = code
	event.psensor = sensor
	return event
end

function utils.buildevent.playerJoin(name)
	local event = {}
	event.id = enum.event.DCT_EVENT_PLAYER_JOIN
	event.unit = name
	return event
end

function utils.buildevent.departure(agent, takeofftime)
	local event = {}
	event.id = enum.event.DCT_EVENT_DEPARTURE
	event.agent = agent.name
	event.takeoff = takeofftime
	return event
end

--- Agent Request:
-- id = id of this event
-- initiator = the agent that initiated the request, for player
--   agents they can receive requests they themselves have generated
--   to allow the actual player to modify the model
-- data = request data, at minimum must be a table with a field of 'id'
function utils.buildevent.agentRequest(agent, data)
	local event = {}
	event.id = enum.event.DCT_EVENT_AGENT_REQUEST
	event.initiator = agent
	event.data = data
	return event
end

return utils
