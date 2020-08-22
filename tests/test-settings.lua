#!/usr/bin/lua

--[[
-- SPDX-License-Identifier: LGPL-3.0
--]]

require("dcttestlibs")
local utils = require("libs.utils")
local dctutils = require("dct.utils")
dctsettings = {
	["missioncfg"] = true,
}
require("dct")

-- luacheck: ignore 561
local function main()
	local cfgvalidation = {
		["theaterpath"] = lfs.tempdir()..utils.sep.."theater",
		["debug"]       = false,
		["profile"]     = false,
		["statepath"]   = lfs.writedir()..utils.sep..env.mission.theatre..
			"_"..env.getValueDictByKey(env.mission.sortie)..".state",
		["servercfg"]   = true,
		["missioncfg"]  = true,
		["acgridfmt"] = {
			["Ka-50"]         = dctutils.posfmt.DDM,
			["M-2000C"]       = dctutils.posfmt.DDM,
			["A-10C"]         = dctutils.posfmt.MGRS,
			["AJS37"]         = dctutils.posfmt.DMS,
			["F-14B"]         = dctutils.posfmt.DDM,
			["FA-18C_hornet"] = dctutils.posfmt.DDM,
			["F-16C_50"]      = dctutils.posfmt.DDM,
			["UH-1H"]         = dctutils.posfmt.DDM,
			["Mi-8MT"]        = dctutils.posfmt.DDM,
			["F-5E-3"]        = dctutils.posfmt.DDM,
			["AV8BNA"]        = dctutils.posfmt.DDM,
			["SA342M"]        = dctutils.posfmt.DDM,
			["SA342L"]        = dctutils.posfmt.DDM,
			["A-10C_2"]       = dctutils.posfmt.MGRS,
		},
		["schedfreq"] = 2,
		["percentTimeAllowed"] = .3,
		["tgtfps"] = 75,
	}

	for k, v in pairs(cfgvalidation) do
		if k == "acgridfmt" then
			for ac, grid in pairs(v) do
				assert(grid == dct.settings[k][ac],
					"cfgvalidation."..k.."."..ac.." invalid value: "..grid)
			end
		-- luacheck: ignore 542
		elseif k == "codenamedb" or k == "atorestrictions" then
		else
			assert(dct.settings[k] == v,
				"cfgvalidation unexpected field '"..k.."'")
		end
	end

	for k, v in pairs(dct.settings) do
		if k == "acgridfmt" then
			for ac, grid in pairs(v) do
				assert(grid == cfgvalidation[k][ac],
					"dct.settings."..k.."."..ac.." invalid value: "..grid)
			end
		-- luacheck: ignore 542
		elseif k == "codenamedb" or k == "atorestrictions" then
		else
			assert(cfgvalidation[k] == v,
				"dct.settings unexpected field '"..k.."'")
		end
	end

	return 0
end

os.exit(main())
