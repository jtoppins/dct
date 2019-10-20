#!/usr/bin/lua

require("dcttestlibs")
require("dct")
local utils = require("libs.utils")

local function main()
	local regiondir = lfs.tempdir()..utils.sep.."theater"..
		utils.sep.."region1"
	dct.Region(regiondir)
	return 0
end

os.exit(main())
