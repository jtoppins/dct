#!/usr/bin/lua

require("dcttestlibs")
require("dct")
local Region = require("dct.templates.Region")

local utils = require("libs.utils")

local function main()
	local regiondir = dct.settings.server.theaterpath..
		utils.sep.."region1"
	Region(regiondir)
	return 0
end

os.exit(main())
