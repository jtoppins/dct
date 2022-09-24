#!/usr/bin/lua

require("os")
require("io")
require("dcttestlibs")
require("dct")
local Command = require("dct.libs.Command")

local function f(a, b, c, time)
    return a + b + c + time
end

local function main()
    local cmd = Command("test cmd", f, 1, 2, 3)
    local r = cmd:execute(500)
    assert(r == 506, "Command class broken")
end

os.exit(main())
