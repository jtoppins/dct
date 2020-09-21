--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides functions for handling templates.
--]]

local enum = {}

enum.assetType = {
	-- control zones
	["KEEPOUT"]     = 1,

	-- strategic types
	["AMMODUMP"]    = 2,
	["FUELDUMP"]    = 3,
	["C2"]          = 4,
	["EWR"]         = 5,
	["MISSILE"]     = 6,
	["OCA"]         = 7,
	["PORT"]        = 8,
	["SAM"]         = 9,
	["FACILITY"]    = 10,

	-- bases
	["BASEDEFENSE"] = 11,

	-- tactical
	["JTAC"]        = 12,
	["LOGISTICS"]   = 13,
	["SEA"]         = 14,

	-- extended type set
	["BUNKER"]      = 15,
	["CHECKPOINT"]  = 16,
	["FACTORY"]     = 17,
	["AIRSPACE"]    = 18,
	["SHORAD"]      = 19,
	["AIRBASE"]     = 20,
	["PLAYERGROUP"] = 21,
	["SPECIALFORCES"] = 22,
	["FOB"]           = 23,
}

--[[
-- We use a min-heap so priority is in reverse numerical order,
-- a higher number is lower priority
--]]
enum.assetTypePriority = {
	[enum.assetType.AIRSPACE]    = 10,
	[enum.assetType.JTAC]        = 10,
	[enum.assetType.EWR]         = 20,
	[enum.assetType.SAM]         = 20,
	[enum.assetType.C2]          = 30,
	[enum.assetType.AMMODUMP]    = 40,
	[enum.assetType.FUELDUMP]    = 40,
	[enum.assetType.MISSILE]     = 50,
	[enum.assetType.SEA]         = 50,
	[enum.assetType.BASEDEFENSE] = 60,
	[enum.assetType.OCA]         = 70,
	[enum.assetType.PORT]        = 70,
	[enum.assetType.LOGISTICS]   = 70,
	[enum.assetType.AIRBASE]     = 70,
	[enum.assetType.SHORAD]      = 100,
	[enum.assetType.FACILITY]    = 100,
	[enum.assetType.BUNKER]      = 100,
	[enum.assetType.CHECKPOINT]  = 100,
	[enum.assetType.SPECIALFORCES] = 100,
	[enum.assetType.FOB]         = 100,
	[enum.assetType.FACTORY]     = 100,
	[enum.assetType.KEEPOUT]     = 10000,
}

enum.missionType = {
	["CAS"]      = 1,
	["CAP"]      = 2,
	["STRIKE"]   = 3,
	["SEAD"]     = 4,
	["BAI"]      = 5,
	["OCA"]      = 6,
	["ARMEDRECON"] = 7,
}

enum.assetClass = {
	["STRATEGIC"] = {
		[enum.assetType.AMMODUMP]    = true,
		[enum.assetType.FUELDUMP]    = true,
		[enum.assetType.C2]          = true,
		[enum.assetType.EWR]         = true,
		[enum.assetType.MISSILE]     = true,
		[enum.assetType.OCA]         = true,
		[enum.assetType.PORT]        = true,
		[enum.assetType.SAM]         = true,
		[enum.assetType.FACILITY]    = true,
		[enum.assetType.BUNKER]      = true,
		[enum.assetType.CHECKPOINT]  = true,
		[enum.assetType.FACTORY]     = true,
		[enum.assetType.SHORAD]      = true,
		[enum.assetType.AIRBASE]     = true,
		[enum.assetType.SPECIALFORCES] = true,
		[enum.assetType.FOB]           = true,
	},
	["BASES"] = {
		[enum.assetType.AIRBASE]     = true,
	},
	-- agents never get seralized to the state file
	["AGENTS"] = {
		[enum.assetType.PLAYERGROUP] = true,
	}
}

enum.missionTypeMap = {
	[enum.missionType.STRIKE] = {
		[enum.assetType.AMMODUMP]   = true,
		[enum.assetType.FUELDUMP]   = true,
		[enum.assetType.C2]         = true,
		[enum.assetType.MISSILE]    = true,
		[enum.assetType.PORT]       = true,
		[enum.assetType.FACILITY]   = true,
		[enum.assetType.BUNKER]     = true,
		[enum.assetType.CHECKPOINT] = true,
		[enum.assetType.FACTORY]    = true,
	},
	[enum.missionType.SEAD] = {
		[enum.assetType.EWR]        = true,
		[enum.assetType.SAM]        = true,
	},
	[enum.missionType.OCA] = {
		[enum.assetType.OCA]        = true,
		[enum.assetType.AIRBASE]    = true,
	},
	[enum.missionType.BAI] = {
		[enum.assetType.LOGISTICS]  = true,
	},
	[enum.missionType.CAS] = {
		[enum.assetType.JTAC]       = true,
	},
	[enum.missionType.CAP] = {
		[enum.assetType.AIRSPACE]   = true,
	},
	[enum.missionType.ARMEDRECON] = {
		[enum.assetType.SPECIALFORCES] = true,
		[enum.assetType.FOB]           = true,
	},
}

enum.missionAbortType = {
	["ABORT"]    = 0,
	["COMPLETE"] = 1,
	["TIMEOUT"]  = 2,
}

enum.uiRequestType = {
	["THEATERSTATUS"]   = 1,
	["MISSIONREQUEST"]  = 2,
	["MISSIONBRIEF"]    = 3,
	["MISSIONSTATUS"]   = 4,
	["MISSIONABORT"]    = 5,
	["MISSIONROLEX"]    = 6,
	["MISSIONCHECKIN"]  = 7,
	["MISSIONCHECKOUT"] = 8,
	["SCRATCHPADGET"]   = 9,
	["SCRATCHPADSET"]   = 10,
	["CHECKPAYLOAD"]    = 11,
	["MISSIONJOIN"]     = 12,
}

enum.weaponCategory = {
	["AA"] = 1,
	["AG"] = 2,
}

enum.WPNINFCOST = 5000

return enum
