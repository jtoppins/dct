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

local aircraft = {
	["sensors"] = {
		["MissionSensor"]   = 0,
		["PlanningSensor"]  = 0,
		["LocationSensor"]  = 0, -- TODO: updates the location and avg speed
					 -- of an asset so other sensors can reference
					 -- this data
		["PathSensor"]      = 0,
		["ThreatSensor"]    = 0,
		["CoverSensor"]     = 0,
		["FuelSensor"]      = 0,
	},
	["actions"] = {
		["Idle"]         = 1,
		["Ejection"]     = 1,
		["Takeoff"]      = 1,
		["Land"]         = 1,
		["EscapeDanger"] = 7,
		["GotoNode"]     = 1,
		["GotoNodeType"] = 1,
		["GotoTarget"]   = 1,
	},
	["goals"]   = {
		["Idle"]         = 1,
		["ReactToEvent"] = 2,
		["RTB"]          = 1,
	},
}

local groundunits = airdefense

local agents = {}
for _, assettype in pairs(dctenum.assetType) do
	agents[assettype] = static
end

agents[dctenum.assetType.INVALID]     = nil
agents[dctenum.assetType.NODE]        = nil
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
		["AirbaseSensor"]    = 0,
	},
	["actions"] = {
		["RunwayRepair"]     = 1,
		["DoDeparture"]      = 1,
		["Idle"]             = 1,
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
		["AirbaseSensor"]    = 0,
	},
	["actions"] = {
		["DoDeparture"]      = 1,
		["Idle"]             = 1,
	},
	["goals"] = {
		["Idle"]             = 1,
	},
}
agents[dctenum.assetType.SQUADRON]    = {
	["sensors"] = {
		["PlanningSensor"]   = 0,
		["SquadronSensor"]   = 0,
	},
	["actions"] = {
		["Idle"]             = 1,
	},
	["goals"] = {
		["Idle"]             = 1,
	},
}
agents[dctenum.assetType.AIRPLANE] = aircraft
agents[dctenum.assetType.HELO] = aircraft
agents[dctenum.assetType.PLAYER] = {
	["sensors"] = {
		["MissionSensor"]   = 0,
		["PlanningSensor"]  = 0,
		["PlayerSensor"]    = 0,
		["PlayerUISensor"]  = 0,
	},
	["actions"] = {
		["PlayerJoin"]   = 1,
		["Ejection"]     = 1,
		["PlayerKick"]   = 1,
		["PlayerAttack"] = 50,
		["Idle"]         = 1,
	},
	["goals"]   = {
		["Idle"]         = 1,
		["ReactToEvent"] = 2,
	},
}

return agents
