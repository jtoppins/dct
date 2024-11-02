-- SPDX-License-Identifier: LGPL-3.0

--- Default aircraft-specific settings.
-- @module dct.settings.theater.ui

local uihuman  = require("dct.ui.human")

local player_ui_default = {
	["gridfmt"]     = uihuman.posfmt.DMS,
	["distfmt"]     = uihuman.distancefmt.NAUTICALMILE,
	["altfmt"]      = uihuman.altfmt.FEET,
	["speedfmt"]    = uihuman.speedfmt.KNOTS,
	["pressurefmt"] = uihuman.pressurefmt.INHG,
	["tempfmt"]     = uihuman.tempfmt.F,
}

local function UNITS_IMPERIAL_MBAR_DDM()
	return setmetatable({
		["gridfmt"] = uihuman.posfmt.DDM,
		["pressurefmt"] = uihuman.pressurefmt.MBAR,
	}, {
		__index = player_ui_default,
	})
end

local function UNITS_IMPERIAL_MGRS()
	return setmetatable({
		["gridfmt"] = uihuman.posfmt.MGRS,
	}, {
		__index = player_ui_default,
	})
end

local function UNITS_METRIC()
	return setmetatable({
		["distfmt"]  = uihuman.distancefmt.KILOMETER,
		["altfmt"]   = uihuman.altfmt.METER,
		["speedfmt"] = uihuman.speed.KPH,
		["tempfmt"]  = uihuman.tempfmt.C,
	}, {
		__index = player_ui_default,
	})
end

local function UNITS_METRIC_HPA()
	local u = UNITS_METRIC()
	u.pressurefmt = uihuman.pressurefmt.HPA
	return u
end

local function UNITS_METRIC_INHG()
	local u = UNITS_METRIC()
	u.pressurefmt = uihuman.pressurefmt.INHG
	return u
end

local function UNITS_METRIC_MMHG()
	local u = UNITS_METRIC()
	u.pressurefmt = uihuman.pressurefmt.MMHG
	return u
end

local function UNITS_METRIC_MMHG_DDM()
	local u = UNITS_METRIC()
	u.pressurefmt = uihuman.pressurefmt.MMHG
	u.gridfmt     = uihuman.posfmt.DDM
	return u
end

local _ui = {
	["A-10A"]         = UNITS_IMPERIAL_MGRS(),
	["A-10C"]         = UNITS_IMPERIAL_MGRS(),
	["A-10C_2"]       = UNITS_IMPERIAL_MGRS(),
	["AH-64D_BLK_II"] = {
		gridfmt = uihuman.posfmt.MGRS,
		distfmt = uihuman.distancefmt.KILOMETER,
	},
	["AJS37"]         = UNITS_METRIC_HPA(),
	["Bf-109K-4"]     = UNITS_METRIC_HPA(),
	["F-5E-3"]        = {
		gridfmt = uihuman.posfmt.DDM,
	},
	["F-14A-95-GR"]   = {
		gridfmt = uihuman.posfmt.DDM,
	},
	["F-14A-135-GR"]  = {
		gridfmt = uihuman.posfmt.DDM,
	},
	["F-14B"]         = {
		gridfmt = uihuman.posfmt.DDM,
	},
	["F-15ESE"]       = {
		gridfmt = uihuman.posfmt.DDM,
	},
	["F-16C_50"]      = {
		gridfmt = uihuman.posfmt.DDM,
	},
	["FA-18C_hornet"] = {
		gridfmt = uihuman.posfmt.DDM,
	},
	["FW-190A8"]      = UNITS_METRIC_HPA(),
	["FW-190D9"]      = UNITS_METRIC_HPA(),
	["I-16"]          = UNITS_METRIC_MMHG(),
	["Ka-50"]         = UNITS_METRIC_MMHG_DDM(),
	["Ka-50_3"]       = {
		gridfmt = uihuman.posfmt.DDM,
	},
	["M-2000C"]       = UNITS_IMPERIAL_MBAR_DDM(),
	["Mi-8MT"]        = UNITS_METRIC_MMHG_DDM(),
	["Mi-24P"]        = UNITS_METRIC_MMHG(),
	["Mirage-F1BE"]   = UNITS_IMPERIAL_MBAR_DDM(),
	["Mirage-F1CE"]   = UNITS_IMPERIAL_MBAR_DDM(),
	["Mirage-F1EE"]   = UNITS_IMPERIAL_MBAR_DDM(),
	["Mirage-F1M"]    = UNITS_IMPERIAL_MBAR_DDM(),
	["MiG-15bis"]     = UNITS_METRIC_MMHG(),
	["MiG-19P"]       = UNITS_METRIC_MMHG(),
	["MiG-21Bis"]     = UNITS_METRIC_MMHG(),
	["MiG-29A"]       = UNITS_METRIC_MMHG(),
	["MiG-29S"]       = UNITS_METRIC_MMHG(),
	["MiG-29G"]       = UNITS_METRIC_INHG(),
	["SA342M"]        = {
		gridfmt = uihuman.posfmt.DDM,
	},
	["SA342L"]        = {
		gridfmt = uihuman.posfmt.DDM,
	},
	["Su-25"]         = UNITS_METRIC_MMHG(),
	["Su-25T"]        = UNITS_METRIC_MMHG(),
	["Su-27"]         = UNITS_METRIC_MMHG(),
	["Su-33"]         = UNITS_METRIC_HPA(),
	["Yak-52"]        = UNITS_METRIC_MMHG(),
	["UH-1H"]         = {
		gridfmt = uihuman.posfmt.DDM,
	},
}
setmetatable(_ui, {
	__index = function(--[[tbl, key]])
		return player_ui_default
	end
})

return _ui
