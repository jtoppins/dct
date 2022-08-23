--- SPDX-License-Identifier: LGPL-3.0
--
-- Define some basic global enumerations for DCT.

local enum = {}

enum.geomtype = {
	["CIRCLE"]    = 1,
	["RECTANGLE"] = 2,
	["POLYGON"]   = 3,
}

enum.objtype = {
	["UNIT"]    = 1,
	["STATIC"]  = 2,
	["GROUP"]   = 3,
	["SCENERY"] = 4,
	["AGENT"]   = 5,
}

enum.airbaserecovery = {
	["TERMINAL"] = 1,
	["LAND"]     = 2,
	["TAXI"]     = 3,
}

-- this is really the template type, it has no bearing on the underlying
-- object used
enum.assetType = {
	["INVALID"]     = 0,
	-- resource types
	["AMMODUMP"]    = 1,
	["FUELDUMP"]    = 2,
	["PORT"]        = 3,
	["FACILITY"]    = 4,
	["BUNKER"]      = 4,
	["CHECKPOINT"]  = 4,
	["FACTORY"]     = 4,
	["C2"]          = 5,
	["FOB"]         = 6,

	-- strategic assets
	["MISSILE"]     = 10,
	["OCA"]         = 11,

	-- air defense
	["BASEDEFENSE"] = 20,
	["EWR"]         = 21,
	["SAM"]         = 22,
	["SHORAD"]      = 23,

	-- HQ's / bases
	["AIRBASE"]        = 31,
	["SQUADRONPLAYER"] = 32,
	["SQUADRON"]       = 32,

	-- tactical land
	["GROUND"]        = 41,
	["LOGISTICS"]     = 41,
	["SPECIALFORCES"] = 41,
	["JTAC"]          = 42,

	-- tactical sea
	["SEA"]         = 51,
	["CV"]          = 52,

	-- tactical air
	["AIRPLANE"]    = 61,
	["HELO"]        = 62,

	-- players
	["PLAYER"]      = 71,

	-- control primitives
	["SCRIPT"]      = 101,  -- no agent is associated, it is just a
				-- template that spawns DCS objects
	["NODE"]        = 102,
}

enum.missionType = {
	["CAS"]        = 1,
	["CAP"]        = 2,
	["STRIKE"]     = 3,
	["SEAD"]       = 4,
	["BAI"]        = 5,
	["OCA"]        = 6,
	["ARMEDRECON"] = 7,
}

enum.squawkMissionType = {
	[enum.missionType.CAP]        = 2,
	[enum.missionType.SEAD]       = 3,
	[enum.missionType.CAS]        = 5,
	[enum.missionType.STRIKE]     = 5,
	[enum.missionType.BAI]        = 5,
	[enum.missionType.OCA]        = 5,
	[enum.missionType.ARMEDRECON] = 5,
}

enum.squawkMissionSubType = {
	[enum.missionType.STRIKE]     = 0,
	[enum.missionType.OCA]        = 0,
	[enum.missionType.BAI]        = 1,
	[enum.missionType.ARMEDRECON] = 2,
	[enum.missionType.CAS]        = 3,
}

for _, msntype in pairs(enum.missionType) do
	assert(enum.squawkMissionType[msntype],
		"not all mission types are mapped to squawk codes")
end

enum.assetClass = {
	["INITIALIZE"] = {
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
		[enum.assetType.LOGISTICS]     = true,
	},
	-- strategic list is used in calculating ownership of a region
	-- among other things
	["STRATEGIC"] = {
		[enum.assetType.AMMODUMP]    = true,
		[enum.assetType.FUELDUMP]    = true,
		[enum.assetType.C2]          = true,
		[enum.assetType.EWR]         = true,
		[enum.assetType.MISSILE]     = true,
		[enum.assetType.PORT]        = true,
		[enum.assetType.SAM]         = true,
		[enum.assetType.FACILITY]    = true,
		[enum.assetType.BUNKER]      = true,
		[enum.assetType.CHECKPOINT]  = true,
		[enum.assetType.FACTORY]     = true,
		[enum.assetType.AIRBASE]     = true,
		[enum.assetType.FOB]         = true,
	},
	["AGENTS"] = {
	},
	["HEADQUARTERS"] = {
		--[enum.assetType.SQUADRON] = true,
	},
}

enum.missionTypeMap = {
	[enum.assetType.AMMODUMP]	= enum.missionType.STRIKE,
	[enum.assetType.FUELDUMP]	= enum.missionType.STRIKE,
	[enum.assetType.C2]		= enum.missionType.STRIKE,
	[enum.assetType.MISSILE]	= enum.missionType.STRIKE,
	[enum.assetType.PORT]		= enum.missionType.STRIKE,
	[enum.assetType.FACILITY]	= enum.missionType.STRIKE,
	[enum.assetType.BUNKER]		= enum.missionType.STRIKE,
	[enum.assetType.CHECKPOINT]	= enum.missionType.STRIKE,
	[enum.assetType.FACTORY]	= enum.missionType.STRIKE,
	[enum.assetType.EWR]		= enum.missionType.SEAD,
	[enum.assetType.SAM]		= enum.missionType.SEAD,
	[enum.assetType.SHORAD]		= enum.missionType.SEAD,
	[enum.assetType.OCA]		= enum.missionType.OCA,
	[enum.assetType.AIRBASE]	= enum.missionType.OCA,
	[enum.assetType.LOGISTICS]	= enum.missionType.BAI,
	[enum.assetType.JTAC]		= enum.missionType.CAS,
	[enum.assetType.SPECIALFORCES]	= enum.missionType.ARMEDRECON,
	[enum.assetType.FOB]		= enum.missionType.ARMEDRECON,
	[enum.assetType.SEA]		= enum.missionType.SEA,
}

enum.missionResult = {
	["ABORT"]   = 0,
	["TIMEOUT"] = 1,
	["SUCCESS"] = 2,
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
	["REQUESTREARM"]    = 13,
}

enum.weaponCategory = {
	["AA"] = 1,
	["AG"] = 2,
}

enum.WPNINFCOST = 5000
enum.UNIT_CAT_SCENERY = Unit.Category.STRUCTURE + 1

local eventbase = world.event.S_EVENT_MAX + 2000
enum.event = {
	["DCT_EVENT_DEAD"]           = eventbase + 1,
	["DCT_EVENT_HIT"]            = eventbase + 2,
	["DCT_EVENT_OPERATIONAL"]    = eventbase + 3,
	["DCT_EVENT_CAPTURED"]       = eventbase + 4,
	["DCT_EVENT_IMPACT"]         = eventbase + 5,
	["DCT_EVENT_ADD_ASSET"]      = eventbase + 6,
	["DCT_EVENT_GOAL_COMPLETE"]  = eventbase + 7,
	["DCT_EVENT_MISSION_START"]  = eventbase + 8,
	["DCT_EVENT_MISSION_UPDATE"] = eventbase + 9,
	["DCT_EVENT_MISSION_DONE"]   = eventbase + 10,
	["DCT_EVENT_MISSION_JOIN"]   = eventbase + 11,
	["DCT_EVENT_MISSION_LEAVE"]  = eventbase + 12,
	["DCT_EVENT_PLAYER_KICK"]    = eventbase + 13,
	["DCT_EVENT_PLAYER_JOIN"]    = eventbase + 14,
}

enum.kickCode = require("dct.libs.kickinfo").kickCode

return enum
