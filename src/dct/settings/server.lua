-- SPDX-License-Identifier: LGPL-3.0

--- Reads server config settings.
-- Server configs are read upon game startup and can only be changed
-- when the game is restarted.
-- @module dct.settings

-- NOTE: cannot reference or require any library that relies on DCS
-- mission environment objects.

require("lfs")
require("libs")
local utils = libs.utils
local Check = require("dct.libs.Check")

local serverCfgChecker = Check("Server", {
	["debug"]       = {
		["default"] = _G.DCT_TEST or false,
		["type"] = Check.valuetype.BOOL,
		["description"] = [[
Globally enable debug logging and debugging checks.]],
	},
	["debughook"]   = {
		["default"] = _G.DCT_TEST or false,
		["type"] = Check.valuetype.BOOL,
		["description"] = [[]],
	},
	["profile"]     = {
		["default"] = false,
		["type"] = Check.valuetype.BOOL,
		["description"] = [[
Globally enable profiling. Can cause performance issues.]],
	},
	["statepath"]   = {
		["default"] = "",
		["type"] = Check.valuetype.STRING,
		["description"] = [[
]],
	},
	["theaterpath"] = {
		["default"] = "",
		["type"] = Check.valuetype.STRING,
		["description"] = [[
]],
	},
	["schedfreq"] = {
		["default"] = 2,
		["type"] = Check.valuetype.UNIT,
		["description"] = [[
DCT has a central command scheduler on which everything is driven. A higher
number will mean both AI and player UI will be more responsive but at the
cost of lower server performance.

_Note: the default is likely a reasonable value._]],
	},
	["tgtfps"] = {
		["default"] = 75,
		["type"] = Check.valuetype.UNIT,
		["description"] = [[
DCT has a central command scheduler on which everything is driven. This
scheduler implements a
[clamped game loop](https://gameprogrammingpatterns.com/game-loop.html)
which will prevent additional commands from executing once DCT's calculated
quanta has been reached. This allows the server to "catch-up". A lower
value will effectively allocate more time for DCT to run at the expense of
stealing server cycles for things like networking.]],
	},
	["percentTimeAllowed"] ={
		["default"] = .3,
		["type"] = Check.valuetype.UNIT,
		["description"] = [[
Used in calculation of the quanta. Specifies the percent of time in a given
frame DCT is allowed to run.

	example:
	    percentTimeAllowed = .3
	    tgtfps = 75
	    quanta = (1/75)*.3 = 0.004 or 4 milliseconds
	      This means per-frame DCT is only allowed 4ms of execution time.]],
	},
	["period"] = {
		["default"] = -1,
		["type"] = Check.valuetype.UNIT,
		["description"] = [[
The amount of time, in seconds, the server will be run before being
restarted by the dct-hooks script. This allows a server to periodically
restart its mission, this does not reset the saved state of the mission.]],
	},
	["logger"] = {
		["default"] = {},
		["type"] = Check.valuetype.TABLE,
		["description"] = [[
Defines the logging level for various subsystems in the framework. The
logging levels are:

 * `(0) error`
 * `(1) warn`
 * `(2) info`
 * `(4) debug`

The default level is the "warn" level.

`<subsystem>` can be one of the following:

 * `Theater`
 * `Command`
 * `Goal`
 * `Commander`
 * `Asset`
 * `AssetManager`
 * `Observable`
 * `Region`
 * `UI`]],
	},
	["whitelists"] = {
		["default"] = {},
		["type"] = Check.valuetype.TABLE,
		["description"] = [[
 An allow list can be defined for each special role slot allowing a server
 administrator to restrict the usage of these slots to specific people.

 A example of how to define a whitelist:

```lua
whitelist = {
	["admin"] = {
		"ucid-1",
		"ucid-2",
	},
	["observer"] = {
		"ucid-3",
		"ucid-4",
	},
}
```

Role specific slot types:

 * admin
 * forward_observer
 * instructor
 * artillery_commander
 * observer

If a UCID is a member of the "admin" role type these players can join any
slot on the server, assuming they have the DCS paid for content.]],
	},
	["emptyslottimeout"] = {
		["default"] = 0,
		["type"] = Check.valuetype.UNIT,
		["description"] = [[
Sets how long an empty player slot can be before its mission is automatically
aborted. A value of 0 means missions will only be aborted when the mission
itself times out, while a positive value makes empty slots time out faster.

Note that because the AssetManager runs every 2 minutes, the actual timeout
value can only have a granularity of 2 minutes.]],
	},
	["showErrors"] = {
		["default"] = false,
		["type"] = Check.valuetype.BOOL,
		["description"] = [[
Shows DCT script errors in a modal message box. Meant for development use only,
as the game will be unresponsive until the message box is closed.]],
	},
	["enableslots"] = {
		["default"] = true,
		["type"] = Check.valuetype.BOOL,
		["description"] = [[
Mission designers are layering other scripts on top of DCT. The initialization
of these scripts needs to be complete before players should be allowed to join
slots. To allow for this use case, a well known mission flag (DCTENABLE_SLOTS)
can be used. The DCT hooks script will then use this flag to determine if hooks
are globally enabled or not. Finally a server level configuration can be set to
initially set this flag true/false. With the default being true so DCT will
enable slots as normal as soon as it is ready. The flag is only set once
by the Theater during init to this default value. It is up to third party
scripts to set this DCS user flag to true when they are ready if the initial
value is false.]],
	},
},[[
All DCT server configuration can be accessed via LUA's global table at:

	dct.settings.server.<config-item>

Where `<config-item>` is the name of the configuration option below.]])

local function convert_lists(tbl)
	local allowedkeys = {
		["admin"]               = true,
		["forward_observer"]    = true,
		["instructor"]          = true,
		["artillery_commander"] = true,
		["observer"]            = true,
	}
	local tblkey = "whitelists"
	local newtbl = {}
	for k, v in pairs(tbl[tblkey]) do
		if allowedkeys[k] == nil then
			return false, "invalid key "..k
		end
		newtbl[k] = {}
		for _, ucid in ipairs(v) do
			newtbl[k][ucid] = true
		end
	end
	tbl[tblkey] = newtbl
	return true
end

local function validate_server_config(cfg, tbl)
	local ok, msg = serverCfgChecker:check(tbl)

	if not ok then
		error(string.format("%s; file: %s", msg, cfg.file))
	end

	ok, msg = convert_lists(tbl)

	if not ok then
		error(string.format("%s; file: %s", msg, cfg.file))
	end
	return tbl
end

--- Server configuration table.
-- Describes the server configuration defined in
-- `<dcs-savedgames>/Config/dct.cfg`.
-- @table server
-- @field debug Globally enable debug logging and debugging checks.
local sconfig = {}
local sconfig_mt = {}

function sconfig_mt.__index(tbl, key)
	if next(tbl) then
		return nil
	end

	local newtbl = {}
	utils.readconfigs({
		{
			["name"] = "server",
			["file"] = lfs.writedir()..
				utils.join_paths("Config", "dct.cfg"),
			["validate"] = validate_server_config,
		},}, newtbl)
	utils.mergetables(tbl, newtbl.server)
	return tbl[key]
end

setmetatable(sconfig, sconfig_mt)

return sconfig
