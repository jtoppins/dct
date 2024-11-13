-- SPDX-License-Identifier: LGPL-3.0

--- Common functions to convert data to human readable formats.
-- @module dct.ui.human

require("math")
require("libs")

local utils    = libs.utils
local dctenum  = require("dct.enum")
local dctutils = require("dct.libs.utils")
local Mission  = require("dct.ai.Mission")
local WS       = require("dct.agent.worldstate")

local function conversion_entry(ratio, symbol)
        return {
                ["ratio"]  = ratio,
                ["symbol"] = symbol,
        }
end

local posfmt = {
	["DD"]   = 1,
	["DDM"]  = 2,
	["DMS"]  = 3,
	["MGRS"] = 4,
}

local altfmt = {
	["FEET"]  = 1,
	["METER"] = 2,
}

--- altitude conversion table from meters to X
local altitude_conversion = {
	[altfmt.FEET]  = conversion_entry(3.28084, "ft"),
	[altfmt.METER] = conversion_entry(1, "m"),
}

local pressurefmt = {
	["INHG"] = 1,
	["MMHG"] = 2,
	["HPA"]  = 3,
	["MBAR"] = 4,
}

--- pressure conversion table from pascals to X
local pressure_conversion = {
	[pressurefmt.INHG] = conversion_entry(0.0002953, "inHg"),
	[pressurefmt.MMHG] = conversion_entry(0.00750062, "mmHg"),
	[pressurefmt.HPA]  = conversion_entry(0.01, "hPa"),
	[pressurefmt.MBAR] = conversion_entry(0.1, "mbar"),
}

local distancefmt = {
	["NAUTICALMILE"] = 1,
	["STATUTEMILE"]  = 2,
	["KILOMETER"]    = 3,
}

--- distance conversion from meters to X
local distance_conversion = {
	[distancefmt.NAUTICALMILE] = conversion_entry(0.000539957, "NM"),
	[distancefmt.STATUTEMILE] = conversion_entry(0.000621371, "sm"),
	[distancefmt.KILOMETER] = conversion_entry(0.001, "km"),
}

local speedfmt = {
	["KNOTS"] = 1,
	["KPH"]   = 2,
	["MPH"]   = 3,
}

--- converts meters per second to X speed
local speed_conversion = {
	[speedfmt.KNOTS] = conversion_entry(1.94384, "kts"),
	[speedfmt.KPH] = conversion_entry(3.6, "kph"),
	[speedfmt.MPH] = conversion_entry(2.23694, "mph"),
}

local tempfmt = {
	["K"] = 1,
	["F"] = 2,
	["C"] = 3,
}

--- converts kelvins to X temp
local temp_conversion = {
	[tempfmt.K] = conversion_entry(1, "K"),
	[tempfmt.C] = {
		["symbol"]  = "C",
		["convert"] = function (value)
			return value - 273.15
		end,
	},
	[tempfmt.F] = {
		["symbol"]  = "F",
		["convert"] = function (value)
			return (value - 273.15) * 9/5 + 32
		end,
	},
}

local unitstype = {
	["SPEED"]    = 1,
	["DISTANCE"] = 2,
	["ALTITUDE"] = 3,
	["PRESSURE"] = 4,
	["TEMP"]     = 5,
}

local conversiontbl = {
	[unitstype.SPEED]    = speed_conversion,
	[unitstype.DISTANCE] = distance_conversion,
	[unitstype.ALTITUDE] = altitude_conversion,
	[unitstype.PRESSURE] = pressure_conversion,
	[unitstype.TEMP]     = temp_conversion,
}

-- Filter out facts that are not considered targets.
local function istarget(owner)
	return function (fact)
		if fact.type == WS.Facts.factType.CHARACTER and
		   fact.objtype == dctenum.objtype.AGENT and
		   dctutils.isenemy(fact.owner.value, owner) and
		   fact.object.confidence > 0 and fact.position and
		   (fact.position.confidence * dctutils.INTELMAX) > 3 then
			return true
		end
		return false
	end
end

