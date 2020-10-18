--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides a basic Command class to call an arbitrary function
-- at a later time via the Command's execute function.
--]]

local class = require("libs.class")
local utils = require("libs.utils")

-- lower value is higher priority; total of 127 priority values
local cmdpriority = {
	["UI"]     = 10,
	["NORMAL"] = 64,
}

local Command = class()
function Command:__init(func, ...)
	assert(type(func) == "function",
		"value error: the first argument must be a function")
	self.func = func
	self.name = "Unnamed Command"
	self.prio = cmdpriority.NORMAL
	self.args = {select(1, ...)}
	self.PRIORITY = nil
end

function Command:execute(time)
	local args = utils.shallowclone(self.args)
	table.insert(args, time)
	return self.func(unpack(args))
end
Command.PRIORITY = cmdpriority

local cmd = Command

if _G.settings and _G.settings.server and
   _G.settings.server.debug == true then
	require("os")
	local TimmedCommand = class(Command)
	function TimmedCommand:execute(time)
		local tstart = os.clock()
		local rc = Command.execute(self, time)
		dct.Logger.getByName("Command"):info(
			string.format("'%s' exec time: %f",
			self.name, os.clock()-tstart))
		return rc
	end
	TimmedCommand.PRIORITY = cmdpriority
	cmd = TimmedCommand
end

return cmd
