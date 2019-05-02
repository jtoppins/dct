require("testlibs")
require("dct")

local function main()
	local regiondir = "./data/mission/region1"
	dct.Region(regiondir)
	return 0
end

os.exit(main())
