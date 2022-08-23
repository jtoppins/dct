--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- common utility functions
--]]

require("os")
require("math")
local check = require("libs.check")
local enum  = require("dct.enum")
local vector = require("dct.libs.vector")
local utils = {}

local enemymap = {
	[coalition.side.NEUTRAL] = false,
	[coalition.side.BLUE]    = coalition.side.RED,
	[coalition.side.RED]     = coalition.side.BLUE,
}

utils.INTELMAX = 5

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
	return (grp and grp:isExist() and grp:getSize() > 0)
end

function utils.interp(s, tab)
	return (s:gsub('(%b%%)', function(w) return tab[w:sub(2,-2)] or w end))
end

function utils.assettype2mission(assettype)
	for k, v in pairs(enum.missionTypeMap) do
		if v[assettype] then
			return k
		end
	end
	return nil
end

local airbase_id2name_map = nil
function utils.airbaseId2Name(id)
	if id == nil then
		return nil
	end
	if airbase_id2name_map == nil then
		airbase_id2name_map = {}
		for _, ab in pairs(world.getAirbases()) do
			airbase_id2name_map[tonumber(ab:getID())] = ab:getName()
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

function utils.time(dcsabstime)
	-- timer.getAbsTime() returns local time of day, but we still need
	-- to calculate the day
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

utils.posfmt = {
	["DD"]   = 1,
	["DDM"]  = 2,
	["DMS"]  = 3,
	["MGRS"] = 4,
}

-- reduce the accuracy of the position to the precision specified
function utils.degradeLL(lat, long, precision)
	local multiplier = math.pow(10, precision)
	lat  = math.modf(lat * multiplier) / multiplier
	long = math.modf(long * multiplier) / multiplier
	return lat, long
end

-- set up formatting args for the LL string
local function getLLformatstr(precision, fmt)
	local decimals = precision
	if fmt == utils.posfmt.DDM then
		if precision > 1 then
			decimals = precision - 1
		else
			decimals = 0
		end
	elseif fmt == utils.posfmt.DMS then
		if precision > 4 then
			decimals = precision - 2
		elseif precision > 2 then
			decimals = precision - 3
		else
			decimals = 0
		end
	end
	if decimals == 0 then
		return "%02.0f"
	else
		return "%0"..(decimals+3).."."..decimals.."f"
	end
end

function utils.LLtostring(lat, long, precision, fmt)
	local northing = "N"
	local easting  = "E"
	local degsym   = '°'

	if lat < 0 then
		northing = "S"
	end

	if long < 0 then
		easting = "W"
	end

	lat, long = utils.degradeLL(lat, long, precision)
	lat  = math.abs(lat)
	long = math.abs(long)

	local fmtstr = getLLformatstr(precision, fmt)

	if fmt == utils.posfmt.DD then
		return string.format(fmtstr..degsym, lat)..northing..
			" "..
			string.format(fmtstr..degsym, long)..easting
	end

	-- we give the minutes and seconds a little push in case the division
	-- from the truncation with this multiplication gives us a value ending
	-- in .99999...
	local tolerance = 1e-8

	local latdeg   = math.floor(lat)
	local latmind  = (lat - latdeg)*60 + tolerance
	local longdeg  = math.floor(long)
	local longmind = (long - longdeg)*60 + tolerance

	if fmt == utils.posfmt.DDM then
		return string.format("%02d"..degsym..fmtstr.."'", latdeg, latmind)..
			northing..
			" "..
			string.format("%03d"..degsym..fmtstr.."'", longdeg, longmind)..
			easting
	end

	local latmin   = math.floor(latmind)
	local latsecd  = (latmind - latmin)*60 + tolerance
	local longmin  = math.floor(longmind)
	local longsecd = (longmind - longmin)*60 + tolerance

	return string.format("%02d"..degsym.."%02d'"..fmtstr.."\"",
			latdeg, latmin, latsecd)..
		northing..
		" "..
		string.format("%03d"..degsym.."%02d'"..fmtstr.."\"",
			longdeg, longmin, longsecd)..
		easting
end

function utils.MGRStostring(mgrs, precision)
	local str = mgrs.UTMZone .. " " .. mgrs.MGRSDigraph

	if precision == 0 then
		return str
	end

	local divisor = 10^(5-precision)
	local fmtstr  = "%0"..precision.."d"

	if precision == 0 then
		return str
	end

	return str.." "..string.format(fmtstr, (mgrs.Easting/divisor))..
		" "..string.format(fmtstr, (mgrs.Northing/divisor))
end

function utils.degrade_position(position, precision)
	local lat, long = coord.LOtoLL(position)
	lat, long = utils.degradeLL(lat, long, precision)
	return coord.LLtoLO(lat, long, 0)
end

function utils.fmtposition(position, precision, fmt)
	precision = math.floor(precision)
	assert(precision >= 0 and precision <= 5,
		"value error: precision range [0,5]")
	local lat, long = coord.LOtoLL(position)

	if fmt == utils.posfmt.MGRS then
		return utils.MGRStostring(coord.LLtoMGRS(lat, long),
			precision)
	end

	return utils.LLtostring(lat, long, precision, fmt)
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

function utils.calcTACANFreq(chan, mode)
	local aienum = require("dct.ai.enum")
	check.range(chan, 1, 126)
	check.tblkey(mode, aienum.BEACON.TACANMODE, "BEACON.TACANMODE")
	local A = 1151
	local B = 64

	if chan < 64 then
		B = 1
	end
	if mode == aienum.BEACON.TACANMODE.Y then
		A = 1025
		if chan < 64 then
			A = 1088
		end
	else
		if chan < 64 then
			A = 962
		end
	end
	return (A + chan - B) * 1000000
end

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

--- HIT definition:
--   id = id of this event
--   initiator = DCT asset that was hit
--   weapon = DCTWeapon object
function utils.buildevent.hit(asset, weapon)
	check.table(asset)
	check.table(weapon)
	local event = {}
	event.id = enum.event.DCT_EVENT_HIT
	event.initiator = asset
	event.weapon = weapon
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

return utils
