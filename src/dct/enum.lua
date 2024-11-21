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
	["RUNWAY"]  = 6,
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
	["SPAWNPOINT"]  = 27,

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
	["MOVETO"]     = 1,

	-- Guarding based missions, just with different threat and
	-- target sets
	["GUARD"]      = 20,
	["JTAC"]       = 21,
	["AFAC"]       = 22,
	["CAS"]        = 23,
	["CAP"]        = 24,
	["TANKER"]     = 25,
	["AWACS"]      = 26,

	-- Attack based missions
	["ATTACK"]     = 30,
	["STRIKE"]     = 31,
	["BAI"]        = 32,
	["OCA"]        = 33,
	["ANTISHIP"]   = 34,
	["DEAD"]       = 35,
	["SWEEP"]      = 36,
	["AREASTRIKE"] = 37,

	-- Search based missions
	["SEARCH"]     = 40,
	["RECON"]      = 41,
	["INTERCEPT"]  = 42,

	-- Escort based missions
	["ESCORT"]     = 50,
	["SEAD"]       = 51,
	["FIGHTERCOVER"] = 52,

	-- Transport based missions
	["TRANSPORT"]  = 60,
	["CSAR"]       = 61,
	["RESUPPLY"]   = 62,
}

--- Requests that Agents can send to other agents.
enum.requestType = {
	["REARM"]      = 1,
}

enum.UNIT_CAT_SCENERY = Unit.Category.STRUCTURE + 1
enum.kickCode = require("dct.libs.kickinfo").kickCode

return enum
