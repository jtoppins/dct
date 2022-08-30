--- SPDX-License-Identifier: LGPL-3.0

local dctenum = require("dct.enum")

local statics = {
	["sensors"] = {
		["DCSObjectsSensor"] = 0,
		["PlanningSensor"]   = 0,
	},
	["actions"] = {
		["GroundIdle"]       = 1,
	},
	["goals"]   = {
		["Idle"]             = 1,
	},
}

local airdefense = {
	["sensors"] = {
		["DCSObjectsSensor"] = 0,
		["PlanningSensor"]   = 0,
	},
	["actions"] = {
		["GroundIdle"]       = 1,
	},
	["goals"]   = {
		["Idle"]             = 1,
	},
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
		["sensors"] = {
			["PlanningSensor"]   = 0,
			["RunwaySensor"]     = 0,
		},
		["actions"] = {
			["RunwayRepair"]     = 1,
		},
		["goals"]   = {
			["Idle"]             = 1,
			["Heal"]             = 1,
		},
	},
	[dctenum.assetType.CV]          = {
		["sensors"] = {
			["MissionSensor"]    = 0,
			["PlanningSensor"]   = 0,
		},
		["actions"] = {
		},
		["goals"] = {
			["Idle"]             = 1,
		},
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
