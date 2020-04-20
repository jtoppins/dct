--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides functions for handling templates.
--]]

local assetType = {
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
}

--[[
-- We use a min-heap so priority is in reverse numerical order,
-- a higher number is lower priority
--]]
local assetTypePriority = {
	[assetType.AIRSPACE]    = 10,
	[assetType.JTAC]        = 10,
	[assetType.EWR]         = 20,
	[assetType.SAM]         = 20,
	[assetType.C2]          = 30,
	[assetType.AMMODUMP]    = 40,
	[assetType.FUELDUMP]    = 40,
	[assetType.MISSILE]     = 50,
	[assetType.SEA]         = 50,
	[assetType.BASEDEFENSE] = 60,
	[assetType.OCA]         = 70,
	[assetType.PORT]        = 70,
	[assetType.LOGISTICS]   = 70,
	[assetType.AIRBASE]     = 70,
	[assetType.SHORAD]      = 100,
	[assetType.FACILITY]    = 100,
	[assetType.BUNKER]      = 100,
	[assetType.CHECKPOINT]  = 100,
	[assetType.FACTORY]     = 100,
	[assetType.KEEPOUT]     = 10000,
}

local missionType = {
	["CAS"]      = 1,
	["CAP"]      = 2,
	["STRIKE"]   = 3,
	["SEAD"]     = 4,
	["BAI"]      = 5,
	["OCA"]      = 6,
}

local assetClass = {
	["STRATEGIC"] = {
		[assetType.AMMODUMP]    = true,
		[assetType.FUELDUMP]    = true,
		[assetType.C2]          = true,
		[assetType.EWR]         = true,
		[assetType.MISSILE]     = true,
		[assetType.OCA]         = true,
		[assetType.PORT]        = true,
		[assetType.SAM]         = true,
		[assetType.FACILITY]    = true,
		[assetType.BUNKER]      = true,
		[assetType.CHECKPOINT]  = true,
		[assetType.FACTORY]     = true,
		[assetType.SHORAD]      = true,
		[assetType.AIRBASE]     = true,
	},
	["BASES"] = {
		[assetType.AIRBASE]     = true,
	},
	-- agents never get seralized to the state file
	["AGENTS"] = {
		[assetType.PLAYERGROUP] = true,
	}
	--[[
	-- Means ground tactical units
	["TACTICAL"] = {
	},
	["AIRBORNE"] = {
	},
	--]]
}

local missionTypeMap = {
	[missionType.STRIKE] = {
		[assetType.AMMODUMP]   = true,
		[assetType.FUELDUMP]   = true,
		[assetType.C2]         = true,
		[assetType.MISSILE]    = true,
		[assetType.PORT]       = true,
		[assetType.FACILITY]   = true,
		[assetType.BUNKER]     = true,
		[assetType.CHECKPOINT] = true,
		[assetType.FACTORY]    = true,
	},
	[missionType.SEAD] = {
		[assetType.EWR]        = true,
		[assetType.SAM]        = true,
	},
	[missionType.OCA] = {
		[assetType.OCA]        = true,
		[assetType.AIRBASE]    = true,
	},
	[missionType.BAI] = {
		[assetType.LOGISTICS]  = true,
	},
	[missionType.CAS] = {
		[assetType.JTAC]       = true,
	},
	[missionType.CAP] = {
		[assetType.AIRSPACE]   = true,
	},
}

local uiRequestType = {
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
}

local enum = {
	["assetType"]         = assetType,
	["assetTypePriority"] = assetTypePriority,
	["assetClass"]        = assetClass,
	["missionType"]       = missionType,
	["missionTypeMap"]    = missionTypeMap,
	["uiRequestType"]     = uiRequestType,
}

return enum
