--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Reads the server config settings
--]]

-- NOTE: cannot reference or require any library that relies on DCS
-- mission environment objects.

require("lfs")
local utils = require("libs.utils")

local function convert_lists(keydata, t)
	local allowedkeys = {
		["admin"]               = true,
		["forward_observer"]    = true,
		["instructor"]          = true,
		["artillery_commander"] = true,
		["observer"]            = true,
	}
	local newtbl = {}
	for k, v in pairs(t[keydata.name]) do
		if allowedkeys[k] == nil then
			return false
		end
		newtbl[k] = {}
		for _, ucid in ipairs(v) do
			newtbl[k][ucid] = true
		end
	end
	t[keydata.name] = newtbl
	return true
end

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
			["name"] = "hookdebug",
			["type"] = "boolean",
			["default"] = cfgdata.default["hookdebug"],
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
		}, {
			["name"] = "whitelists",
			["type"] = "table",
			["check"] = convert_lists,
			["default"] = cfgdata.default["whitelists"],
		}, {
			["name"] = "emptyslottimeout",
			["type"] = "number",
			["default"] = cfgdata.default["emptyslottimeout"],
		}, {
			["name"] = "showErrors",
			["type"] = "boolean",
			["default"] = cfgdata.default["showErrors"],
		}, {
			["name"] = "enableslots",
			["type"] = "boolean",
			["default"] = cfgdata.default["enableslots"],
		},
	}
	tbl.path = cfgdata.file
	utils.checkkeys(keys, tbl)
	tbl.path = nil
	return tbl
end

-- luacheck: read_globals DCS
local function getEnvVars()
	local vars = {}
	if env == nil then
		vars.theater = "unknown"
		vars.sortie  = "unknown"
	else
		vars.theater = env.mission.theatre
		vars.sortie  = env.getValueDictByKey(env.mission.sortie)
	end
	return vars
end

local function servercfgs(config)
	local vars = getEnvVars()
	utils.readconfigs({
		{
			["name"] = "server",
			["file"] = lfs.writedir().."Config"..utils.sep..
				   "dct.cfg",
			["validate"] = validate_server_config,
			["default"] = {
				["debug"]       = _G.DCT_TEST or false,
				["hookdebug"]   = _G.DCT_TEST or false,
				["profile"]     = false,
				["statepath"]   =
					lfs.writedir()..vars.theater.."_"..
					vars.sortie..".state",
				["theaterpath"] = lfs.writedir().."DCT"..
					utils.sep.."theaters"..utils.sep..
					vars.theater.."_"..vars.sortie,
				["schedfreq"] = 2, -- hertz
				["tgtfps"] = 75,
				["percentTimeAllowed"] = .3,
				["period"] = -1, -- mission restart is disabled by default
				["logger"] = {},
				["whitelists"] = {},
				["emptyslottimeout"] = 0, -- seconds
				["showErrors"] = false,
				["enableslots"] = true,
			},
		},}, config)
	return config
end

return servercfgs
