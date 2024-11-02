-- SPDX-License-Identifier: LGPL-3.0

-- TODO: move theater settings to the theater class and its component
-- system.
--
-- Problem:
-- Provide a way to enable/disable systems registered with a given theater
-- instance. The idea is that different mission designers will want to use
-- different features of DCT.
--
-- Examples of optional features:
-- * Restricted Weapons / Point Buy System
-- * Blast Effects Enhancements
-- * Ticket System - the theater might implement a custom way to terminate
--                   the theater.
--
-- Solution:
-- A simple option is to declare if the system should be used by marking
-- each system definition as enabled. This would make initialization look
-- like;
--
-- if not dct.systems.isEnabled(dct.systems.BlastEffects) then
--     dct.systems.setEnabled(dct.systems.BlastEffects, true)
-- end
-- local theater = Theater()
-- -- non-DCT systems can call Theater methods systemRegister and
-- -- systemOverride to replace or add to the systems run.
--
-- How is this different from just passing a table to the Theater
-- constructor?
-- sysstates = {
--   ["BlastEffects"] = true,
--   ["WeaponsTracking"] = false,
-- }
-- local theater = Theater(sysstates)
-- -- will not forcefully override another system and throw an error if
-- the system of the same name is already registered.
-- theater:systemRegister(AnInstanceOfMySpecialNewSystem)
-- -- will replace a core system with the specified replacement
-- theater:systemOverride(AnInstanceOfMySpecialTicketSystem)
-- theater:initialize()
--
-- And the sysstates table could come from server configuration to allow
-- server admins to prevent the use of certain systems.

--- Provides facilities for reading theater level configuration.
-- @submodule dct.settings

require("libs")
local class    = libs.classnamed
local utils    = libs.utils
local dctenum  = require("dct.enum")
local dctutils = require("dct.libs.utils")
local Check    = require("dct.libs.Check")
local playerui = require("dct.settings.data.player")

local validators = {
	["restrictedweapons"] = check_restricted_weapons,
	["blasteffects"]      = todo,
	["agents"]            = todo,
	["general"]           = todo,
}

local function generic_validator(cfg, tbl)
        local check = 1-- TODO: lookup validator
	local ok, msg = check:check(tbl)
	if not ok then
		error(string.format("%s; file: %s", msg, cfg.file))
	end
	return tbl
end

local function merge_defaults(cfgdata, tbl)
	local newtbl = {}
	newtbl = utils.mergetables(newtbl, cfgdata.default)
	newtbl = utils.mergetables(newtbl, tbl)
	return newtbl
end

local function validate_general(cfg, tbl)
	local check = Check(nil, {
			["airbase_nosilence"] = {
				["description"] = [[
This setting will determine if the ATC tower is disabled by default
until a DCT airbase object takes ownership. By default all airbases
are silenced unless DCT is controlling the airbase. Set to true to
keep DCS's ATC system on for all airbases, including ships.]],
				["type"] = Check.valuetype.BOOL,
				["default"] = false,
			},
		})
	local ok, msg = check:check(tbl)

	if not ok then
		error(string.format("%s; file: %s", msg, cfg.file))
	end
	return tbl
end

local function theatercfgs(config)
	local basepath = utils.join_paths(config.server.theaterpath,
					  "settings")
	local cfgs = {
		{
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

--- Theater configuration table.
-- @table theater
-- @field one blah
local theater = {}

return theatercfgs
