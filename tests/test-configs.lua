#!/usr/bin/lua

require("dcttestlibs")
require("dct")

assert(dct.settings.ui.gridfmt["Ka-50"] == 6, "ka-50 error")
os.exit(0)
