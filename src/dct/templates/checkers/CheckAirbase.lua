--- SPDX-License-Identifier: LGPL-3.0

local class   = require("libs.namedclass")
local dctenum = require("dct.enum")
local Check   = require("dct.templates.checkers.Check")

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
		["takeofftype"] = {
			["default"] = "inair",
			["type"]    = Check.valuetype.VALUES,
			["values"]  = takeoffvalues,
			["description"] =
	"This allows the mission designer to specify how AI aircraft will"..
	"depart the field. The possible options are:",
		},
		["recoverytype"] = {
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
	--[dctenum.assetType.CV]      = true,
}

function CheckAirbase:check(data)
	if airbases[data.objtype] == nil then
		return true
	end

	return Check.check(self, data)
end

return CheckAirbase
