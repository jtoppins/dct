require("os")

local template = require("dct.template")
local json = require("libs.json")

coalition = {}
function coalition.addGroup(cntry, cat, data)
	print("SPAWN: spawn group, type:" .. cat .. ", name: " .. data.name)
	--print(json:encode_pretty(data))
end

function coalition.addStaticObject(cntry, data)
	print("SPAWN: spawn static, type:" .. type(data) .. ", name: " .. data.name)
	--print(json:encode_pretty(data))
end

local function main()
	local stmfile = "./data/test.stm"
	local dctfile = "./data/test.dct"

	local t = template.Template(stmfile, dctfile)
	--print(json:encode_pretty(t))
	t:spawn()
	return 0
end

os.exit(main())
