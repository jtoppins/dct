--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides a basic Command class to call an arbitrary function
-- at a later time via the Command's ececute function.
--]]

local class = require("libs.class")
local utils = require("libs.utils")

local Command = class()
function Command:__init(func, ...)
	assert(type(func) == "function",
		"value error: the first argument must be a function")
	self.func = func
	self.args = {select(1, ...)}
end

function Command:execute(time)
	local args = utils.shallowclone(self.args)
	table.insert(args, time)
	return self.func(unpack(args))
end

return Command
