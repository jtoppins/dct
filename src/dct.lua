-- SPDX-License-Identifier: LGPL-3.0

require("libs")

local dct = {
    _VERSION = "%VERSION%",
    _DESCRIPTION = "DCT: DCS Dynamic Campaign Tools",
    _COPYRIGHT = "Copyright (c) 2019-2020,2024 Jonathan Toppins"
}

_G.dct = dct
dct.modpath   = lfs.writedir()..libs.utils.join_paths("Mods", "Tech", "DCT")
dct.settings  = require("dct.settings")
dct.enum      = require("dct.enum")
dct.libs      = require("dct.libs")
dct.systems   = require("dct.systems")

env.info(dct._DESCRIPTION.."; "..dct._COPYRIGHT.."; version: "..
    dct._VERSION)
env.info("DCT: dct.modpath: "..tostring(dct.modpath))
env.info("DCT: dct.settings.server: "..
	 libs.json:encode_pretty(dct.settings.server))
return dct