-- Filter out facts that are not considered threats.
local function isthreat(owner)
	return function (fact)
		if fact.type == WS.Facts.factType.CHARACTER and
		   fact.objtype == dctenum.objtype.AGENT and
		   dctutils.isenemy(fact.owner.value, owner) and
		   fact.object.confidence == 0 then
		   return true
		end
		return false
	end
end

-- reduce the accuracy of the position to the precision specified
local function degradeLL(lat, long, precision)
	local multiplier = math.pow(10, precision)
	lat  = math.modf(lat * multiplier) / multiplier
	long = math.modf(long * multiplier) / multiplier
	return lat, long
end

-- set up formatting args for the LL string
local function getLLformatstr(precision, fmt)
	local decimals = precision
	if fmt == posfmt.DDM then
		if precision > 1 then
			decimals = precision - 1
		else
			decimals = 0
		end
	elseif fmt == posfmt.DMS then
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

local human = {}

human.posfmt = posfmt
human.altfmt = altfmt
human.pressurefmt = pressurefmt
human.distancefmt = distancefmt
human.speedfmt = speedfmt
human.tempfmt = tempfmt
human.units = unitstype

--- Convert from DCS native unit to another unit of measure using
-- conversion tables.
-- @tparam number value value to convert
-- @tparam human.units utype the type of unit of measure
-- @tparam  human.*fmt touint the unit of measure to convert to.
-- @treturn[1] number converted value
-- @treturn[1] number unit symbol
-- @treturn[2] nil on error
function human.convert(value, utype, tounit)
	local converttbl = conversiontbl[utype]

	if converttbl == nil then
		return nil
	end

	local totbl = converttbl[tounit]

	if totbl == nil then
		return nil
	end

	if type(totbl.convert) == "function" then
		return totbl.convert(value), totbl.symbol
	end
	return value * totbl.ratio, totbl.symbol
end

--- enemy air superiority as defined by the US-DOD is
--  'incapability', 'denial', 'parity', 'superiority',
--  'supremacy' - this is simply represented by a number
--  which can then be mapped to a given word
function human.airthreat(value)
	assert(value >= 0 and value <= 100, "value error: value out of range")
	if value >= 0 and value < 20 then
		return "incapability"
	elseif value >= 20 and value < 40 then
		return "denial"
	elseif value >= 40 and value < 60 then
		return "parity"
	elseif value >= 60 and value < 80 then
		return "superiority"
	end
	return "supremacy"
end

--- The value is a rough representation of threat level between 0
-- and 100. This is translated in to 'low', 'med', & 'high'.
function human.threat(value)
	assert(value >= 0 and value <= 100, "value error: value out of range")
	if value >= 0 and value < 30 then
		return "low"
	elseif value >= 30 and value < 70 then
		return "medium"
	end
	return "high"
end

--- A textual representation of the strengths of value.
-- @tparam number value
function human.strength(value)
	if value == nil then
		return "Unknown"
	end

	if value < 25 then
		return "Critical"
	elseif value >= 25 and value < 75 then
		return "Marginal"
	elseif value >= 75 and value < 125 then
		return "Nominal"
	end
	return "Excellent"
end

--- Text representation of the relationship between two sides.
-- @tparam coalition.side side1
-- @tparam coalition.side side2
function human.relationship(side1, side2)
	if side1 == side2 then
		return "Friendly"
	elseif dctutils.getenemy(side1) == side2 then
		return "Hostile"
	else
		return "Neutral"
	end
end

function human.degrade_position(position, precision)
	local lat, long = coord.LOtoLL(position)
	lat, long = degradeLL(lat, long, precision)
	return coord.LLtoLO(lat, long, 0)
end

function human.LLtostring(lat, long, precision, fmt)
	local northing = "N"
	local easting  = "E"
	local degsym   = '°'

	if lat < 0 then
		northing = "S"
	end

	if long < 0 then
		easting = "W"
	end

	lat, long = degradeLL(lat, long, precision)
	lat  = math.abs(lat)
	long = math.abs(long)

	local fmtstr = getLLformatstr(precision, fmt)

	if fmt == posfmt.DD then
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

	if fmt == posfmt.DDM then
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

function human.MGRStostring(mgrs, precision)
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

