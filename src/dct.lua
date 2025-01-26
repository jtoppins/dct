-- SPDX-License-Identifier: LGPL-3.0

require("libs")

-- Can be changed to point to the game's install path, it depends
-- on where the mod is installed, the game directory or a user's
-- savedgames directory. Use `lfs.currentdir()` to point to where
-- the game is installed.
local BASEPATH = lfs.writedir()

local dct = {
    _VERSION = "%VERSION%",
    _DESCRIPTION = "DCT: DCS Dynamic Campaign Tools",
    _COPYRIGHT = "Copyright (c) 2019-2020,2024 Jonathan Toppins"
}

_G.dct = dct
-- Where the DCT code is stored
dct.modpath = libs.utils.join_paths(BASEPATH, "Mods", "Tech", "DCT")
-- DCT config file path, always stored in savedgames dir
dct.cfgpath = libs.utils.join_paths(lfs.writedir(), "Config", "dct.cfg")
-- DCT Theaters are always stored in the savedgames directory
dct.theaterpath = libs.utils.join_paths(lfs.writedir(), "DCT", "theaters")
-- DCT Templates are always stored in the savedgames directory
dct.templatepath = libs.utils.join_paths(lfs.writedir(), "DCT", "templates")

dct.settings  = require("dct.settings")
dct.enum      = require("dct.enum")
dct.event     = require("dct.event")
dct.libs      = require("dct.libs")
dct.ui        = require("dct.ui")
dct.ai        = require("dct.ai")
dct.agent     = require("dct.agent")
dct.systems   = require("dct.systems")
dct.Theater   = require("dct.Theater")

env.info(dct._DESCRIPTION.."; "..dct._COPYRIGHT.."; version: "..
    dct._VERSION)
env.info("DCT: dct.modpath: "..tostring(dct.modpath))
env.info("DCT: dct.settings.server: "..
	 libs.json:encode_pretty(dct.settings.server))
return dct
