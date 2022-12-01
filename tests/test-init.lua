#!/usr/bin/lua

require("dcttestlibs")
dofile(os.getenv("DCT_DATA_ROOT").."/../mission/dct-mission-init.lua")
dctstubs.setModelTime(50)
for i = 1,100,1 do
	dctstubs.runSched()
	dctstubs.addModelTime(3)
end

local expected = 34
assert(dctcheck.spawngroups == expected,
	string.format("group spawn broken; expected(%d), got(%d)",
	expected, dctcheck.spawngroups))
expected = 36
assert(dctcheck.spawnstatics == expected,
	string.format("static spawn broken; expected(%d), got(%d)",
	expected, dctcheck.spawnstatics))

os.remove(dct.settings.server.statepath)
os.exit(0)
