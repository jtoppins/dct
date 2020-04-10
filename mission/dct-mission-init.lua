--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- DCT mission script
--
-- This script is intended to be included in a DCS mission file via
-- the trigger system. This file will test and verify the server's
-- environment supports the calls required by DCT framework. It will
-- then setup and start the framework.
--]]

if not lfs or not io or not require then
	local assertmsg = "DCT requires DCS mission scripting environment to be" ..
		" modified, the file needing to be changed can be found at" ..
		" $DCS_ROOT\\Scripts\\MissionScripting.lua. Comment out the" ..
		" removal of lfs and io and the setting of 'require' to nil."
	assert(false, assertmsg)
end

-- 'dctsettings' can be defined in the mission to override any of the
-- possible dct settings.
dctsettings = dctsettings or {}

-- Check that DCT mod is installed
local modpath = lfs.writedir() .. "Mods\\tech\\DCT"
if lfs.attributes(modpath) == nil then
	local errmsg = "DCT: module not installed, mission not DCT enabled"
	if dctsettings.nomodlog then
		env.error(errmsg)
	else
		assert(false, errmsg)
	end
else
	package.path = package.path .. ";" .. modpath .. "\\lua\\?.lua;"
	require("dct")
	dct.init()
end

