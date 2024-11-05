-- SPDX-License-Identifier: LGPL-3.0

local utils = require("libs.utils")

local dct = {
    _VERSION = "%VERSION%",
    _DESCRIPTION = "DCT: DCS Dynamic Campaign Tools",
    _COPYRIGHT = "Copyright (c) 2019-2020 Jonathan Toppins"
}

_G.dct = dct
dct.settings  = require("dct.settings")()
dct.Logger    = require("dct.libs.Logger")
dct.init      = require("dct.init")
dct.modpath   = lfs.writedir()..table.concat({"Mods", "Tech", "DCT"},
		utils.sep)
dct.Theater   = require("dct.Theater")

env.info(dct._DESCRIPTION.."; "..dct._COPYRIGHT.."; version: "..
    dct._VERSION)
env.info("DCT: dct.modpath: "..tostring(dct.modpath))
env.info("DCT: dct.settings.server: "..
	 require("libs.json"):encode_pretty(dct.settings.server))
return dct
