-- SPDX-License-Identifier: LGPL-3.0
--
-- DCT mission script
--
-- This script is intended to be included in a DCS mission file via
-- the trigger system. This file will test and verify the server's
-- environment supports the calls required by DCT framework. It will
-- then setup and start the framework.

do
	if not lfs or not io or not os or not require or not package then
		local assertmsg = "DCT requires DCS mission scripting environment"..
			" to be modified, the file needing to be changed can be found"..
			" at $DCS_ROOT\\Scripts\\MissionScripting.lua. Comment out"..
			" the removal of lfs, io, os, 'require' and 'package'."..
			" *WARNING:* Running an unsanitized environment can open the"..
			" system up to unauthorized file-system writes, only run"..
			" DCS missions which you trust."
		assert(false, assertmsg)
	end

	-- 'dctsettings' can be defined in the mission to set nomodlog
	dctsettings = dctsettings or {}

	local dcttests = os.getenv("DCT_SRC_ROOT") and true
	local modpath = lfs.writedir() .. "\\Mods\\tech\\DCT"

	if not dcttests and lfs.attributes(modpath) == nil then
		local errmsg = "DCT: module not installed, mission not DCT enabled"
		if dctsettings.nomodlog then
			env.error(errmsg)
		else
			assert(false, errmsg)
		end
	else
		package.path = package.path .. ";" .. modpath .. "\\lua\\?.lua;"
		require("dct")
		if not dcttests then
			dct.modpath = modpath
		end
		dct.init()
	end
end
