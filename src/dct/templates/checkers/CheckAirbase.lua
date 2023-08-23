--- SPDX-License-Identifier: LGPL-3.0

local class    = require("libs.namedclass")
local utils    = require("libs.utils")
local dctenum  = require("dct.enum")
local vector   = require("dct.libs.vector")
local TACAN    = require("dct.ai.tacan")
local aitasks  = require("dct.ai.tasks")
local Check    = require("dct.templates.checkers.Check")

local DEFAULT_ALT = 610
local PARKING_START = 1000
local takeoffvalues = {
	["INAIR"]   = {
		["value"] = dctenum.airbaseTakeoff.INAIR,
		["description"] = [[
aircraft will depart the field already in the air 1500ft above the field]],
	},
	["RUNWAY"]  = {
		["value"] = dctenum.airbaseTakeoff.RUNWAY,
		["description"] = [[aircraft will depart from the runway]],
	},
	["PARKING"] = {
		["value"] = dctenum.airbaseTakeoff.PARKING,
		["description"] = [[
aircraft will depart the airfield from ramp parking only cold]],
	},
	["GROUND"] = {
		["value"] = dctenum.airbaseTakeoff.GROUND,
		["description"] = [[
aircraft will depart the airfield from ramp parking if fixed wing and from
ground spots, if defined, for helicopters.]]
	},
}

local landingvalues = {
	["TERMINAL"] = {
		["value"] = dctenum.airbaseRecovery.TERMINAL,
		["description"] = [[
aircraft will get within 10nm of the airbase before despawning]],
	},
	["LAND"]     = {
		["value"] = dctenum.airbaseRecovery.LAND,
		["description"] = [[
aircraft will land on the runway or ramp helipads only and immediately
despawn 30 seconds after doing so]],
	},
	["TAXI"]     = {
		["value"] = dctenum.airbaseRecovery.TAXI,
		["description"] = [[
aircraft will land using runway or helipads, including ground spots, and
be despawned after 5 minutes of the land event firing]],
	},
}

local airbases = {
	[dctenum.assetType.AIRBASE] = true,
	[dctenum.assetType.FARP]    = true,
	[dctenum.assetType.CV]      = true,
	[dctenum.assetType.HELOCARRIER] = true,
}

local isship = {
	[dctenum.assetType.CV] = true,
	[dctenum.assetType.HELOCARRIER] = true,
}

local iscarrier = {
	[dctenum.assetType.CV] = true,
}

