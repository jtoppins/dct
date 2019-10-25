-- SPDX-License-Identifier: LGPL-3.0

local _G   = _G
local _ENV = nil
local dct = {
    _VERSION = "0.1",
    _DESCRIPTION = "DCT: DCS Dynamic Campaign Tools",
    _COPYRIGHT = "Copyright (c) 2019 Jonathan Toppins"
}

_G.dct = dct
dct.settings  = require("dct.settings")(dctsettings)
dct.enum      = require("dct.enum")
dct.init      = require("dct.init")
dct.Template  = require("dct.Template")
dct.Region    = require("dct.Region")
dct.Theater   = require("dct.Theater")
dct.Asset     = require("dct.Asset")
dct.Profiler  = require("dct.Profiler")
dct.DebugStats= require("dct.DebugStats")

require("dct.ui.groupmenu")()

return dct
