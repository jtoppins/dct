#!/usr/bin/lua

require("testlibs")
require("dct")
local Template = require("dct.template")

local function main()
	check.spawngroups  = 0
	check.spawnstatics = 0
	local t = Template("./data/test.stm", "./data/test.dct")
	t:spawn()
	assert(check.spawngroups == 1, "group spawn broken")
	assert(check.spawnstatics == 11, "static spawn broken")


	check.spawngroups  = 0
	check.spawnstatics = 0
	t = Template("./data/test-all-types.stm",
				"./data/test-all-types.dct")
	t:spawn()
	assert(check.spawngroups == 6, "group spawn broken")
	assert(check.spawnstatics == 3, "static spawn broken")

	return 0
end

os.exit(main())
