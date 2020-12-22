--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- enum definitions that are not exposed via the mission environment,
-- but are critical to getting correct behaviour from DCS.
--]]

local enum = {}
enum.TASKTYPE = {
	["COMMAND"] = 1,
	["OPTION"]  = 2,
	["TASK"]    = 3,
}

enum.BEACON = {}
enum.BEACON.TYPE = {
	["NULL"]                      = 0,
	["VOR"]                       = 1,
	["DME"]                       = 2,
	["VOR_DME"]                   = 3,
	["TACAN"]                     = 4,
	["VORTAC"]                    = 5,
	["HOMER"]                     = 8,
	["RSBN"]                      = 128,
	["BROADCAST_STATION"]         = 1024,
	["AIRPORT_HOMER"]             = 4104,
	["AIRPORT_HOMER_WITH_MARKER"] = 4136,
	["ILS_FAR_HOMER"]             = 16408,
	["ILS_NEAR_HOMER"]            = 16456,
	["ILS_LOCALIZER"]             = 16640,
	["ILS_GLIDESLOPE"]            = 16896,
	["PRMG_LOCALIZER"]            = 33024,
	["PRMG_GLIDESLOPE"]           = 33280,
	["ICLS_LOCALIZER"]            = 131328,
	["ICLS_GLIDESLOPE"]           = 131584,
	["NAUTICAL_HOMER"]            = 65536,
}

enum.BEACON.SYSTEM = {
	["PAR_10"]              = 1,
	["RSBN_4H"]             = 2,
	["TACAN"]               = 3,
	["TACAN_TANKER_MODE_X"] = 4,
	["TACAN_TANKER_MODE_Y"] = 5,
	["VOR"]                 = 6,
	["ILS_LOCALIZER"]       = 7,
	["ILS_GLIDESLOPE"]      = 8,
	["PRMG_LOCALIZER"]      = 9,
	["PRMG_GLIDESLOPE"]     = 10,
	["BROADCAST_STATION"]   = 11,
	["VORTAC"]              = 12,
	["TACAN_AA_MODE_X"]     = 13,
	["TACAN_AA_MODE_Y"]     = 14,
	["VORDME"]              = 15,
	["ICLS_LOCALIZER"]      = 16,
	["ICLS_GLIDESLOPE"]     = 17,
	["TACAN_MOBILE_MODE_X"] = 18,
	["TACAN_MOBILE_MODE_Y"] = 19,
}

enum.BEACON.TACANMODE = {
	["X"] = "X",
	["Y"] = "Y",
}

enum.FORMATION = {}
enum.FORMATION.TYPE = {
	["NO_FORMATION"]              = 0,
	["LINE_ABREAST"]              = 1,
	["TRAIL"]                     = 2,
	["WEDGE"]                     = 3,
	["ECHELON_RIGHT"]             = 4,
	["ECHELON_LEFT"]              = 5,
	["FINGER_FOUR"]               = 6,
	["SPREAD_FOUR"]               = 7,
	["HEL_WEDGE"]                 = 8,
	["HEL_ECHELON"]               = 9,
	["HEL_FRONT"]                 = 10,
	["HEL_COLUMN"]                = 11,
	["WW2_BOMBER_ELEMENT"]        = 12,
	["WW2_BOMBER_ELEMENT_HEIGHT"] = 13,
	["WW2_FIGHTER_VIC"]           = 14,
	["COMBAT_BOX"]                = 15,
	["JAVELIN_DOWN"]              = 16,
	["MODERN_BOMBER_ELEMENT"]     = 17,
	["MAX"]                       = 18
}

enum.FORMATION.DISTANCE = {
	["CLOSE"] = 1,
	["OPEN"]  = 2,
	["GROUP"] = 3,
}

enum.FORMATION.SIDE = {
	["RIGHT"] = 0,
	["LEFT"]  = 256,
}

enum.WEAPONFLAGS = {
	["NOWEAPON"]      = 0,

	-- Bombs
	["LGB"]           = 2^1,
	["TVGB"]          = 2^2,
	["SNSGB"]         = 2^3,
	["HEBOMB"]        = 2^4,
	["PENETRATOR"]    = 2^5,
	["NAPALMBOMB"]    = 2^6,
	["FAEBOMB"]       = 2^7,
	["CLUSTERBOMB"]   = 2^8,
	["DISPENCER"]     = 2^9,
	["CANDLEBOMB"]    = 2^10,
	["PARACHUTEBOMB"] = 2^31,

