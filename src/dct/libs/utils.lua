-- SPDX-License-Identifier: LGPL-3.0

--- common utility functions
-- @module dct.libs.utils

local myos = require("os")
require("math")
require("libs")

local libsutils = libs.utils
local check = libs.check
local enum  = require("dct.enum")
local vector = require("dct.libs.vector")
local STM = require("dct.templates.STM")
local utils = {}

--- The maximum intel level a side can achieve. Intel ranges from [0,5]
-- and is mainly used to scale the accuracy of coordinates provided to
-- attacking units. Intel levels of 3 are considered good enough for
-- visual engagement given other information about the target. Levels
-- 4+ are considered good enough for GPS targeting.
utils.INTELMAX = 5

--- An enhanced version of the `coalition.side` DCS table. With two added
-- entries.
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

--- Get the enemy of `side`.
-- @param side coalition we want the enemy of.
-- @return the enemy coalition in `utils.coalition` table.
function utils.getenemy(side)
	return enemymap[side]
end

--- Are `side1` and `side2` enemies?
-- @return bool, true means `side1` and `side2` are enemies.
function utils.isenemy(side1, side2)
	if side1 == side2 then
		return false
	end
	if utils.getenemy(side1) ~= side2 then
		return false
	end
	return true
end

--- Is `grpname` alive according to DCS?
-- @param grpname [string] name of the DCS group to check.
-- @return bool, true the group is alive.
function utils.isalive(grpname)
	local grp = Group.getByName(grpname)
	return (grp ~= nil and grp:isExist() and grp:getSize() > 0)
end

--- Print a stack trace in a well known format, so users know what
-- to copy when reporting errors.
-- @param err error object.
-- @param lvl level in the call stack to start the traceback or zero.
function utils.errtraceback(err, lvl)
	lvl = lvl or 0
	return "\n---[ cut here ]---\n"..
	       string.format("ERROR DCT(%s): ", dct._VERSION)..
	       debug.traceback(err, lvl+1)..
	       "\n---[ end trace ]---"
end

--- Logs an error message as a result of a failed pcall context.
-- @param err error object.
-- @param logger the dct.utils.Logger object to print the trackback to.
-- @param lvl level in the call stack to start the traceback or one.
function utils.errhandler(err, logger, lvl)
	local str = utils.errtraceback(err, lvl or 1)
	logger:error("%s", str)

	if _G.DCT_TEST == true then
		print(str)
	end
end

--- Calls an optional function for a set of objects defined in tbl.
-- @tparam table tbl the table of objects whos keys do not matter and
-- whos values are the objects to be checked if the object implements
-- the optional `func` function.
-- @tparam function iterator callback to iterate over tbl, used in
--   for loop.
-- @tparam string func the name of the function to check for and
--   execute if exists.
function utils.foreach_call(tbl, iterator, func, ...)
	check.table(tbl)
	check.func(iterator)

	for _, obj in iterator(tbl) do
		if type(obj[func]) == "function" then
			obj[func](obj, ...)
		end
	end
end

--- Call an optional function for a set of objected defined in tbl
-- in a protected context.
-- @tparam Logger logger to report errors
-- @tparam table tbl the table of objects whos keys do not matter and
-- whos values are the objects to be checked if the object implements
-- the optional `func` function.
-- @tparam function iterator callback to iterate over tbl, used in
--   for loop.
-- @tparam string func the name of the function to check for and
--   execute if exists.
function utils.foreach_protectedcall(logger, tbl, iterator, func, ...)
	check.table(tbl)
	check.func(iterator)

	local ok, errmsg

	for _, obj in iterator(tbl) do
		if type(obj[func]) == "function" then
			ok, errmsg = pcall(obj[func], obj, ...)
			if not ok then
				utils.errhandler(errmsg, logger, 2)
			end
		end
	end
end

--- String interpolation, substitute %NAME% where NAME is any arbitrary
-- string enclosed with parenthesis with a value in `tab`. `tab` is
-- a table of name=value pairs.
-- @param s string with possible substitution keys.
-- @param tab table of name=value pairs used in the substitution.
-- @return [string] expanded with substitutions.
function utils.interp(s, tab)
	return (s:gsub('(%b%%)', function(w) return tab[w:sub(2,-2)] or w end))
end

--- A nil filter function.
-- @return true always
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

--- Reads a DCS group definition and determines if there are any player
-- units in the group.
-- @param grp group table to read, this is not a normalized group table
--     used in templates, this is a raw group definition that can be
--     read directly from a mission file definition of a group.
function utils.isplayergroup(grp)
	local slotcnt = 0
	for _, unit in ipairs(grp.units) do
		if string.upper(unit.skill) == "CLIENT" then
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

--- Checks list of missions is valid
-- @todo needed?
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

--- Sets the allowed lists of missions a flight can take.
-- @todo needed?
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

--- Enumerate non-player groups found in the currently loaded
-- mission (miz) file.
-- @return list of non-player groups found in the mission indexed
--    by group name.
-- @todo needed? or can be moved to another location?
function utils.get_miz_groups()
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

--- Enumerate non-player units found in the currently loaded
-- mission (miz) file.
-- @return list of non-player units found in the mission indexed
--     by unit name.
-- @todo needed? or can be moved to another location?
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
	local time = myos.time({
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

function utils.buildevent.initcomplete(theater)
	local event = {}
	event.id = enum.event.DCT_EVENT_INIT_COMPLETE
	event.initiator = theater
	return event
end

--- DEAD definition:
-- @field id of this event
-- @field initiator asset sending the death notification
function utils.buildevent.dead(obj)
	check.table(obj)
	local event = {}
	event.id = enum.event.DCT_EVENT_DEAD
	event.initiator = obj
	return event
end

--- OPERATIONAL definition:
-- @field id of this event
-- @field initiator base sending the operational notification
-- @field state of the base, true == operational
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
-- @field id of this event
-- @field initiator object that initiated the capture
-- @field target the base that has been captured
-- Doesn't exist right now

--- IMPACT definition:
-- @field id of this event
-- @field initiator DCTWeapon class causing the impact
-- @field point impact point
function utils.buildevent.impact(wpn)
	check.table(wpn)
	local event = {}
	event.id = enum.event.DCT_EVENT_IMPACT
	event.initiator = wpn
	event.point = wpn:getImpactPoint()
	return event
end

--- ADD_ASSET definition:
-- A new asset was added to the asset manager.
-- @field id of this event
-- @field initiator asset being added
function utils.buildevent.addasset(asset)
	check.table(asset)
	local event = {}
	event.id = enum.event.DCT_EVENT_ADD_ASSET
	event.initiator = asset
	return event
end

--- Goal event definition:
-- @field id of this event
-- @field initiator goal
function utils.buildevent.goalComplete(goal)
	check.table(goal)
	local event = {}
	event.id = enum.event.DCT_EVENT_GOAL_COMPLETE
	event.initiator = goal
	return event
end

-- Mission event definitions:
-- @field id of this event
-- @field initiator mission object
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
-- @field id of this event
-- @field initiator mission object
-- @field result of the mission; success, abort, timeout
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
-- @field id of this event
-- @field initiator mission object
-- @field member that joined or left
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
-- @field id of this event
-- @field initiator the agent that initiated the request, for player
--   agents they can receive requests they themselves have generated
--   to allow the actual player to modify the model
-- @field data request data, at minimum must be a table with a field of 'id'
function utils.buildevent.agentRequest(agent, data)
	local event = {}
	event.id = enum.event.DCT_EVENT_AGENT_REQUEST
	event.initiator = agent
	event.data = data
	return event
end

return utils
