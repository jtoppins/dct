#!/usr/bin/lua

require("os")
require("dcttestlibs")
require("dct")

local function main()
	local theater = dct.Theater()
	assert(dctcheck.spawngroups == 1, "group spawn broken")
	assert(dctcheck.spawnstatics == 11, "static spawn broken")

	local restriction =
		theater:getATORestrictions(coalition.side.BLUE, "A-10C")
	local validtbl = { ["BAI"] = 5, ["CAS"] = 1, }
	for k, v in pairs(restriction) do
		assert(validtbl[k] == v, "ATO Restriction error")
	end
	return 0
end

os.exit(main())