	-- Rockets
	["LIGHTROCKET"]   = 2^11,
	["MARKERROCKET"]  = 2^12,
	["CANDLEROCKET"]  = 2^13,
	["HEAVYROCKET"]   = 2^14,

	-- Missiles
	["ARM"]           = 2^15,
	["ASM"]           = 2^16,
	["ATGM"]          = 2^17,
	["FAFASM"]        = 2^18,
	["LASM"]          = 2^19,
	["TELEASM"]       = 2^20,
	["CRUISEMISSILE"] = 2^21,
	["ARM2"]          = 2^30,

	-- AAMs
	["SRAAM"]         = 2^22,
	["MRAAM"]         = 2^23,
	["LRAAM"]         = 2^24,
	["IR_AAM"]        = 2^25,
	["SAR_AAM"]       = 2^26,
	["AR_AAM"]        = 2^27,

	-- Guns
	["GUNPOD"]        = 2^28,
	["BUILTINGUN"]    = 2^29,

	-- Torpedo
	["TORPEDO"]       = 2^32,
}

enum.WEAPONFLAGS.GUIDEDBOMB      = enum.WEAPONFLAGS.LGB +
	enum.WEAPONFLAGS.TVGB +
	enum.WEAPONFLAGS.SNSGB
enum.WEAPONFLAGS.ANYUNGUIDEDBOMB = enum.WEAPONFLAGS.HEBOMB +
	enum.WEAPONFLAGS.PENETRATOR +
	enum.WEAPONFLAGS.NAPALMBOMB +
	enum.WEAPONFLAGS.FAEBOMB +
	enum.WEAPONFLAGS.CLUSTERBOMB +
	enum.WEAPONFLAGS.DISPENCER +
	enum.WEAPONFLAGS.CANDLEBOMB +
	enum.WEAPONFLAGS.PARACHUTEBOMB
enum.WEAPONFLAGS.ANYBOMB         = enum.WEAPONFLAGS.GUIDEDBOMB +
	enum.WEAPONFLAGS.ANYUNGUIDEDBOMB
enum.WEAPONFLAGS.ANYROCKET       = enum.WEAPONFLAGS.LIGHTROCKET +
	enum.WEAPONFLAGS.MARKERROCKET +
	enum.WEAPONFLAGS.CANDLEROCKET +
	enum.WEAPONFLAGS.HEAVYROCKET
enum.WEAPONFLAGS.GUIDEDASM       = enum.WEAPONFLAGS.LASM +
	enum.WEAPONFLAGS.TELEASM
enum.WEAPONFLAGS.TACTICALASM     = enum.WEAPONFLAGS.GUIDEDASM +
	enum.WEAPONFLAGS.FAFASM
enum.WEAPONFLAGS.ANYASM          = enum.WEAPONFLAGS.ARM +
	enum.WEAPONFLAGS.ASM +
	enum.WEAPONFLAGS.ATGM +
	enum.WEAPONFLAGS.FAFASM +
	enum.WEAPONFLAGS.GUIDEDASM +
	enum.WEAPONFLAGS.CRUISEMISSILE
enum.WEAPONFLAGS.ANYAAM          = enum.WEAPONFLAGS.SRAAM +
	enum.WEAPONFLAGS.MRAAM +
	enum.WEAPONFLAGS.LRAAM +
	enum.WEAPONFLAGS.IR_AAM +
	enum.WEAPONFLAGS.SAR_AAM +
	enum.WEAPONFLAGS.AR_AAM
enum.WEAPONFLAGS.ANYMISSILE      = enum.WEAPONFLAGS.ANYASM +
	enum.WEAPONFLAGS.ANYAAM
enum.WEAPONFLAGS.ANYAUTOMISSILE  = enum.WEAPONFLAGS.IR_AAM +
	enum.WEAPONFLAGS.ARM +
	enum.WEAPONFLAGS.ASM +
	enum.WEAPONFLAGS.FAFASM +
	enum.WEAPONFLAGS.CRUISEMISSILE
enum.WEAPONFLAGS.CANNONS         = enum.WEAPONFLAGS.GUNPOD +
	enum.WEAPONFLAGS.BUILTINGUN

return enum
