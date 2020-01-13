#!/usr/bin/lua

require("math")
require("dcttestlibs")
dctsettings = {
	["profile"] = true,
	["debug"]   = false,
	["logger"]  = {
	},
	["theaterpath"] = os.getenv("DCT_TEMPLATE_PATH"),
}
require("dct")

local function main()
	-- setup an initial seed, lets use the same one for now '12345'
	math.randomseed(12345)
	if os.getenv("DCT_TEMPLATE_PATH") == nil then
		-- skip test
		return 0
	end

	dct.Theater()
	--print("Groups spawned:  "..dctcheck.spawngroups)
	--print("Statics spawned: "..dctcheck.spawnstatics)
	assert(dctcheck.spawngroups == 83, "group spawn broken; expected: 83"..
		string.format(", got: %d", dctcheck.spawngroups))
	assert(dctcheck.spawnstatics == 745, "static spawn broken; expected: 745"..
		string.format(", got: %d", dctcheck.spawnstatics))
	--print(t.assetmgr:getStats(coalition.side.RED):tostring("%s: %d\n"))
	return 0
end

os.exit(main())
