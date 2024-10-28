-- SPDX-License-Identifier: LGPL-3.0

--- Define some basic global enumerations for DCT.

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
--TODO: reorganize type values so the lower 4 bits are dedicated to
-- subtypes and the upper 4 bits are major types with all F's being
-- an invalid type.
enum.assetType = {
	["INVALID"]     = 256, -- 0x100

	-- Navigation points in the DCT object space they can also
	-- be smartobjects and do things like transmit a beacon.
	["NODE"]        = 00, -- 0x00

	-- resource types supply resources to its commander; resources
	-- can be one or all of: ammo, fuel, supply, intel
	["RESOURCE"]    = 16, -- 0x10
	["AMMODUMP"]    = 17,
	["FUELDUMP"]    = 18,
	["C2"]          = 19,
	["BUNKER"]      = 20,
	["CHECKPOINT"]  = 21,

	-- Base assets accept character objects from an HQ and spawn
	-- the characters into the world according to the base's specific
	-- criteria
	["SPAWNPOINT"]  = 32, -- 0x20
	["ARMYBASE"]    = 33,
	["AIRBASE"]     = 34,
	["PORT"]        = 35,
	["CV"]          = 36,
	["HELOCARRIER"] = 37,
	["FARP"]        = 38,

	-- Headquarters are children of Bases they are also the only
	-- Agents the commander sends requests to.
	["SQUADRON"]    = 48, -- 0x30
	["ARMYGROUP"]   = 49,
	["FLEET"]       = 50,

	-- tactical units are the "game pieces", some can move and some
	-- just occupy an area defined by their template.
	-- Ground, Air, and Ship unit groups are split up into different
	-- spaces.
	["GROUNDGROUP"] = 64, -- 0x40
	["INFANTRY"]    = 65,
	["JTAC"]        = 66,
	["PILOT"]       = 67,
	["ARMOR"]       = 68,
	["MECH"]        = 69,
	["ARTILLERY"]   = 70,
	["EWR"]         = 71,
	["SAM"]         = 72,
	["SHORAD"]      = 73,

	["AIRGROUP"]    = 80, -- 0x50
	["AIRPLANE"]    = 81,
	["HELO"]        = 82,

	["SHIP"]        = 96, -- 0x60

	-- players
	["PLAYER"]      = 112, -- 0x70
}

--TODO: reorganize type values so the lower 4 bits are dedicated to
-- subtypes and the upper 4 bits are major types with all F's being
-- an invalid type.
enum.missionType = {
	["INVALID"]    = 256, -- 0x100
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
