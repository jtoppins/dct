#!/usr/bin/lua

require("os")
local Timer = require("dct.libs.Timer")

local function sleep(s)
	local n = os.clock() + s
	repeat until os.clock() > n
end

local function main()
	local a = Timer(15, os.clock)
	local b = Timer(2, os.clock)

	sleep(3)
	a:update()
	b:update()
	local remain = a:remain()
	assert(remain <= 12, "remain: "..remain)
	assert(a:expired() == false)

	remain = b:remain()
	assert(remain == 0, "remain: "..remain)
	assert(b:expired() == true)
	b:reset()
	remain = b:remain()
	assert(remain == 2, "remain: "..remain)
	b:extend(2)
	remain = b:remain()
	assert(remain == 4, "extend failed")
end

os.exit(main())
