require("os")
require("testlibs.test")
require("testlibs.dcsstubs")
local json = require("libs.json")
local region = require("dct.region")

local function main()
	local regiondir = "./data/region1"

	local r = region.Region(regiondir)
	print(json:encode_pretty(r))
	return 0
end

os.exit(main())
