-- SPDX-License-Identifier: LGPL-3.0

--- Initialize DCT from MissionScripting.lua

local sep     = package.config:sub(1,1)
local modpath = table.concat({lfs.writedir(), "Mods", "tech", "DCT"}, sep)
local pkgpath = table.concat({modpath, "lua", "?.lua"}, sep)

if lfs.attributes(modpath) ~= nil then
	package.path = table.concat({package.path, pkgpath}, ";")
	require("dct")
end
