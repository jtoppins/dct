--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides config facilities.
--]]

local class    = require("libs.namedclass")
local utils    = require("libs.utils")
local dctenum  = require("dct.enum")
local dctutils = require("dct.libs.utils")
local uihuman  = require("dct.ui.human")
local Checker  = require("dct.templates.checkers.Check")

local defaultpayload = {}
for _, v in pairs(dctenum.weaponCategory) do
	defaultpayload[v] = dctenum.WPNINFCOST - 1
end

local CheckPerEntry = class("CheckPerEntry", Checker)
function CheckPerEntry:check(data)
	for key, val in pairs(data) do
		local ok, errkey, msg = Checker.check(self, val)
		if not ok then
			return false, string.format(
				"%s: invalid `%s` %s", tostring(key),
				tostring(errkey), tostring(msg))
		end
	end
	return true
end

local function validate_weapon_restrictions(cfg, tbl)
	local check = CheckPerEntry(nil, {
			["cost"] = {
				["nodoc"] = true,
				["type"] = Checker.valuetype.INT,
			},
			["category"] = {
				["nodoc"] = true,
				["type"] = Checker.valuetype.TABLEKEYS,
				["values"] = dctenum.weaponCategory,
			},
		})

	local ok, msg = check:check(tbl)
	if not ok then
		error(string.format("%s; file: %s", msg, cfg.file))
	end
	return tbl
end

--- validates payload limits configuration
-- This is per airframe with a "default" entry in case an airframe is
-- not defined. The default is unlimited.
local function validate_payload_limits(cfg, tbl)
	local newlimits = {}

	for planetype, limits in pairs(tbl) do
		newlimits[planetype] = {}
		local tmptbl = {}

		for wpncat, val in pairs(limits) do
			local w = dctenum.weaponCategory[string.upper(wpncat)]

			if w == nil then
				error(string.format(
					"invalid weapon category '%s' - "..
					"plane type %s; file: %s",
					wpncat, planetype, cfg.file))
			end
			tmptbl[w] = val
		end
		utils.mergetables(newlimits[planetype], defaultpayload)
		utils.mergetables(newlimits[planetype], tmptbl)
	end
	newlimits["default"] = defaultpayload
	return newlimits
end

local function validate_codenamedb(cfg, tbl)
	local newtbl = {}
	for key, list in pairs(tbl) do
		local newkey
		local upper = string.upper(key)
		local k = dctenum.assetType[upper]

		if k == nil then
			k = dctenum.assetTypeDeprecated[upper]
		end

		if k ~= nil then
			newkey = k
		elseif key == "default" then
			newkey = key
		else
			error(string.format("invalid codename category "..
				"'%s'; file: %s", key, cfg.file))
		end

		if type(list) ~= "table" then
			error(string.format("invalid codename value for "..
				"category '%s', must be a table; file: %s",
				key, cfg.file))
		end
		newtbl[newkey] = list
	end
	return newtbl
end

local function validate_ui(cfg, tbl)
	local check = CheckPerEntry(nil, {
			["gridfmt"] = {
				["nodoc"] = true,
				["type"] = Checker.valuetype.TABLEKEYS,
				["values"] = uihuman.posfmt,
				["default"] = uihuman.posfmt.DMS,
			},
			["distfmt"] = {
				["nodoc"] = true,
				["type"] = Checker.valuetype.TABLEKEYS,
				["values"] = uihuman.distancefmt,
				["default"] = uihuman.distancefmt.NAUTICALMILE,
			},
			["altfmt"] = {
				["nodoc"] = true,
				["type"] = Checker.valuetype.TABLEKEYS,
				["values"] = uihuman.altfmt,
				["default"] = uihuman.altfmt.FEET,
			},
			["speedfmt"] = {
				["nodoc"] = true,
				["type"] = Checker.valuetype.TABLEKEYS,
				["values"] = uihuman.speedfmt,
				["default"] = uihuman.speedfmt.KNOTS,
			},
			["pressurefmt"] = {
				["nodoc"] = true,
				["type"] = Checker.valuetype.TABLEKEYS,
				["values"] = uihuman.pressurefmt,
				["default"] = uihuman.pressurefmt.INHG,
			},
			["tempfmt"] = {
				["nodoc"] = true,
				["type"] = Checker.valuetype.TABLEKEYS,
				["values"] = uihuman.tempfmt,
				["default"] = uihuman.tempfmt.F,
			},
		})
	local newtbl = {}

	utils.mergetables(newtbl, cfg.default)
	utils.mergetables(newtbl, tbl)

	local ok, msg = check:check(newtbl)
	if not ok then
		error(string.format("%s; file: %s", msg, cfg.file))
	end
	return newtbl
