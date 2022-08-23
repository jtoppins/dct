-- SPDX-License-Identifier: LGPL-3.0

local dct = {
    _VERSION = "%VERSION%",
    _DESCRIPTION = "DCT: DCS Dynamic Campaign Tools",
    _COPYRIGHT = "Copyright (c) 2019-2020 Jonathan Toppins"
}

_G.dct = dct
dct.settings  = require("dct.settings")()
dct.Logger    = require("dct.libs.Logger")
dct.init      = require("dct.init")
dct.Theater   = require("dct.Theater")
if os.getenv("DCT_SRC_ROOT") then
	dct.modpath = os.getenv("DCT_SRC_ROOT").."/src"
end

env.info(dct._DESCRIPTION.."; "..dct._COPYRIGHT.."; version: "..
    dct._VERSION)
return dct
