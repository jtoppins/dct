-- SPDX-License-Identifier: LGPL-3.0

--- Default aircraft-specific settings.

local function UNITS_IMPERIAL_MBAR_DDM()
	return {
		["gridfmt"] = "ddm",
		["pressurefmt"] = "mbar",
	}
end

local function UNITS_IMPERIAL_MGRS()
	return {
		["gridfmt"] = "mgrs",
	}
end

local function UNITS_METRIC()
	return {
		["distfmt"]  = "kilometer",
		["altfmt"]   = "meter",
		["speedfmt"] = "kph",
		["tempfmt"]  = "C",
	}
end

local function UNITS_METRIC_HPA()
	local u = UNITS_METRIC()
	u.pressurefmt = "hpa"
	return u
end

local function UNITS_METRIC_INHG()
	local u = UNITS_METRIC()
	u.pressurefmt = "inhg"
	return u
end

local function UNITS_METRIC_MMHG()
	local u = UNITS_METRIC()
	u.pressurefmt = "mmhg"
	return u
end

local function UNITS_METRIC_MMHG_DDM()
	local u = UNITS_METRIC()
	u.pressurefmt = "mmhg"
	u.gridfmt     = "ddm"
	return u
end

local playeruicfg = {
	["A-10A"]         = UNITS_IMPERIAL_MGRS(),
	["A-10C"]         = UNITS_IMPERIAL_MGRS(),
	["A-10C_2"]       = UNITS_IMPERIAL_MGRS(),
	["AH-64D_BLK_II"] = {
		gridfmt = "mgrs",
		distfmt = "kilometer",
	},
	["AJS37"]         = UNITS_METRIC_HPA(),
	["Bf-109K-4"]     = UNITS_METRIC_HPA(),
	["F-5E-3"]        = {
		gridfmt = "ddm",
	},
	["F-14A-95-GR"]   = {
		gridfmt = "ddm",
	},
	["F-14A-135-GR"]  = {
		gridfmt = "ddm",
	},
	["F-14B"]         = {
		gridfmt = "ddm",
	},
	["F-15ESE"]       = {
		gridfmt = "ddm",
	},
	["F-16C_50"]      = {
		gridfmt = "ddm",
	},
	["FA-18C_hornet"] = {
		gridfmt = "ddm",
	},
	["FW-190A8"]      = UNITS_METRIC_HPA(),
	["FW-190D9"]      = UNITS_METRIC_HPA(),
	["I-16"]          = UNITS_METRIC_MMHG(),
	["Ka-50"]         = UNITS_METRIC_MMHG_DDM(),
	["Ka-50_3"]       = {
		gridfmt = "ddm",
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
		gridfmt = "ddm",
	},
	["SA342L"]        = {
		gridfmt = "ddm",
	},
	["Su-25"]         = UNITS_METRIC_MMHG(),
	["Su-25T"]        = UNITS_METRIC_MMHG(),
	["Su-27"]         = UNITS_METRIC_MMHG(),
	["Su-33"]         = UNITS_METRIC_HPA(),
	["Yak-52"]        = UNITS_METRIC_MMHG(),
	["UH-1H"]         = {
		gridfmt = "ddm",
	},
}

return playeruicfg
