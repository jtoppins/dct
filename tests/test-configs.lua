#!/usr/bin/lua

require("dcttestlibs")
require("dct")

assert(dct.settings.ui["Ka-50"].gridfmt == 2, "ka-50 error")
os.exit(0)
