#!/usr/bin/lua

require("os")
require("testlibs")
local utils = require("libs.utils")
dctsettings = {}
dctsettings.theaterpath = lfs.writedir()..utils.sep.."mission"
require("dct")

local function main()
	dct.init()
	assert(check.spawngroups == 1, "group spawn broken")
	assert(check.spawnstatics == 11, "static spawn broken")
	return 0
end

os.exit(main())
