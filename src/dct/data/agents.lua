--- SPDX-License-Identifier: LGPL-3.0

local dctenum = require("dct.enum")

local statics = {
	["sensors"] = {},
	["actions"] = {},
	["goals"]   = {},
}

local airdefense = {
	["sensors"] = {},
	["actions"] = {},
	["goals"]   = {},
}

local groundunits = airdefense

local agents = {
	[dctenum.assetType.AMMODUMP]    = statics,
	[dctenum.assetType.FUELDUMP]    = statics,
	[dctenum.assetType.PORT]        = statics,
	[dctenum.assetType.FACILITY]    = statics,
	[dctenum.assetType.BUNKER]      = statics,
	[dctenum.assetType.CHECKPOINT]  = statics,
	[dctenum.assetType.FACTORY]     = statics,
	[dctenum.assetType.C2]          = statics,
	[dctenum.assetType.FOB]         = statics,
	[dctenum.assetType.BASEDEFENSE] = airdefense,
	[dctenum.assetType.EWR]         = airdefense,
	[dctenum.assetType.SAM]         = airdefense,
	[dctenum.assetType.SHORAD]      = airdefense,
	[dctenum.assetType.GROUND]      = groundunits,
	[dctenum.assetType.JTAC]        = groundunits,
	[dctenum.assetType.AIRBASE]     = {
		["sensors"] = {},
		["actions"] = {},
		["goals"] = {},
	},
	[dctenum.assetType.CV]          = {
		["sensors"] = {},
		["actions"] = {},
		["goals"] = {},
	},
	[dctenum.assetType.SQUADRON]    = {
		["sensors"] = {},
		["actions"] = {},
		["goals"] = {},
	},
	[dctenum.assetType.PLAYER] = {
		["sensors"] = {
			["MissionSensor"]   = 0,
			["PlanningSensor"]  = 0,
			["PlayerSensor"]    = 0,
		},
		["actions"] = {
			["PlayerJoin"]   = 1,
			["Ejection"]     = 1,
			["PlayerKick"]   = 1,
			["PlayerAttack"] = 50,
		},
		["goals"]   = {
			["Idle"]         = 1,
			["ReactToEvent"] = 2,
		},
	},
}

return agents
