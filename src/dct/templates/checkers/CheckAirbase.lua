--- SPDX-License-Identifier: LGPL-3.0

local class    = require("libs.namedclass")
local utils    = require("libs.utils")
local dctenum  = require("dct.enum")
local dctutils = require("dct.libs.utils")
local Check    = require("dct.templates.checkers.Check")

local takeoffvalues = {
	["INAIR"]   = {
		["value"] = AI.Task.WaypointType.TURNING_POINT,
		["description"] =
			"aircraft will depart the field already in the "..
			"air above the field at 1500ft",
	},
	["RUNWAY"]  = {
		["value"] = AI.Task.WaypointType.TAKEOFF,
		["description"] = "aircraft will depart from the runway",
	},
	["PARKING"] = {
		["value"] = AI.Task.WaypointType.TAKEOFF_PARKING,
		["description"] =
			"aircraft will depart the airfield from parking cold",
	},
}

local landingvalues = {
	["TERMINAL"] = {
		["value"] = dctenum.airbaserecovery.TERMINAL,
		["description"] =
			"aircraft will get within 10nm of the airbase "..
			"before despawning",
	},
	["LAND"]     = {
		["value"] = dctenum.airbaserecovery.LAND,
		["description"] =
			"when the aircraft land event fires the plane "..
			"will be despawned",
	},
	["TAXI"]     = {
		["value"] = dctenum.airbaserecovery.TAXI,
		["description"] =
			"the aircraft will be despawned after 5 minutes "..
			"of the land event firing",
	},
}

local CheckAirbase = class("CheckAirbase", Check)
function CheckAirbase:__init()
	Check.__init(self, "Airbase", {
		["takeoff"] = {
			["default"] = "inair",
			["type"]    = Check.valuetype.VALUES,
			["values"]  = takeoffvalues,
			["description"] =
	"This allows the mission designer to specify how AI aircraft will"..
	"depart the field. The possible options are:",
		},
		["recovery"] = {
			["default"] = "terminal",
			["type"]    = Check.valuetype.VALUES,
			["values"]  = landingvalues,
			["description"] =
	"This allows the mission designer to specify how AI aircraft will"..
	"recover at the field. The possible options are:",
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
