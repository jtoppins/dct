--- SPDX-License-Identifier: LGPL-3.0

local dctenum = require("dct.enum")

local static = {
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

local agents = {}
for _, assettype in pairs(dctenum.assetType) do
	agents[assettype] = static
end

agents[dctenum.assetType.BASEDEFENSE] = airdefense
agents[dctenum.assetType.EWR]         = airdefense
agents[dctenum.assetType.SAM]         = airdefense
agents[dctenum.assetType.SHORAD]      = airdefense
agents[dctenum.assetType.GROUND]      = groundunits
agents[dctenum.assetType.JTAC]        = groundunits
agents[dctenum.assetType.AIRBASE]     = {
	["sensors"] = {
		["RunwaySensor"]     = 0,
		["PlanningSensor"]   = 0,
	},
	["actions"] = {
		["RunwayRepair"]     = 1,
	},
	["goals"]   = {
		["Idle"]             = 1,
		["Heal"]             = 1,
	},
}
agents[dctenum.assetType.CV]          = {
	["sensors"] = {
		["DCSObjectsSensor"] = 0,
		["MissionSensor"]    = 0,
		["PlanningSensor"]   = 0,
	},
	["actions"] = {
	},
	["goals"] = {
		["Idle"]             = 1,
	},
}
agents[dctenum.assetType.SQUADRON]    = {
	["sensors"] = {
		["PlanningSensor"]   = 0,
	},
	["actions"] = {
	},
	["goals"] = {
		["Idle"]             = 1,
	},
}
agents[dctenum.assetType.PLAYER] = {
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
}

return agents
