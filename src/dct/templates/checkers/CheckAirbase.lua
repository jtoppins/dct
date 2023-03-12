--- SPDX-License-Identifier: LGPL-3.0

local class    = require("libs.namedclass")
local utils    = require("libs.utils")
local dctenum  = require("dct.enum")
local dctutils = require("dct.libs.utils")
local TACAN    = require("dct.ai.tacan")
local Check    = require("dct.templates.checkers.Check")

local takeoffvalues = {
	["INAIR"]   = {
		["value"] = 1,
		["description"] = [[
aircraft will depart the field already in the air above the field at 1500ft]],
	},
	["RUNWAY"]  = {
		["value"] = 2,
		["description"] = [[aircraft will depart from the runway]],
	},
	["PARKING"] = {
		["value"] = 3,
		["description"] = [[
aircraft will depart the airfield from ramp parking only cold]],
	},
	["GROUND"] = {
		["value"] = 4,
		["description"] = [[
aircraft will depart the airfield from ramp parking if fixed wing and from
ground spots, if defined, for helicopters.]]
	},
}

local landingvalues = {
	["TERMINAL"] = {
		["value"] = 1,
		["description"] = [[
aircraft will get within 10nm of the airbase before despawning]],
	},
	["LAND"]     = {
		["value"] = 2,
		["description"] = [[
aircraft will land on the runway or ramp helipads only and immediately
despawn 30 seconds after doing so]],
	},
	["TAXI"]     = {
		["value"] = 3,
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
	})
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
		local abcategory = ab:getDesc().category

		if abcategory == Airbase.Category.SHIP and
		   data.tpldata == nil then
			local miz_groups = dctutils.get_miz_groups()
			local U = Unit.getByName(data.name)
			local G = U:getGroup()
			local gdata = miz_groups[G:getName()]

			data.tpldata = utils.deepcopy(gdata)
			data.overwrite = false
		end
		data.location = ab:getPoint()
		utils.mergetables(data.attributes, ab:getDesc().attributes)
	end

	return true
end

function CheckAirbase:check(data)
	if airbases[data.objtype] == nil then
		return true
	end

	data.rename = false

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
