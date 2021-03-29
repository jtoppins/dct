#!/usr/bin/lua

require("dcttestlibs")
require("dct")

assert(dct.settings.ui.gridfmt["Ka-50"] == 3, "ka-50 error")
os.exit(0)
