--- SPDX-License-Identifier: LGPL-3.0

local class    = require("libs.namedclass")
local utils    = require("libs.utils")
local dctenum  = require("dct.enum")
local dctutils = require("dct.libs.utils")
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
	})
end

local airbases = {
	[dctenum.assetType.AIRBASE] = true,
	[dctenum.assetType.CV]      = true,
	[dctenum.assetType.FARP]    = true,
}

function CheckAirbase:check(data)
	if airbases[data.objtype] == nil then
		return true
	end

	data.rename = false

	local ok, key, msg = Check.check(self, data)
	if not ok then
		return ok, key, msg
	end

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
		if data.objtype ~= dctenum.assetType.AIRBASE and
		   data.tpldata == nil then
			local miz_groups = dctutils.get_miz_groups()
			local U = Unit.getByName(data.name)
			local G = U:getGroup()
			local gdata = miz_groups[G:getName()]

			data.tpldata = utils.deepcopy(gdata.data)
			data.overwrite = false
		end
		data.location = ab:getPoint()
	end

	return true
end

return CheckAirbase