local CheckAirbase = class("CheckAirbase", Check)
function CheckAirbase:__init()
	Check.__init(self, "Airbase", {
		["takeoff"] = {
			["default"] = takeoffvalues.INAIR.value,
			["type"]    = Check.valuetype.VALUES,
			["values"]  = takeoffvalues,
			["description"] = [[
This allows the mission designer to specify how AI aircraft will depart the
field. The possible options are:

%VALUES%

If any airbase does not have any suitable parking spots, after exclusion
set is applied, then this option will be forced to runway departures.
Ground spots are only used for helicopters.]],
		},
		["recovery"] = {
			["default"] = landingvalues.TERMINAL.value,
			["type"]    = Check.valuetype.VALUES,
			["values"]  = landingvalues,
			["description"] = [[
This allows the mission designer to specify how AI aircraft will recover at
the field. The possible options are:

%VALUES%

Ground spots, if defined, will only be used for helicopters and only if
recovery is land or taxi.]],
		},
		["tacan"] = {
			["default"] = "",
			["type"]    = Check.valuetype.STRING,
			["description"] = [[
For carriers. Allows the designer to specify the TACAN configuration for
the carrier. This is typically applied to NATO carriers. The format of the
definition is as follows: `<channel><mode> <callsign>`, for example
`31X CVN`, where `31` is the channel, `X` is the TACAN mode, and `CVN` is
the callsign.]],
		},
		["icls"] = {
			["default"] = 0,
			["type"]    = Check.valuetype.RANGE,
			["values"]  = {1, 20},
			["description"] = [[
For carriers. Allows the designer to specify the ICLS channel for the
carrier.]],
		},
		["atc"] = {
			["default"] = "",
			["type"]    = Check.valuetype.STRING,
			["values"]  = {100, 300},
			["description"] = [[
For carriers. Define the frequency on which the carrier's tower operations
will respond. Only one frequency is allowed and has the following format:
`<number>[(AM|FM)]`, example `127.5AM`. Where `127.5` is the frequency in
megahertz and `AM` is the modulation. If not defined what was defined
in the unit definition stm or miz will be used.]],
		},
		["departure_point"] = {
			["default"] = {},
			["type"]    = Check.valuetype.TABLE,
			["description"] = [[
This is the 3D point to which all departing AI aircraft will fly towards
until the AI Flight Lead can plan a more detailed flight plan. The format is
a relative position in relation to the airbase's X orientation vector. Where
a positive x value places the point to the right of the airbase, a positive y
value places the point Y meters AGL above the airbase, and a positive z value
would place the point ahead of the airbase. By default the departure point
is just the airbase's location at ]]..tostring(DEFAULT_ALT)..[[ meters AGL.]],
		},
		["ramp_exclude"] = {
			["default"] = {},
			["type"]    = Check.valuetype.TABLE,
			["description"] = [[
For Land Bases. This setting can be used to additionally exclude ramp spots
that are part of the DCS airbase definition but for some reason do not
function or the designer have chosen to put disable the spot.]],
		},
		["ground_spots"] = {
			["default"] = {},
			["type"]    = Check.valuetype.TABLE,
			["description"] = [[
For Land Bases. This setting defines a set of user defined spots from which
AI aircraft can be ground spawned. These spots will not be used for fixed-wing
aircraft departing but may be used for helicopters. These spots will also
be used to populate the airbase. Defining these spots is simple, provide
an STM for the airbase which defines aircraft with TakeOffGround or
TakeOffGroundHot parking definitions. The spot data will be used but the
aircraft type will be discarded as the spots will be populated with aircraft
types from the squadrons at the airbase.]],
		},
		["populate"] = {
			["default"] = 0,
			["type"]    = Check.valuetype.RANGE,
			["values"]  = {0, 1},
			["description"] = [[
For Land Bases. A value greater than zero causes an airbase to automatically
populate the airbase's ramp and ground spots with aircraft types from the
squadrons based at the field. The decimal value ranging from zero to one
represents the percentage of spots utilized up to the maximum number of
available airframes for all squadrons on the base. Any spawned airframes
that are damaged/destroyed during an air raid will negatively impact
the owning squadron's airframes available.
This option is only available to land airbases and will be forced off for
other types of airbases.]],
		},
		["taxidelay"] = {
			["default"] = 180, -- 3 minutes
			["type"]    = Check.valuetype.INT,
			["description"] = [[
For Land Bases. Is the expected amount of time it will take to taxi to the
runway. This amount of time will modify when the aircraft group actually
gets spawned.]],
		},
	}, [[Configuration specifically related to airbase assets. In this
case an airbase can be a land based airfield, aircraft carrier, or
destroyer with a few helicopters.]])
end

function CheckAirbase:checkCarrier(data)
	if isship[data.objtype] == nil then
		data.tacan = nil
		data.icls = nil
		data.atc = nil
		return true
	end

	if data.atc ~= "" then
		local freq = tonumber(string.match(data.atc,
						   "^(%d+[.]?%d*)%a"))
		local mod = string.upper(string.match(data.atc,
						      "^%d+[.]?%d*(%a)"))
		if freq == nil or mod == nil then
			return false, "atc", "invalid frequency or modulation"
		end

		mod = radio.modulation[mod]
		if mod == nil then
			return false, "atc", "invalid modulation"
		end

		data.atc = {
			["frequency"] = freq * 1000 * 1000,
			["modulation"] = mod,
		}
	else
		data.atc = nil
	end

	if data.tacan ~= "" then
		data.tacan = TACAN.decodeChannel(data.tacan)
		if data.tacan == nil then
			return false, "tacan", "invalid channel or mode"
		end
	else
		data.tacan = nil
	end

	if iscarrier[data.objtype] == nil or data.icls == 0 then
		data.icls = nil
	end
	return true
end

local function reorder_tpldata(data)
	local newtbl = {}
	local i = 0

	for _, grp in pairs(data.tpldata) do
		i = i + 1
		newtbl[i] = grp
	end

	data.tpldata = newtbl
end

--- find ground parking spots
local function find_ground_parking(data)
	if next(data.ground_spots) ~= nil or data.tpldata == nil or
	   next(data.tpldata) == nil then
		return
	end

	local index = PARKING_START

	for key, grp in pairs(data.tpldata) do
		local action = grp.data.route.points[1].action

		if action == aitasks.Waypoint.wpAction.FROM_GROUND or
		   action == aitasks.Waypoint.wpAction.FROM_GROUND_HOT then
			data.tpldata[key] = nil

			for _, unit in ipairs(grp.data.units or {}) do
				local spot = {}

				index = index + 1
				spot.Term_Index = index
				spot.Term_Type = dctenum.parkingType.GROUND
				spot.vTerminalPos =
					vector.Vector3D.create(unit.x, unit.y,
						land.getHeight(unit)):raw()
				table.insert(data.ground_spots, spot)
			end
		end
	end

	if index > PARKING_START then
		reorder_tpldata(data)
	end
end

function CheckAirbase:checkAirbase(data)
	local ab = Airbase.getByName(data.name)

	if ab == nil then
		if data.objtype == dctenum.assetType.AIRBASE then
			return false, "location", string.format(
				"cannot find airbase '%s'", data.name)
		elseif data.tpldata == nil then
			return false, "tpldata", string.format(
				"base(%s) doesn't exist and no template"..
				" data defined", data.name)
		end
	else
		data.location = ab:getPoint()
		utils.mergetables(data.attributes, ab:getDesc().attributes)
	end

	find_ground_parking(data)

	if data.takeoff <= takeoffvalues.RUNWAY.value or
	   isship[data.objtype] then
		data.taxidelay = 0
	end

	if next(data.departure_point) == nil then
		data.departure_point = { x = 0, y = DEFAULT_ALT, z = 0, }
	end

	if data.populate > 0 then
		data.sensors["AirbasePopSensor"] = 0
	end

	return true
end

function CheckAirbase:check(data)
	if airbases[data.objtype] == nil then
		return true
	end

	data.rename = false
	if data.objtype == dctenum.assetType.AIRBASE then
		data.notpldata = true
	end

	for _, check in ipairs({ Check.check,
				 self.checkAirbase,
				 self.checkCarrier, }) do
		local ok, key, msg = check(self, data)
		if not ok then
			return ok, key, msg
		end
	end

	return true
end

return CheckAirbase
