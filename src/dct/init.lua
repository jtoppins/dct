--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Starts the DCT framework
--]]

local Theater = require("dct.Theater")

local function init()
	local t = Theater()
	world.addEventHandler(t)
	timer.scheduleFunction(t.exec, t, timer.getTime() + 20)
end

return init
