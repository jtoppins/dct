#!/usr/bin/lua

require("dcttestlibs")
local sep = package.config:sub(1,1)
local modpath = lfs.writedir()..table.concat({"Mods", "Tech", "DCT"}, sep)

if lfs.attributes(modpath) == nil then
	env.error("DCT: module not installed, mission not DCT enabled")
end

package.path = package.path..";"..modpath..sep.."lua"..sep.."?.lua;"
require("dct")
dct.init()
dctstubs.setModelTime(50)
for _ = 1,100,1 do
	dctstubs.runSched()
	dctstubs.addModelTime(3)
end

local expected = 35
assert(dctcheck.spawngroups == expected,
	string.format("group spawn broken; expected(%d), got(%d)",
	expected, dctcheck.spawngroups))
expected = 36
assert(dctcheck.spawnstatics == expected,
	string.format("static spawn broken; expected(%d), got(%d)",
	expected, dctcheck.spawnstatics))

os.remove(dct.settings.server.statepath)
os.exit(0)
