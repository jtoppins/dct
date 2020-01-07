#!/usr/bin/lua

require("os")
require("io")
local Command = require("dct.Command")

local function f(a, b, c, time)
    return a + b + c + time
end

local function main()
    local cmd = Command(f, 1, 2, 3)
    local r = cmd:execute(500)
    assert(r == 506, "Command class broken")
end

os.exit(main())
