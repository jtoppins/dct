require("math")
require("testlibs")
local json = require("libs.json")
dctsettings = {
	["profile"] = true,
	["debug"]   = false,
	["logger"]  = {
		["debugstats"] = "debug",
		["gamestate"]  = "debug",
	},
}
require("dct")

local check = {}
check.spawngroups  = 0
check.spawnstatics = 0

coalition = {}
function coalition.addGroup(_, cat, data)
	test.debug("SPAWN: spawn group; type: "..cat.."; name: "..data.name)
	test.debug(json:encode_pretty(data))
	check.spawngroups = check.spawngroups + 1
end

function coalition.addStaticObject(_, data)
	test.debug("SPAWN: spawn static; type: static; name: "..data.name)
	test.debug(json:encode_pretty(data))
	check.spawnstatics = check.spawnstatics + 1
end

local function main()
	-- setup an initial seed, lets use the same one for now '12345'
	math.randomseed(12345)
	local theaterPath = os.getenv("DCT_MISSION_PATH")
	if theaterPath == nil then
		-- skip test
		return 0
	end

	dct.Theater(theaterPath)
	print("Groups spawned:  "..check.spawngroups)
	print("Statics spawned: "..check.spawngroups)
	dct.DebugStats.getDebugStats():log()
	return 0
end

os.exit(main())
