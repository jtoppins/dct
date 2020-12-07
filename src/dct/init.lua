--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Starts the DCT framework
--]]

local Theater = require("dct.Theater")
local runonce

local function init()
	if runonce == true then
		return
	end
	local t = Theater.singleton()
	world.addEventHandler(t)
	timer.scheduleFunction(t.exec, t, timer.getTime() + 20)
	trigger.action.setUserFlag("DCTFLAG", true)
	runonce = true
end

return init
