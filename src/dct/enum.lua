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

-- This is really the template type, it has no bearing on the underlying
-- object used. The values of the lower 4 bits are dedicated to
-- subtypes and the upper 4 bits are major types with 0x100 being
-- an invalid type.
enum.assetType = {
	["INVALID"]     = 0,

	-- 0b0000 0000 0000 0000
	--    ^     ^    ^    ^--- subtype
	--    |     |    +---- Base types (1) Resource, (2) Base, (4) HQ
	--    |     +----- Unit types (1) Ground, (2) Air, (4) Ship
	--
	-- resource types supply resources to its commander; resources
	-- can be one or all of: ammo, fuel, supply, intel
	["RESOURCE"]    = 16, -- 0x10
	["AMMODUMP"]    = 17,
	["FUELDUMP"]    = 18,
	["C2"]          = 19,

	-- Base assets accept character objects from an HQ and spawn
	-- the characters into the world according to the base's specific
	-- criteria
	["BASE"]        = 32, -- 0x20
	["AIRBASE"]     = 33,
	["FARP"]        = 34,
	["CV"]          = 35,
	["HELOCARRIER"] = 36,

	-- Headquarters are based at Bases and are also the only
	-- Agents the commander sends requests to.
	["HQ"]          = 48, -- 0x40
	["SQUADRON"]    = 49,

	-- tactical units are the "game pieces", some can move and some
	-- just occupy an area defined by their template.
	-- Ground, Air, and Ship unit groups are split up into different
	-- spaces.
	["GROUND_UNIT"] = 256, -- 0x100
	["EWR"]         = 257,
	["SAM"]         = 258,
	["SHORAD"]      = 259,

	["AIR_UNIT"]    = 512, -- 0x200
	["AIRPLANE"]    = 513,
	["HELO"]        = 514,

	["SHIP_UNIT"]   = 1024, -- 0x400
}

enum.missionType = {
	-- 0b0000 0000 0000 0000
	--    ^     ^    ^    ^--- mission subtype
	--    |     |    +---- types (1) MoveTo, (2) Guard, (4) Attack,
	--    |     |               (8) Search
	--    |     +----- types (1) Escort, (2) Transport

	["INVALID"]    = 0,
	["MOVETO"]     = 16, -- 0x10

	-- Guarding based missions, just with different threat and
	-- target sets
	["GUARD"]      = 32, -- 0x20
	["JTAC"]       = 33,
	["AFAC"]       = 34,
	["CAS"]        = 35,
	["CAP"]        = 36,
	["TANKER"]     = 37,
	["AWACS"]      = 38,

	-- Attack based missions
	["ATTACK"]     = 64, -- 0x40
	["STRIKE"]     = 65,
	["BAI"]        = 66,
	["OCA"]        = 67,
	["ANTISHIP"]   = 68,
	["DEAD"]       = 69,
	["SWEEP"]      = 70,
	["AREASTRIKE"] = 71,

	-- Search based missions
	["SEARCH"]     = 128, -- 0x80
	["RECON"]      = 129,
	["INTERCEPT"]  = 130,

	-- Escort based missions
	["ESCORT"]     = 256, -- 0x100
	["SEAD"]       = 257,
	["FIGHTERCOVER"] = 258,

	-- Transport based missions
	["TRANSPORT"]  = 512, -- 0x200
	["CSAR"]       = 513,
	["RESUPPLY"]   = 514,
}

--- Requests that Agents can send to other agents.
enum.requestType = {
	["REARM"]      = 1,
}

enum.UNIT_CAT_SCENERY = Unit.Category.STRUCTURE + 1
enum.kickCode = require("dct.libs.kickinfo").kickCode

return enum
