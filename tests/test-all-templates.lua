#!/usr/bin/lua

require("math")
require("dcttestlibs")
dctsettings = {
	["profile"] = true,
	["debug"]   = false,
	["logger"]  = {
		["DebugStats"] = "debug",
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

	dct.Theater.getInstance()
	print("Groups spawned:  "..check.spawngroups)
	print("Statics spawned: "..check.spawngroups)
	dct.DebugStats.getDebugStats():log()
	return 0
end

os.exit(main())
