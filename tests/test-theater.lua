require("os")
require("testlibs.dcsstubs")
local test = require("testlibs.test")
local json = require("libs.json")
require("dct")

local check = {}
check.spawngroups  = 0
check.spawnstatics = 0

coalition = {}
function coalition.addGroup(cntry, cat, data)
	test.debug("SPAWN: spawn group, type: " .. cat .. ", name: " .. data.name)
	test.debug(json:encode_pretty(data))
	check.spawngroups = check.spawngroups + 1
end

function coalition.addStaticObject(cntry, data)
	test.debug("SPAWN: spawn static, type: " .. type(data) .. ", name: " .. data.name)
	test.debug(json:encode_pretty(data))
	check.spawnstatics = check.spawnstatics + 1
end

local function main()
	local theaterPath = "./data/mission"
	local t = dct.Theater(theaterPath)
	assert(check.spawngroups == 1, "group spawn broken")
	assert(check.spawnstatics == 11, "static spawn broken")
	return 0
end

os.exit(main())
