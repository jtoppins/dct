-- SPDX-License-Identifier: LGPL-3.0

--- DCT init hook script
---
--- This script is intended to be put into the hooks directory;
---     <dcs-saved-games>/Scripts/Hooks/
---
--- The script is intended in initialize the DCT mission environment if the
--- mission being loaded has set a specific flag in the mission editor to
--- signal the mission is DCT enabled.
--- @script dct-init

-- luacheck: read_globals log DCS net
local facility = "[DCT-INIT]"
local sep      = package.config:sub(1,1)

-- Determine if DCT is installed and amend environment as appropriate
local modpath = lfs.writedir()..table.concat({"Mods", "Tech", "DCT"}, sep)
local pkgpath = table.concat({modpath, "lua", "?.lua"}, sep)
if lfs.attributes(modpath) == nil then
	log.write(facility, log.WARNING, "DCT not installed, skipping...")
	return
end
package.path = table.concat({package.path, pkgpath}, ";")

local ok
local class
local DCTHooks

ok, class = pcall(require, "libs.class")
if not ok then
	log.write(facility, log.ERROR,
		string.format("unable to load class library: %s", class))
	return
end

ok, DCTHooks = pcall(require, "dcthooks")
if not ok then
	log.write(facility, log.ERROR,
		string.format("unable to load dcthooks: %s", DCTHooks))
	return
end

local dctinitcmd = string.format("%q", [[
if not lfs or not io or not os or not require or not package then
	local assertmsg = "DCT requires DCS mission scripting"..
		" environment to be modified, the file needing to be"..
		" changed can be found at"..
		" $DCS_ROOT\\Scripts\\MissionScripting.lua. Comment"..
		" out the removal of lfs, io, os, 'require' and"..
		" 'package'. *WARNING:* Running an unsanitized"..
		" environment can open the system up to unauthorized"..
		" file-system writes, only run DCS missions which"..
		" you trust."
	assert(false, assertmsg)
end

local sep = package.config:sub(1,1)
local modpath = lfs.writedir()..table.concat({"Mods", "Tech", "DCT"}, sep)
local pkgpath = table.concat({modpath, "lua", "?.lua"}, sep)

if lfs.attributes(modpath) == nil then
	env.error("DCT: module not installed, mission not DCT enabled")
end

package.path = table.concat({package.path, pkgpath}, ";")
require("dct")
dct.init()
return "0"
]])
local code = string.format("a_do_script(%s)", dctinitcmd)

local DCTInit = class(facility, DCTHooks)
function DCTInit:__init()
	DCTHooks.__init(self)
end

function DCTInit:onMissionLoadEnd()
	if DCS.isServer() and self:isMissionEnabled() then
		self:doRPC("mission", code, "number")
	end
end

local init = DCTInit()
init:register()
