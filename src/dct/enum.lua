--- SPDX-License-Identifier: LGPL-3.0
--
-- Define some basic global enumerations for DCT.

local enum = {}

enum.DEFAULTCODENAME = "default codename"
enum.DEFAULTNAME  = "auto"
enum.DEFAULTRANGE = -1

enum.objtype = {
	["UNIT"]    = 1,
	["STATIC"]  = 2,
	["GROUP"]   = 3,
	["SCENERY"] = 4,
	["AGENT"]   = 5,
}

-- this is really the template type, it has no bearing on the underlying
-- object used
enum.assetType = {
	["INVALID"]     = 0,
	-- resource types
	["RESOURCE"]    = 1,  -- an agent that supplies resources to its
			      -- commander; resources can be one or all
			      -- of: ammo, supply
	["AMMODUMP"]    = 2,
	["FUELDUMP"]    = 3,
	["C2"]          = 4,
	["BUNKER"]      = 5,
	["CHECKPOINT"]  = 6,

	-- strategic assets
	["MISSILE"]     = 11,
	["OCA"]         = 12,

	-- Base assets accept character objects from an HQ and spawn
	-- the characters into the world according to the base's specific
	-- criteria
	["ARMYBASE"]    = 21,
	["AIRBASE"]     = 22,
	["PORT"]        = 23,
	["CV"]          = 24,
	["HELOCARRIER"] = 25,
	["FARP"]        = 26,

	-- Headquarters are children of Bases they are also the only
	-- Agents the commander sends requests to.
	["SQUADRON"]    = 31,
	["ARMYGROUP"]   = 32,
	["FLEET"]       = 33,

	-- tactical units are the "game pieces", some can move and some
	-- just occupy an area defined by their template.
	["GROUND"]      = 41,
	["JTAC"]        = 42,
	["AIRPLANE"]    = 43,
	["HELO"]        = 44,
	["BASEDEFENSE"] = 45,
	["EWR"]         = 46,
	["SAM"]         = 47,
	["SHORAD"]      = 48,
	["INFANTRY"]    = 49,
	["PILOT"]       = 50,
	["SHIP"]        = 51,

	-- players
	["PLAYER"]      = 71,

	-- control primitives
	["SCRIPT"]      = 101,  -- no agent is associated, it is just a
				-- template that spawns DCS objects, the
				-- objects are not even tracked or targetable
	["NODE"]        = 102,  -- navigation points in the DCT object space
				-- they can also be smartobjects and do things
				-- like transmit a beacon
}

enum.assetTypeDeprecated = {
	["FACTORY"]        = 1,
	["FACILITY"]       = 1,
	["FOB"]            = 21,
	["SQUADRONPLAYER"] = 31,
	["LOGISTICS"]      = 41,
	["SPECIALFORCES"]  = 41,
}

enum.missionType = {
	["INVALID"]    = 0,
	["MOVETO"]     = 10,
	["JTAC"]       = 11,
	["AFAC"]       = 12,

	["GUARD"]      = 20,
	["CAS"]        = 21,
	["CAP"]        = 22,
	["SEAD"]       = 23,
	["TANKER"]     = 24,
	["AWACS"]      = 25,

	["ATTACK"]     = 30,
	["STRIKE"]     = 31,
	["BAI"]        = 32,
	["OCA"]        = 33,
	["ANTISHIP"]   = 34,
	["DEAD"]       = 35,
	["SWEEP"]      = 36,

	["SEARCH"]     = 40,
	["RECON"]      = 41,
	["INTERCEPT"]  = 42,
	["ESCORT"]     = 43,

	["TRANSPORT"]  = 50,
	["CSAR"]       = 51,
	["RESUPPLY"]   = 52,
}

--- Requests that Agents can send to other agents.
enum.requestType = {
	["REARM"]      = 1,
}

enum.parkingType = {
	["GROUND"]      = 1,
	["RUNWAY"]      = 16,
	["HELO"]        = 40,
	["HARDSHELTER"] = 68,
	["AIRPLANE"]    = 72,
	["OPENAIR"]     = 104,
}

enum.airbaseTakeoff = {
	["INAIR"]   = 1,
	["RUNWAY"]  = 2,
	["PARKING"] = 3,
	["GROUND"]  = 4,
}

enum.airbaseRecovery = {
	["TERMINAL"] = 1,
	["LAND"]     = 2,
	["TAXI"]     = 3,
}

enum.weaponCategory = {
	["AA"] = 1,
	["AG"] = 2,
	["GUN"] = 3,
}

enum.WPNINFCOST = 5000
enum.UNIT_CAT_SCENERY = Unit.Category.STRUCTURE + 1

local eventbase = world.event.S_EVENT_MAX + 2000
enum.event = {
	["DCT_EVENT_DEAD"]           = eventbase + 1,
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
	["DCT_EVENT_DEPARTURE"]      = eventbase + 15,
	["DCT_EVENT_AGENT_REQUEST"]  = eventbase + 16,
}

enum.kickCode = require("dct.libs.kickinfo").kickCode

return enum