function human.fmtposition(position, precision, fmt)
	precision = math.floor(precision)
	assert(precision >= 0 and precision <= 5,
		"value error: precision range [0,5]")
	local lat, long = coord.LOtoLL(position)

	if fmt == posfmt.MGRS then
		return human.MGRStostring(coord.LLtoMGRS(lat, long),
			precision)
	end

	return human.LLtostring(lat, long, precision, fmt)
end

-- TODO: this needs to be refined. It needs to be able to handle
-- different character types. Actually it really only makes sense
-- to support Agents, the trouble is things like factories and
-- oil storage should be able to display the coordinates of
-- individual statics and scenery.
--
-- The format of the output is:
-- #. <coords> - <displayname> (<status:operational|damaged>)
function human.mission_detail_facts(msn, filter, gridfmt)
	local facts = {}

	for _, fact in msn:iterateFacts(filter) do
		table.insert(facts, fact)
	end

	if next(facts) == nil then
		return nil
	end

	local result = ""
	for k, fact in ipairs(facts) do
		local health = string.lower(utils.getkey(WS.Health,
					fact.status.value))
		local intel = fact.position.confidence * dctutils.INTELMAX
		local line = string.format("%d. %s - %s (%s)\n",
			k,
			human.fmtposition(fact.position.value,
					     intel, gridfmt),
			tostring(fact.displayname),
			health)
		result = result..line
	end

	return result
end

--- Print all the assets assigned to the Mission(msn).
--
-- @param msn the mission to print the assets assigned
-- @return string listing all the assets assigned
function human.mission_assigned(player)
	local assetmgr = dct.Theater.singleton():getAssetMgr()
	local msn = player:getMission()
	local assets = {}

	for name, _ in msn:iterateAssigned() do
		local asset = assetmgr:getAsset(name)

		if asset and asset.type == dctenum.assetType.PLAYER then
			table.insert(assets, "P: "..
				asset:getDescKey("displayname"))
		elseif asset then
			table.insert(assets, "AI: "..
				asset:getDescKey("displayname"))
		end
	end

	return table.concat(assets, "\n")
end

--- Format location of mission according to the grid format
-- the player object wants. This is simply the AO of the mission
-- not any specific targets the mission has. Since this location
-- is generally known give it a static precision of 3.
--
-- @param player an Agent object representing a player
-- @return string
function human.mission_location(player)
	local msn = player:getMission()

	return human.fmtposition(msn:getDescKey("location"), 3,
				 player:getDescKey("gridfmt"))
end

--- Print target details. Targets are found by iterating over the
-- mission facts looking for character facts with a confidence
-- greater then zero.
--
-- Format:
-- #. <coords> - <displayname> (<status:operational|damaged>)
--
-- @param player an Agent object representing a player
-- @return string
function human.mission_targets(player)
	local result = human.mission_detail_facts(
		player:getMission(), istarget(player.owner),
		player:getDescKey("gridfmt"))

	if result == nil then
		return "No detailed target info."
	end

	return result
end

--- Print threat details.
-- Format:
-- #. <coords> - <displayname> (<status:operational|damaged>)
--
-- @param player an Agent object representing a player
-- @return string
function human.mission_threats(player)
	local result = human.mission_detail_facts(
		player:getMission(), isthreat(player.owner),
		player:getDescKey("gridfmt"))

	if result == nil then
		return "No known threats."
	end

	return result
end

function human.mission_remarks(player)
	local remarks = player:getMission():getDescKey("remarks")

	if remarks == nil then
		return "None."
	end

	return remarks
end

-- TODO: missions can have a tactical frequency assigned, also
-- if a mission has supporting missions a "package" frequency
-- could be assigned. Finally if a mission knows about any
-- supporting assets in the region they could be included.
-- This will be communicated via a mission description table
-- entry, "comms", of the format:
-- mission.desc.comms = {
--     ["flight"] = xxxxxxxxx, -- where the frequency is in hertz
--     ["package"] = x,
--     ["jtac"] = y,
--     -- common frequencies defined at the theater level
--     ["tac1"] = z,
--     ["guard"] = g,
--     -- supporting missions
--     ["tanker"] = a,
--     ["awacs"] = u,
-- }
--
-- Also support defining the IFF codes the player should be
-- using.
function human.mission_commsplan(--[[player]])
	return "Not Implemented"

