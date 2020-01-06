--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides functions to define and manage goals.
--]]

local class = require("libs.class")

local Command = class()
function Command:execute(time)
	assert(false, "runtime error: this class method must be overridden")
end

return Command
