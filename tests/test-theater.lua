#!/usr/bin/lua

require("os")
require("dcttestlibs")
require("dct")

local function main()
	local theater = dct.Theater.getInstance()
	assert(dctcheck.spawngroups == 1, "group spawn broken")
	assert(dctcheck.spawnstatics == 11, "static spawn broken")

	--[[
	local restriction =
		theater:getATORestrictions(coalition.side.BLUE, "A-10C")
	print(require("libs.json"):encode_pretty(restriction))
	restriction =
		theater:getATORestrictions(coalition.side.BLUE, "F-15C")
	print(require("libs.json"):encode_pretty(restriction))
	--]]
	return 0
end

os.exit(main())
