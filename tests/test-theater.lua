#!/usr/bin/lua

require("os")
require("io")
require("md5")
require("dcttestlibs")
require("dct")
local settings = _G.dct.settings

local function main()
	local theater = dct.Theater()
	assert(dctcheck.spawngroups == 1, "group spawn broken")
	assert(dctcheck.spawnstatics == 11, "static spawn broken")

	local restriction =
		theater:getATORestrictions(coalition.side.BLUE, "A-10C")
	local validtbl = { ["BAI"] = 5, ["CAS"] = 1, ["STRIKE"] = 3,}
	for k, v in pairs(restriction) do
		assert(validtbl[k] == v, "ATO Restriction error")
	end

	theater:export()
	local f = io.open(settings.statepath, "r")
	local sumorig = md5.sum(f:read("*all"))
	f:close()

	local newtheater = dct.Theater()
	newtheater:export()
	f = io.open(settings.statepath, "r")
	local sumsave = md5.sum(f:read("*all"))
	f:close()
	os.remove(settings.statepath)

	assert(newtheater.statef == true and sumorig == sumsave,
		"state saving didn't produce the same md5sum")
	return 0
end

os.exit(main())