--[[
local invalidXpdrTbl = {
	["7700"] = true,
	["7600"] = true,
	["7500"] = true,
	["7400"] = true,
}

-- TODO: move this to the human module as IFF codes can be generated from
-- the mission id and the player's join number.
--- Generates a mission id as well as generating IFF codes for the
-- mission (in octal).
--
-- Returns: a table with the following:
--   * id (string): is the mission ID
--   * m1 (number): is the mode 1 IFF code
--   * m3 (number): is the mode 3 IFF code
--  If 'nil' is returned no valid mission id could be generated.
function Commander:genMissionCodes(msntype)
	local missionId, fmtId
	local digit1 = enum.squawkMissionType[msntype]
	for _, id in ipairs(self.missionIds) do
		fmtId = string.format("%01o%02o0", digit1, id)
		if invalidXpdrTbl[fmtId] == nil and self:getMission(fmtId) == nil then
			missionId = id
			break
		end
	end
	assert(missionId ~= nil, "cannot generate mission: no valid ids left")
	local m1 = (8*digit1)+(enum.squawkMissionSubType[msntype] or 0)
	local m3 = (512*digit1)+(missionId*8)
	return { ["id"] = fmtId, ["m1"] = m1, ["m3"] = m3, }
end
--]]
end

--- Generate mission description text from the supplied information
--
-- Replacement text support in briefing descriptions
-- %LOCATIONMETHOD% - a simple little text blurb on how the target was
--                    discovered, not terribly important.
-- %LOCATION% - per player formatted location information
-- %TARGETS% - list of specific targets if intel is high enough precision
--             coordinates will be provided
function human.mission_description(player)
	local msn = player:getMission()
	local description = msn:getDescKey("description")
	local locationmethod = msn:getDescKey("locationmethod")
	local msg

	msg = dctutils.interp(description, {
		["LOCATIONMETHOD"] = locationmethod,
		["LOCATION"] = human.mission_location(player),
		["TARGETS"] = human.mission_targets(player),
	})

	return msg
end

--- Generate the mission overview. This also doubles as the mission
-- status when players request status about the mission they are
-- assigned.
--
-- @param player the player agent
-- @return mission overview string
function human.mission_overview(player)
	local msn = player:getMission()
	local timer = msn:getTimer()
	local health = msn:getFact(WS.Facts.factKey.HEALTH)
	local msndata = Mission.typeData[msn.type]
	local msg = string.format("Package: #%d\n", msn:getID())..
		string.format("Mission: %s\n", msndata.name)..
		string.format("AO: %s (%s)\n",
			human.mission_location(player),
			msn:getDescKey("codename"))

	if timer then
		msg = msg..string.format("Timeout: %s (in %d mins)\n",
			os.date("%F %Rz",
				dctutils.zulutime(timer.timeoutlimit)),
			timer:remain() / 60)
	end
	msg = msg..string.format("Progress: %d%% complete",
				 health.value.value * 100)
	return msg
end

--- Generate mission briefing text for a player. The briefing is broken
-- up into sections; Overview (aka summary), Description, Threat Analysis,
-- Package Assets, and Remarks.
--
-- @param player the player agent
-- @return mission briefing string
function human.mission_briefing(player)
	if player:getMission() == nil then
		return "no mission assigned"
	end

	local msg = ""
	local sections = {
		{
			header = "### Overview",
			body = human.mission_overview(player),
		}, {
			header = "### Description",
			body = human.mission_description(player),
		}, {
			header = "### Comms Plan",
			body = human.mission_commsplan(player),
		}, {
			header = "### Threat Analysis",
			body = human.mission_threats(player),
		}, {
			header = "### Package Assets",
			body = human.mission_assigned(player),
		}, {
			header = "### Remarks",
			body = human.mission_remarks(player),
		}
	}

	for _, v in ipairs(sections) do
		msg = msg..v.header.."\n"..v.body.."\n\n"
	end
	return msg
end

return human
