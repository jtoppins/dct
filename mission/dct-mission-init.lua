-- SPDX-License-Identifier: LGPL-3.0
--[[
-- test and verify the server's environment supports the calls
-- required by DCT framework
--]]
local assertmsg = "DCT requires DCS mission scripting environment to be" ..
			" modified, the file needing to be changed can be found at" ..
			" $DCS_ROOT\\Scripts\\MissionScripting.lua. Comment out the" ..
			" removal of lfs and io and the setting of 'require' to nil."
if not lfs or not io or not require then
	assert(false, assertmsg)
end

-- Provide some default settings if the mission maker doesn't want
-- to add any
local s = dctsettings or {}
if s.luapath == nil then
	s.luapath = lfs.writedir() .. "Scripts\\?.lua;"
end

package.path = package.path .. ";" .. s.luapath
require("dct")
dct.init(s)
