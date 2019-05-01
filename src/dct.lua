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
dct.init      = require("dct.init")
dct.Template  = require("dct.template")
dct.Region    = require("dct.region")
dct.Theater   = require("dct.theater")
dct.Objective = require("dct.objective")
dct.GameState = require("dct.gamestate")

return dct
