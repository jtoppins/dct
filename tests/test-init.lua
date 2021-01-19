#!/usr/bin/lua

require("os")
require("dcttestlibs")
require("dct")

local function main()
	dct.init()
	_G.dct.theater:exec(50)
	local expected = 3
	assert(dctcheck.spawngroups == expected,
		string.format("group spawn broken; expected(%d), got(%d)",
		expected, dctcheck.spawngroups))
	expected = 12
	assert(dctcheck.spawnstatics == expected,
		string.format("static spawn broken; expected(%d), got(%d)",
		expected, dctcheck.spawnstatics))
	return 0
end

os.exit(main())
