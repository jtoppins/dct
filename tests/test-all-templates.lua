#!/usr/bin/lua

require("math")
require("dcttestlibs")
require("dct")
dct.settings.server.profile = true
dct.settings.server.debug   = false
dct.settings.server.theaterpath = os.getenv("DCT_TEMPLATE_PATH")

local function main()
	-- setup an initial seed, lets use the same one for now '12345'
	math.randomseed(12345)
	if os.getenv("DCT_TEMPLATE_PATH") == nil then
		-- skip test
		return 0
	end

	local t = dct.Theater()
	dct.theater = t
	t:exec(50)
	local Logger = dct.Logger.getByName("Tests")
	Logger:warn("Unit spawned:    "..dctcheck.spawnunits)
	Logger:warn("Groups spawned:  "..dctcheck.spawngroups)
	Logger:warn("Statics spawned: "..dctcheck.spawnstatics)
	local tstart = os.clock()
	t:export()
	os.remove(dct.settings.server.statepath)
	Logger:warn("took %4.2fms to write statefile", (os.clock() - tstart)*1000)
	return 0
end

os.exit(main())
