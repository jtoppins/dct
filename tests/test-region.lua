#!/usr/bin/lua

require("dcttestlibs")
require("dct")
local Region = require("dct.Region")

local utils = require("libs.utils")

local function main()
	local regiondir = lfs.tempdir()..utils.sep.."theater"..
		utils.sep.."region1"
	Region(regiondir)
	return 0
end

os.exit(main())
