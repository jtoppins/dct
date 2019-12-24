#!/usr/bin/lua

require("os")
require("dcttestlibs")
require("dct")

local function main()
	local theater = dct.Theater.getInstance()
	assert(check.spawngroups == 1, "group spawn broken")
	assert(check.spawnstatics == 11, "static spawn broken")

	local restriction =
		theater:getATORestrictions(coalition.side.BLUE, "A-10C")
	restriction =
		theater:getATORestrictions(coalition.side.BLUE, "F-15C")
	return 0
end

os.exit(main())
