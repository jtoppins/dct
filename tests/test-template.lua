require("os")

coalition = {}
function coalition.addGroup(cntry, cat, data)
	print("SPAWN: spawn group, type:" .. cat)
end

function coalition.addStaticObject(cntry, cat, data)
	print("SPAWN: spawn static, type:" .. data.name)
end

local template = require("dct.template")
local json = require("libs.json")

local function main()
	local stmfile = "./data/test.stm"
	local dctfile = "./data/test.dct"

	local t = template.Template(stmfile, dctfile)
	print("template: init complete")
	--print(json:encode_pretty(t))
	t:spawn()
	return 0
end

os.exit(main())
