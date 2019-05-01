--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Starts the DCT framework
--]]

local Theater  = require("dct.theater")
local settings = require("dct.settings")

local function init(dctsettings)
	local t = Theater(settings(dctsettings))
	world.addEventHandler(t)
	timer.scheduleFunction(t.exec, t, timer.getTime() + 20)
end

return init