end

local function merge_defaults(cfgdata, tbl)
	local newtbl = {}
	newtbl = utils.mergetables(newtbl, cfgdata.default)
	newtbl = utils.mergetables(newtbl, tbl)
	return newtbl
end

local function validate_ato(cfg, tbl)
	local ntbl = {}

	for ac, mlist in pairs(tbl) do
		local ok, nlist = dctutils.check_ato(mlist)

		if not ok then
			error(string.format("%s; aircraft: %s; file: %s",
				nlist, ac, cfg.file))
		end
		ntbl[ac] = nlist
	end
	return ntbl
end

local function validate_cost(cfg, tbl)
	for ac, cost in pairs(tbl) do
		if type(cost) ~= "number" then
			error(string.format(
				"cost not a number; aircraft: %s; file: %s",
				ac, cfg.file))
		end
	end
	return tbl
end

local function validate_general(cfg, tbl)
	local check = Checker(nil, {
			["airbase_nosilence"] = {
				["description"] = [[
This setting will determine if the ATC tower is disabled by default
until a DCT airbase object takes ownership. By default all airbases
are silenced unless DCT is controlling the airbase. Set to true to
keep DCS's ATC system on for all airbases, including ships.]],
				["type"] = Checker.valuetype.BOOL,
				["default"] = false,
			},
		})
	local ok, msg = check.check(tbl)

	if not ok then
		error(string.format("%s; file: %s", msg, cfg.file))
	end
	return tbl
end

-- We have a few levels of configuration:
-- 	* server defined config file; <dcs-saved-games>/Config/dct.cfg
-- 	* theater defined configuration; <theater-path>/settings/<config-files>
-- 	* default config values
-- simple algorithm; assign the defaults, then apply the server and
-- theater configs
local function theatercfgs(config)
	local basepath = utils.join_paths(config.server.theaterpath,
					  "settings")
	local cfgs = {
		{
			["name"] = "restrictedweapons",
			["file"] = utils.join_paths(basepath,
					"restrictedweapons.cfg"),
			["cfgtblname"] = "restrictedweapons",
			["validate"] = validate_weapon_restrictions,
			["default"] = require("dct.data.restrictedweapons"),
			["env"] = {
				["INFCOST"] = dctenum.WPNINFCOST,
			},
		}, {
			["name"] = "payloadlimits",
			["file"] = utils.join_paths(basepath,
						    "payloadlimits.cfg"),
			["cfgtblname"] = "payloadlimits",
			["validate"] = validate_payload_limits,
		}, {
			["name"] = "codenamedb",
			["file"] = utils.join_paths(basepath,
						    "codenamedb.cfg"),
			["validate"] = validate_codenamedb,
			["default"] = require("dct.data.codenamedb"),
		}, {
			["name"] = "ui",
			["file"] = utils.join_paths(basepath, "ui.cfg"),
			["validate"] = validate_ui,
			["cfgtblname"] = "ui",
			["default"] = require("dct.data.playerui"),
		}, {
			["name"] = "blasteffects",
			["file"] = utils.join_paths(basepath,
						    "blasteffects.cfg"),
			["validate"] = merge_defaults,
			["default"] = require("dct.data.blasteffects"),
		}, {
			["name"] = "agents",
			["file"] = utils.join_paths(basepath, "agents.cfg"),
			["validate"] = merge_defaults,
			["default"] = require("dct.data.agents"),
		}, {
			["name"] = "ato",
			["file"] = utils.join_paths(basepath, "ato.cfg"),
			["validate"] = validate_ato,
			["cfgtblname"] = "ato",
		}, {
			["name"] = "airframecost",
			["file"] = utils.join_paths(basepath,
						    "airframecost.cfg"),
			["validate"] = validate_cost,
			["cfgtblname"] = "cost",
		}, {
			["name"] = "general",
			["file"] = utils.join_paths(basepath,
						    "general.cfg"),
			["validate"] = validate_general,
			["default"] = require("dct.data.general"),
		},
	}

	utils.readconfigs(cfgs, config)
	return config
end

return theatercfgs
