--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Defines kick codes and associated error messages.
--]]

local enum = {}

enum.kickCode = {
	["NOKICK"]  = 0,
	["UNKNOWN"] = 1,
	["SETUP"]   = 2,
	["EMPTY"]   = 3,
	["DEAD"]    = 4,
	["LOADOUT"] = 5,
	["MISSION"] = 6,
}

enum.kickReason = {
	[enum.kickCode.NOKICK] =
		"no kick requested, please report a. bug",
	[enum.kickCode.UNKNOWN] =
		"unknown reason, please report a bug.",
	[enum.kickCode.SETUP] =
		"slots being setup, please wait 1 minute.",
	[enum.kickCode.EMPTY] =
		"slot empty, please report a bug",
	[enum.kickCode.DEAD] =
		"you died, re-slot to continue.",
	[enum.kickCode.LOADOUT] =
		"payload violation, you attempted to takeoff with restricted "..
		"weapons. Check the loadout limits.",
	[enum.kickCode.MISSION] =
		"no mission assigned. Must have a mission assigned.",
}

return enum
