#!/usr/bin/lua

--[[
-- SPDX-License-Identifier: LGPL-3.0
--]]

require("dcttestlibs")
local utils = require("libs.utils")
dctsettings = {
	["missioncfg"] = true,
}
require("dct")

local function main()
	local cfgvalidation = {
		["theaterpath"] = lfs.tempdir()..utils.sep.."theater",
		["debug"]       = false,
		["profile"]     = false,
		["statepath"]   = lfs.writedir()..utils.sep..env.mission.theatre..
			"_"..env.getValueDictByKey(env.mission.sortie)..".state",
		["servercfg"]   = true,
		["missioncfg"]  = true,
		["spawndead"]   = false,
	}

	for k, v in pairs(cfgvalidation) do
		assert(dct.settings[k] == v, "dct.settings unexpected field '"..k.."'")
	end

	for k, v in pairs(dct.settings) do
		assert(cfgvalidation[k] == v, "dct.settings unexpected field '"..k.."'")
	end

	return 0
end

os.exit(main())
