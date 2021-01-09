--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides a basic Command class to call an arbitrary function
-- at a later time via the Command's execute function.
--]]

local class = require("libs.namedclass")
local utils = require("libs.utils")
local check = require("libs.check")
local Logger= dct.Logger.getByName("Command")

-- lower value is higher priority; total of 127 priority values
local cmdpriority = {
	["UI"]     = 10,
	["NORMAL"] = 64,
}

local Command = class("Command")
function Command:__init(func, ...)
	self.func = check.func(func)
	self.name = "Unnamed Command"
	self.prio = cmdpriority.NORMAL
	self.args = {select(1, ...)}
	self.PRIORITY = nil
end

function Command:execute(time)
	local args = utils.shallowclone(self.args)
	Logger:debug(string.format("executing: %s", self.name))
	table.insert(args, time)
	return self.func(unpack(args))
end
Command.PRIORITY = cmdpriority

local cmd = Command

if dct.settings and dct.settings.server and
   (dct.settings.server.debug == true or
	dct.settings.server.profile == true) then
	require("os")
	local TimedCommand = class("TimedCommand", Command)
	function TimedCommand:execute(time)
		local tstart = os.clock()
		local rc = Command.execute(self, time)
		Logger:warn(string.format("'%s' exec time: %5.2fms",
			self.name, (os.clock()-tstart)*1000))
		return rc
	end
	TimedCommand.PRIORITY = cmdpriority
	cmd = TimedCommand
end

return cmd
