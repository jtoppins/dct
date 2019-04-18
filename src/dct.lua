-- SPDX-License-Identifier: LGPL-3.0

local _G   = _G
local _ENV = nil
local dct = {
    _VERSION = "0.1",
    _DESCRIPTION = "DCT: DCS Dynamic Campaign Tools",
    _COPYRIGHT = "Copyright (c) 2019 Jonathan Toppins"
}

dct.init     = require("dct.init")
dct.template = require("dct.template")

_G.dct = dct
return dct
