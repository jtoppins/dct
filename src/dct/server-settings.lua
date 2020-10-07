--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Reads the server config settings
--]]

-- NOTE: cannot reference or require any library that relies on DCS
-- mission environment objects.

require("lfs")
local utils = require("libs.utils")

local function validate_server_config(cfgdata, tbl)
	if tbl == nil then
		return {}
	end
	local keys = {
		{
			["name"] = "debug",
			["type"] = "boolean",
			["default"] = cfgdata.default["debug"],
		}, {
			["name"] = "profile",
			["type"] = "boolean",
			["default"] = cfgdata.default["profile"],
		}, {
			["name"] = "statepath",
			["type"] = "string",
			["default"] = cfgdata.default["statepath"],
		}, {
			["name"] = "theaterpath",
			["type"] = "string",
			["default"] = cfgdata.default["theaterpath"],
		}, {
			["name"] = "schedfreq",
			["type"] = "number",
			["default"] = cfgdata.default["schedfreq"],
		}, {
			["name"] = "tgtfps",
			["type"] = "number",
			["default"] = cfgdata.default["tgtfps"],
		}, {
			["name"] = "percentTimeAllowed",
			["type"] = "number",
			["default"] = cfgdata.default["percentTimeAllowed"],
		}, {
			["name"] = "period",
			["type"] = "number",
			["default"] = cfgdata.default["period"],
		},
	}
	tbl.path = cfgdata.file
	utils.checkkeys(keys, tbl)
	tbl.path = nil
	return tbl
end

local function servercfgs(config)
	utils.readconfigs({
		{
			["name"] = "server",
			["file"] = lfs.writedir()..utils.sep.."Config"..
				utils.sep.."dct.cfg",
			["cfgtblname"] = "dctserverconfig",
			["validate"] = validate_server_config,
			["default"] = {
				["debug"]       = false,
				["profile"]     = false,
				["statepath"]   =
					lfs.writedir()..utils.sep..
					env.mission.theatre.."_"..
					env.getValueDictByKey(env.mission.sortie)..".state",
				["theaterpath"] = lfs.tempdir()..utils.sep.."theater",
				["schedfreq"] = 2, -- hertz
				["tgtfps"] = 75,
				["percentTimeAllowed"] = .3,
				["period"] = 43200,
				["logger"] = {},
			},
		},}, config)
	return config
end

return servercfgs
