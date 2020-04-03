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
	local Logger = require("dct.Logger").getByName("Tests")
	Logger:debug("Groups spawned:  "..dctcheck.spawngroups)
	Logger:debug("Statics spawned: "..dctcheck.spawnstatics)
	return 0
end

os.exit(main())
