require("os")
require("testlibs.test")
require("testlibs.dcsstubs")
local json = require("libs.json")
local template = require("dct.template")

local check = {}
check.spawngroups  = 0
check.spawnstatics = 0

coalition = {}
function coalition.addGroup(cntry, cat, data)
	test.debug("SPAWN: spawn group, type:" .. cat .. ", name: " .. data.name)
	test.debug(json:encode_pretty(data))
	check.spawngroups = check.spawngroups + 1
end

function coalition.addStaticObject(cntry, data)
	test.debug("SPAWN: spawn static, type:" .. type(data) .. ", name: " .. data.name)
	test.debug(json:encode_pretty(data))
	check.spawnstatics = check.spawnstatics + 1
end

local function main()
	check.spawngroups  = 0
	check.spawnstatics = 0
	local t = template.Template("./data/test.stm", "./data/test.dct")
	t:spawn()
	assert(check.spawngroups == 1, "group spawn broken")
	assert(check.spawnstatics == 11, "static spawn broken")


	check.spawngroups  = 0
	check.spawnstatics = 0
	t = template.Template("./data/test-all-types.stm",
						  "./data/test-all-types.dct")
	t:spawn()
	assert(check.spawngroups == 6, "group spawn broken")
	assert(check.spawnstatics == 3, "static spawn broken")

	return 0
end

os.exit(main())
