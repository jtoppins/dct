--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides config facilities.
--]]

require("lfs")
local utils      = require("libs.utils")
local dctutils   = require("dct.utils")
local enum       = require("dct.enum")
local config     = nil

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
	dctutils.checkkeys(keys, tbl)
	tbl.path = nil
	return tbl
end

local function validate_weapon_restrictions(cfgdata, tbl)
	local path = cfgdata.file
	local keys = {
		[1] = {
			["name"] = "cost",
			["type"] = "number",
		},
		[2] = {
			["name"] = "category",
			["type"] = "string",
			["check"] = function (keydata, t)
		if enum.weaponCategory[string.upper(t[keydata.name])] ~= nil then
			t[keydata.name] =
				enum.weaponCategory[string.upper(t[keydata.name])]
			return true
		end
		return false
	end,
		},
	}
	for _, wpndata in pairs(tbl) do
		wpndata.path = path
		utils.checkkeys(keys, wpndata)
		wpndata.path = nil
	end
	return tbl
end

local function validate_payload_limits(cfgdata, tbl)
	local newlimits = {}
	for wpncat, val in pairs(tbl) do
		local w = enum.weaponCategory[string.upper(wpncat)]
		assert(w ~= nil,
			string.format("invalid weapon category '%s'; file: %s",
				wpncat, cfgdata.file))
		newlimits[w] = val
	end
	return newlimits
end

local function validate_codenamedb(cfgdata, tbl)
	local newtbl = {}
	for key, list in pairs(tbl) do
		local newkey
		assert(type(key) == "string",
			string.format("invalid codename category '%s'; file: %s",
			key, cfgdata.file))

		local k = enum.assetType[string.upper(key)]
		if k ~= nil then
			newkey = k
		elseif key == "default" then
			newkey = key
		else
			assert(nil,
				string.format("invalid codename category '%s'; file: %s",
				key, cfgdata.file))
		end
		assert(type(list) == "table",
			string.format("invalid codename value for category "..
				"'%s', must be a table; file: %s", key, cfgdata.file))
		newtbl[newkey] = list
	end
	return newtbl
end

local function validate_ui(cfgdata, tbl)
	local newtbl = {}
	utils.mergetables(newtbl, cfgdata.default)
	for k, v in pairs(tbl) do
		utils.mergetables(newtbl[k], v)
	end
	return newtbl
end

--[[
-- We have a few levels of configuration:
-- 	* server defined config file; <dcs-saved-games>/Config/dct.cfg
-- 	* theater defined configuration; <theater-path>/settings/<config-files>
-- 	* default config values
-- simple algorithm; assign the defaults, then apply the server and
-- theater configs
--]]
local function settings()
	if config ~= nil then
		return config
	end

	config = {}
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
				["statepath"]   = lfs.writedir()..utils.sep..
					env.mission.theatre.."_"..
					env.getValueDictByKey(env.mission.sortie)..".state",
				["theaterpath"] = lfs.tempdir() .. utils.sep .. "theater",
				["schedfreq"] = 2, -- hertz
				["tgtfps"] = 75,
				["percentTimeAllowed"] = .3,
				["period"] = 43200,
			},
		},}, config)

	local defaultpayload = {}
	for _,v in pairs(enum.weaponCategory) do
		defaultpayload[v] = enum.WPNINFCOST - 1
	end

	local theatercfgs = {
		{
			["name"] = "restrictedweapons",
			["file"] = config.server.theaterpath..utils.sep.."settings"..
				utils.sep.."restrictedweapons.cfg",
			["cfgtblname"] = "restrictedweapons",
			["validate"] = validate_weapon_restrictions,
			["default"] = {
				["RN-24"] = {
					["cost"]     = enum.WPNINFCOST,
					["category"] = enum.weaponCategory.AG,
				},
				["RN-28"] = {
					["cost"]     = enum.WPNINFCOST,
					["category"] = enum.weaponCategory.AG,
				},
			},
		},
		{
			["name"] = "payloadlimits",
			["file"] = config.server.theaterpath..utils.sep.."settings"..
				utils.sep.."payloadlimits.cfg",
			["cfgtblname"] = "payloadlimits",
			["validate"] = validate_payload_limits,
			["default"] = defaultpayload,
		},
		{
			["name"] = "codenamedb",
			["file"] = config.server.theaterpath..utils.sep.."settings"..
				utils.sep.."codenamedb.cfg",
			["cfgtblname"] = "codenamedb",
			["validate"] = validate_codenamedb,
			["default"] = require("dct.data.codenamedb"),
		},
		{
			["name"] = "ui",
			["file"] = config.server.theaterpath..utils.sep.."settings"..
				utils.sep.."ui.cfg",
			["cfgtblname"] = "dctui",
			["validate"] = validate_ui,
			["default"] = {
				["gridfmt"] = {
					-- default is DMS, no need to list
					["Ka-50"]         = dctutils.posfmt.DDM,
					["Mi-8MT"]        = dctutils.posfmt.DDM,
					["SA342M"]        = dctutils.posfmt.DDM,
					["SA342L"]        = dctutils.posfmt.DDM,
					["UH-1H"]         = dctutils.posfmt.DDM,
					["A-10A"]         = dctutils.posfmt.MGRS,
					["A-10C"]         = dctutils.posfmt.MGRS,
					["A-10C_2"]       = dctutils.posfmt.MGRS,
					["AV8BNA"]        = dctutils.posfmt.DDM,
					["F-5E-3"]        = dctutils.posfmt.DDM,
					["F-16C_50"]      = dctutils.posfmt.DDM,
					["FA-18C_hornet"] = dctutils.posfmt.DDM,
					["M-2000C"]       = dctutils.posfmt.DDM,
				},
				["ato"] = {},
			},
		},
	}

	utils.readconfigs(theatercfgs, config)
	return config
end

return settings
