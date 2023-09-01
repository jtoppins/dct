-- SPDX-License-Identifier: LGPL-3.0

--- Initializes the DCT framework. Registers `Theater.exec` and
-- `Theater.onEvent` with the DCS mission scripting engine API
-- so DCT can periodically execute code and receive events from
-- DCS. These two theater functions are the only functions registered
-- with DCS.
-- @module dct.init

local Theater = require("dct.Theater")
local runonce

--- Initialize the DCT campaign framework.
-- @return nil
local function init()
	if runonce == true then
		return
	end

	trigger.action.setUserFlag("DCTENABLE_SLOTS", false)

	local t = Theater.singleton()
	world.addEventHandler(t)
	timer.scheduleFunction(t.exec, t, timer.getTime() + 20)
	runonce = true
end

return init
