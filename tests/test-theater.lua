#!/usr/bin/lua

require("os")
require("dcttestlibs")
local utils = require("libs.utils")
require("dct")

local function main()
	dct.Theater()
	assert(check.spawngroups == 1, "group spawn broken")
	assert(check.spawnstatics == 11, "static spawn broken")
	return 0
end

os.exit(main())
