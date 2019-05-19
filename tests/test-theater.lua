#!/usr/bin/lua

require("os")
require("testlibs")
require("dct")

local function main()
	local theaterPath = "./data/mission"
	dct.Theater(theaterPath)
	assert(check.spawngroups == 1, "group spawn broken")
	assert(check.spawnstatics == 11, "static spawn broken")
	return 0
end

os.exit(main())
