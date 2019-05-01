require("os")
require("testlibs.test")
require("testlibs.dcsstubs")
local Region = require("dct.region")

local function main()
	local regiondir = "./data/mission/region1"
	local r = Region(regiondir)
	return 0
end

os.exit(main())
